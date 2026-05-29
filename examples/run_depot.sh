#!/usr/bin/env bash
# Depot simulation — start a CSMS + N charge-point simulators concurrently.
#
# Usage:
#   bash examples/run_depot.sh              # 10 CPs, default DB
#   N_CPS=5 bash examples/run_depot.sh      # 5 CPs
#   CSMS_DB=/tmp/my.db bash examples/run_depot.sh
#
# Requirements:
#   - lex binary on PATH (or LEX=/path/to/lex in env)
#   - lex-ocpp checked out (run from the repo root or examples/ dir)
#   - sqlite3 on PATH (for the final report)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LEX="${LEX:-lex}"
DB="${CSMS_DB:-/tmp/depot.db}"
N_CPS="${N_CPS:-10}"
STARTUP_WAIT=2   # seconds to let the CSMS bind before firing simulators
CP_TIMEOUT=90    # 60s session + 20s overhead; perl alarm kills idle connections
                 # (no client-side WsClose in OCPP 1.6 transport)

# ---- Sanity checks -----------------------------------------------

if ! command -v "$LEX" >/dev/null 2>&1; then
  echo "error: lex binary not found (set LEX=/path/to/lex)"
  exit 1
fi

if [[ "$N_CPS" -gt 10 ]]; then
  echo "warning: depot seeds USER-001..USER-010; capping N_CPS at 10"
  N_CPS=10
fi

# ---- Reset DB ----------------------------------------------------

rm -f "$DB"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "  Depot Simulation"
printf "  CPs:  %d\n" "$N_CPS"
printf "  DB:   %s\n" "$DB"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ---- Start CSMS --------------------------------------------------

CSMS_DB="$DB" "$LEX" run \
  --allow-effects net,io,time,sql,fs_write,env \
  "$SCRIPT_DIR/depot_csms.lex" main \
  2>&1 | sed 's/^/[csms] /' &

CSMS_PID=$!

printf "Waiting %ds for CSMS to bind port 9000..." "$STARTUP_WAIT"
sleep "$STARTUP_WAIT"
echo " done"
echo ""

# ---- Start CP simulators -----------------------------------------

CP_PIDS=()
for i in $(seq 1 "$N_CPS"); do
  cp_id=$(printf "CP-%03d" "$i")
  id_tag=$(printf "USER-%03d" "$i")
  CP_ID="$cp_id" ID_TAG="$id_tag" \
    perl -e "alarm $CP_TIMEOUT; exec @ARGV" -- "$LEX" run \
    --allow-effects net,io,time,env \
    "$SCRIPT_DIR/cp_simulator_v16_timed.lex" main \
    2>&1 | sed "s/^/[$cp_id] /" &
  CP_PIDS+=($!)
done

printf "Started %d CP simulators (CP-001 ... CP-%03d)\n" "$N_CPS" "$N_CPS"
echo ""

# ---- Wait for all simulators -------------------------------------

for pid in "${CP_PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done

echo ""
echo "All simulators finished."

# Give the CSMS a moment to flush the last SQL writes before we query.
sleep 1

# ---- Report ------------------------------------------------------

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "  Depot Report"
echo "╚══════════════════════════════════════════════╝"
echo ""

if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$DB" <<'SQL'
.headers on
.mode column
.width 10 10 10 12 12 10

SELECT
  COUNT(*)                                         AS sessions,
  COUNT(DISTINCT cp_id)                            AS active_cps,
  COALESCE(SUM(meter_stop - meter_start), 0)       AS total_wh,
  COALESCE(AVG(meter_stop - meter_start), 0)       AS avg_wh,
  COALESCE(MIN(meter_stop - meter_start), 0)       AS min_wh,
  COALESCE(MAX(meter_stop - meter_start), 0)       AS max_wh
FROM transactions
WHERE meter_stop IS NOT NULL;
SQL

  echo ""
  sqlite3 "$DB" <<'SQL'
.headers on
.mode column
.width 10 10 12 8 10

SELECT
  cp_id,
  id_tag,
  (meter_stop - meter_start) AS energy_wh,
  reason,
  stop_ts
FROM transactions
WHERE meter_stop IS NOT NULL
ORDER BY id;
SQL
else
  echo "(sqlite3 not found — raw DB at $DB)"
fi

echo ""

# ---- Shutdown CSMS -----------------------------------------------

kill "$CSMS_PID" 2>/dev/null || true
wait "$CSMS_PID" 2>/dev/null || true

echo "CSMS stopped. DB kept at: $DB"
echo ""
echo "To re-inspect:"
echo "  sqlite3 '$DB' 'SELECT * FROM transactions;'"
echo "  sqlite3 '$DB' 'SELECT cp_id, status, ts FROM status_log ORDER BY id;'"
