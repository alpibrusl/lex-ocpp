# lex-ocpp example — OCPP 1.6 CSMS with SQLite persistence
#
# A second-generation CSMS that pairs with `examples/cp_simulator_v16.lex`
# (and any OCPP 1.6J charge point). Compared to `examples/csms_v16.lex`:
#
#   - Persists every state-changing message to a local SQLite database
#     (default `/tmp/csms.db`, override with `CSMS_DB`).
#   - Allocates real `transactionId` values from `last_insert_rowid()`
#     instead of hard-coding 42.
#   - Validates `idTag` against an `allowed_tags` table (seeded with
#     "USER-001" so the bundled simulator works out of the box; add
#     rows with: `sqlite3 /tmp/csms.db "INSERT INTO allowed_tags (id_tag) VALUES ('USER-002');"`).
#   - Tags every row with `cp_id` parsed from the WebSocket upgrade
#     path (`ws://host:9000/ocpp/<cp_id>`), so a single CSMS process
#     can serve multiple concurrent charge points and you can audit
#     per-CP history with a single `SELECT … WHERE cp_id = …`.
#
# Run alongside one or more simulators:
#
#   # Terminal A — CSMS (writes to /tmp/csms.db by default)
#   lex run --allow-effects net,io,time,sql,fs_write,env \
#     examples/csms_v16_sqlite.lex main
#
#   # Terminal B — Charge point #1
#   CP_ID=CP-001 ID_TAG=USER-001 \
#     lex run --allow-effects net,io,env \
#     examples/cp_simulator_v16.lex main
#
#   # Terminal C — Charge point #2 (concurrent)
#   CP_ID=CP-002 ID_TAG=USER-001 \
#     lex run --allow-effects net,io,env \
#     examples/cp_simulator_v16.lex main
#
# Inspect:
#
#   sqlite3 /tmp/csms.db 'SELECT * FROM transactions;'
#   sqlite3 /tmp/csms.db 'SELECT * FROM meter_values;'
#   sqlite3 /tmp/csms.db 'SELECT cp_id, status, ts FROM status_log ORDER BY id DESC LIMIT 10;'
#
# Design notes:
#   - The route_io registry pattern (used by `csms_v16_stateful.lex`)
#     dispatches purely on `action`, so handlers can't see `WsConn`.
#     This CSMS handles dispatch itself in `dispatch_call` so it can
#     thread `cp_id` (from `conn.path`) into every SQL write.
#   - The `Db` handle is captured by the closure passed to
#     `net.serve_ws_fn` — Lex has no mutable globals, but closures
#     can capture immutable values, which is exactly what `Db` is
#     (an opaque integer registry handle behind the scenes).
#   - All SQL goes through `sql.exec` / `sql.query` with parameterised
#     arguments — never string-concat. AGENTS.md §3.2.

import "std.io" as io

import "std.net" as net

import "std.str" as str

import "std.int" as int

import "std.list" as list

import "std.sql" as sql

import "std.env" as env

import "lex-schema/json_value" as jv

import "std.time" as time

import "../src/messages" as msg

import "../src/error" as oe

import "../src/route" as route

import "../src/charge_point" as cp

import "../src/v16/action" as a

import "../src/v16/enums" as en

import "../src/v16/schemas" as sch

# ---- Configuration -----------------------------------------------
fn default_db_path() -> Str {
  "/tmp/csms.db"
}

fn db_path() -> [env] Str {
  match env.get("CSMS_DB") {
    Some(p) => p,
    None => default_db_path(),
  }
}

# Hardcoded constants kept identical to csms_v16_stateful for parity.
fn boot_interval_s() -> Int {
  300
}

# ---- Schema -------------------------------------------------------
fn ddl_charge_points() -> Str {
  "CREATE TABLE IF NOT EXISTS charge_points (\n     cp_id      TEXT PRIMARY KEY,\n     vendor     TEXT,\n     model      TEXT,\n     last_boot  TEXT\n   )"
}

fn ddl_allowed_tags() -> Str {
  "CREATE TABLE IF NOT EXISTS allowed_tags (\n     id_tag      TEXT PRIMARY KEY,\n     description TEXT\n   )"
}

fn ddl_transactions() -> Str {
  "CREATE TABLE IF NOT EXISTS transactions (\n     id           INTEGER PRIMARY KEY AUTOINCREMENT,\n     cp_id        TEXT NOT NULL,\n     connector_id INTEGER NOT NULL,\n     id_tag       TEXT NOT NULL,\n     meter_start  INTEGER NOT NULL,\n     meter_stop   INTEGER,\n     start_ts     TEXT NOT NULL,\n     stop_ts      TEXT,\n     reason       TEXT\n   )"
}

fn ddl_meter_values() -> Str {
  "CREATE TABLE IF NOT EXISTS meter_values (\n     id             INTEGER PRIMARY KEY AUTOINCREMENT,\n     cp_id          TEXT NOT NULL,\n     transaction_id INTEGER,\n     connector_id   INTEGER NOT NULL,\n     value_wh       INTEGER NOT NULL,\n     ts             TEXT NOT NULL\n   )"
}

fn ddl_status_log() -> Str {
  "CREATE TABLE IF NOT EXISTS status_log (\n     id           INTEGER PRIMARY KEY AUTOINCREMENT,\n     cp_id        TEXT NOT NULL,\n     connector_id INTEGER,\n     status       TEXT NOT NULL,\n     error_code   TEXT,\n     ts           TEXT NOT NULL\n   )"
}

fn init_db(db :: Db) -> [sql] Result[Unit, SqlError] {
  match sql.exec(db, ddl_charge_points(), []) {
    Err(e) => Err(e),
    Ok(_) => match sql.exec(db, ddl_allowed_tags(), []) {
      Err(e) => Err(e),
      Ok(_) => match sql.exec(db, ddl_transactions(), []) {
        Err(e) => Err(e),
        Ok(_) => match sql.exec(db, ddl_meter_values(), []) {
          Err(e) => Err(e),
          Ok(_) => match sql.exec(db, ddl_status_log(), []) {
            Err(e) => Err(e),
            Ok(_) => seed_allowed_tags(db),
          },
        },
      },
    },
  }
}

# Idempotent seed. INSERT OR IGNORE leaves an existing row alone.
fn seed_allowed_tags(db :: Db) -> [sql] Result[Unit, SqlError] {
  match sql.exec(db, "INSERT OR IGNORE INTO allowed_tags (id_tag, description) VALUES (?, ?)", [PStr("USER-001"), PStr("default demo card")]) {
    Err(e) => Err(e),
    Ok(_) => Ok(()),
  }
}

# ---- WS path → cp_id ---------------------------------------------
#
# Strip the leading "/ocpp/" prefix. Anything left is the charge-point
# identifier. Fall back to "unknown" if the path doesn't match.
fn cp_id_from_path(path :: Str) -> Str {
  match str.strip_prefix(path, "/ocpp/") {
    Some(id) => id,
    None => match str.strip_prefix(path, "/") {
      Some(id) => id,
      None => "unknown",
    },
  }
}

# ---- Per-action handlers -----------------------------------------
#
# Each returns `route.HandlerResult` (HOk(payload) | HErr(OcppError))
# so the surrounding `handle` shim can convert into CallResult or
# CallError frames the same way lex-ocpp's own `route_io` does.
fn on_boot(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let vendor := json_str_or(payload, "chargePointVendor", "")
  let model := json_str_or(payload, "chargePointModel", "")
  let __lex_discard_1 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] BootNotification vendor=", str.concat(vendor, str.concat(" model=", model))))))
  match sql.exec(db, "INSERT INTO charge_points (cp_id, vendor, model, last_boot)\n       VALUES (?, ?, ?, ?)\n     ON CONFLICT(cp_id) DO UPDATE SET vendor=excluded.vendor,\n       model=excluded.model, last_boot=excluded.last_boot", [PStr(cp_id), PStr(vendor), PStr(model), PStr(now)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([("currentTime", JStr(now)), ("interval", JInt(boot_interval_s())), ("status", JStr(en.reg_accepted()))])),
  }
}

fn on_status(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let status := json_str_or(payload, "status", "?")
  let err_c := json_str_or(payload, "errorCode", en.ec_no_error())
  let __lex_discard_2 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] Status conn=", str.concat(int.to_str(conn_id), str.concat(" status=", status))))))
  match sql.exec(db, "INSERT INTO status_log (cp_id, connector_id, status, error_code, ts)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), PInt(conn_id), PStr(status), PStr(err_c), PStr(now)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([])),
  }
}

# `idTagInfo.status` is "Accepted" when the id_tag is in the allowlist,
# otherwise "Invalid". A real CSMS would also check expiry / parent
# tag — this stays at the minimum for the demo.
fn on_authorize(db :: Db, cp_id :: Str, payload :: jv.Json, _now :: Str) -> [io, sql] route.HandlerResult {
  let id_tag := json_str_or(payload, "idTag", "")
  let allowed := tag_is_allowed(db, id_tag)
  let status := if allowed {
    en.auth_accepted()
  } else {
    en.auth_invalid()
  }
  let __lex_discard_3 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] Authorize idTag=", str.concat(id_tag, str.concat(" → ", status))))))
  HOk(JObj([("idTagInfo", JObj([("status", JStr(status))]))]))
}

fn tag_is_allowed(db :: Db, id_tag :: Str) -> [sql] Bool {
  let res :: Result[List[{ id_tag :: Str }], SqlError] := sql.query(db, "SELECT id_tag FROM allowed_tags WHERE id_tag = ?", [PStr(id_tag)])
  match res {
    Err(_) => false,
    Ok(rows) => not list.is_empty(rows),
  }
}

# `last_insert_rowid()` is SQLite-specific but std.sql is currently
# SQLite-backed. Returns the rowid of the just-INSERTed row.
fn on_start_tx(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let id_tag := json_str_or(payload, "idTag", "")
  let m_start := json_int_or(payload, "meterStart", 0)
  let ts := json_str_or(payload, "timestamp", now)
  match sql.exec(db, "INSERT INTO transactions\n       (cp_id, connector_id, id_tag, meter_start, start_ts)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), PInt(conn_id), PStr(id_tag), PInt(m_start), PStr(ts)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => match last_insert_rowid(db) {
      Err(e) => HErr(oe.internal_err(e.message)),
      Ok(tx_id) => {
        let __lex_discard_4 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] StartTransaction → tx=", int.to_str(tx_id)))))
        let status := if tag_is_allowed(db, id_tag) {
          en.auth_accepted()
        } else {
          en.auth_invalid()
        }
        HOk(JObj([("transactionId", JInt(tx_id)), ("idTagInfo", JObj([("status", JStr(status))]))]))
      },
    },
  }
}

fn last_insert_rowid(db :: Db) -> [sql] Result[Int, SqlError] {
  let res :: Result[List[{ id :: Int }], SqlError] := sql.query(db, "SELECT last_insert_rowid() AS id", [])
  match res {
    Err(e) => Err(e),
    Ok(rows) => match list.head(rows) {
      Some(r) => Ok(r.id),
      None => Ok(0),
    },
  }
}

fn on_meter_values(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let tx_id_o := jv.get_field(payload, "transactionId")
  let tx_id := match tx_id_o {
    Some(JInt(n)) => n,
    _ => 0,
  }
  let sample := extract_first_sample(payload, now)
  let value_wh := sample.value_wh
  let ts := sample.ts
  let __lex_discard_5 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] MeterValues conn=", str.concat(int.to_str(conn_id), str.concat(" tx=", str.concat(int.to_str(tx_id), str.concat(" wh=", int.to_str(value_wh)))))))))
  let tx_param := if tx_id == 0 {
    PNull
  } else {
    PInt(tx_id)
  }
  match sql.exec(db, "INSERT INTO meter_values\n       (cp_id, transaction_id, connector_id, value_wh, ts)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), tx_param, PInt(conn_id), PInt(value_wh), PStr(ts)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([])),
  }
}

# Walk `payload.meterValue[0].sampledValue[0]` defensively — any
# missing/typo path collapses to {value_wh: 0, ts: now} so an out-of-
# spec frame never crashes the handler.
type Sample = { value_wh :: Int, ts :: Str }

fn extract_first_sample(payload :: jv.Json, now :: Str) -> Sample {
  match jv.get_field(payload, "meterValue") {
    Some(JList(mvs)) => match list.head(mvs) {
      Some(mv) => sample_from_mv(mv, now),
      None => { value_wh: 0, ts: now },
    },
    _ => { value_wh: 0, ts: now },
  }
}

fn sample_from_mv(mv :: jv.Json, now :: Str) -> Sample {
  let ts := match jv.get_field(mv, "timestamp") {
    Some(JStr(t)) => t,
    _ => now,
  }
  let wh := match jv.get_field(mv, "sampledValue") {
    Some(JList(svs)) => match list.head(svs) {
      Some(sv) => wh_from_sv(sv),
      None => 0,
    },
    _ => 0,
  }
  { value_wh: wh, ts: ts }
}

fn wh_from_sv(sv :: jv.Json) -> Int {
  match jv.get_field(sv, "value") {
    Some(JStr(v)) => match str.to_int(v) {
      Some(n) => n,
      None => 0,
    },
    Some(JInt(n)) => n,
    _ => 0,
  }
}

fn on_heartbeat(_db :: Db, cp_id :: Str, _payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let __lex_discard_6 := io.print(str.concat("  [", str.concat(cp_id, "] Heartbeat")))
  HOk(JObj([("currentTime", JStr(now))]))
}

fn on_stop_tx(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let tx_id := json_int_or(payload, "transactionId", 0)
  let m_stop := json_int_or(payload, "meterStop", 0)
  let ts := json_str_or(payload, "timestamp", now)
  let reason := json_str_or(payload, "reason", en.reason_local())
  let __lex_discard_7 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] StopTransaction tx=", str.concat(int.to_str(tx_id), str.concat(" reason=", reason))))))
  match sql.exec(db, "UPDATE transactions SET meter_stop = ?, stop_ts = ?, reason = ?\n       WHERE id = ? AND cp_id = ?", [PInt(m_stop), PStr(ts), PStr(reason), PInt(tx_id), PStr(cp_id)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([("idTagInfo", JObj([("status", JStr(en.auth_accepted()))]))])),
  }
}

fn on_data_transfer(_db :: Db, cp_id :: Str, _payload :: jv.Json, _now :: Str) -> [io, sql] route.HandlerResult {
  let __lex_discard_8 := io.print(str.concat("  [", str.concat(cp_id, "] DataTransfer (stub)")))
  HOk(JObj([("status", JStr(en.dt_accepted()))]))
}

# ---- Dispatch -----------------------------------------------------
#
# Per-action: validate the inbound payload, route to the right
# handler closure, build a CallResult or CallError frame.
fn dispatch_call(db :: Db, cp_id :: Str, action :: Str, message_id :: Str, payload :: jv.Json, now :: Str) -> [io, time, sql] msg.Frame {
  if action == a.boot_notification() {
    handle(message_id, sch.validate_boot_notification_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
      on_boot(db, cp_id, p, now)
    })
  } else {
    if action == a.status_notification() {
      handle(message_id, sch.validate_status_notification_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_status(db, cp_id, p, now)
      })
    } else {
      if action == a.authorize() {
        handle(message_id, sch.validate_authorize_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
          on_authorize(db, cp_id, p, now)
        })
      } else {
        if action == a.start_transaction() {
          handle(message_id, sch.validate_start_transaction_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
            on_start_tx(db, cp_id, p, now)
          })
        } else {
          if action == a.meter_values() {
            handle(message_id, sch.validate_meter_values_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
              on_meter_values(db, cp_id, p, now)
            })
          } else {
            if action == a.heartbeat() {
              handle(message_id, sch.validate_heartbeat_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
                on_heartbeat(db, cp_id, p, now)
              })
            } else {
              if action == a.stop_transaction() {
                handle(message_id, sch.validate_stop_transaction_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
                  on_stop_tx(db, cp_id, p, now)
                })
              } else {
                if action == a.data_transfer() {
                  handle(message_id, sch.validate_data_transfer_req, payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
                    on_data_transfer(db, cp_id, p, now)
                  })
                } else {
                  let __lex_discard_9 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] NotImplemented: ", action))))
                  let oerr := oe.not_implemented_err(action)
                  msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details)
                }
              }
            }
          }
        }
      }
    }
  }
}

fn handle(message_id :: Str, validator :: (jv.Json) -> Result[jv.Json, List[{ path :: Str, code :: Str, message :: Str }]], payload :: jv.Json, body :: (jv.Json) -> [io, sql] route.HandlerResult) -> [io, sql] msg.Frame {
  match validator(payload) {
    Err(es) => {
      let oerr := oe.from_schema_errors(es)
      msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details)
    },
    Ok(normalized) => match body(normalized) {
      HOk(out) => msg.new_call_result(message_id, out),
      HErr(oerr) => msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details),
    },
  }
}

# ---- WS adapter --------------------------------------------------
fn handle_raw(db :: Db, cp_id :: Str, raw :: Str) -> [io, time, sql] Str {
  match msg.parse(raw) {
    Err(fe) => msg.encode(msg.new_call_error("", fe.code, fe.message, JObj([]))),
    Ok(FrameCall(c)) => {
      let now := time.now_str()
      msg.encode(dispatch_call(db, cp_id, c.action, c.message_id, c.payload, now))
    },
    Ok(FrameCallResult(_)) => "",
    Ok(FrameCallError(e)) => {
      let __lex_discard_10 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] inbound CallError: ", e.description))))
      ""
    },
  }
}

# Build the WebSocket message handler. Captures `db`. Each new
# connection is a different `WsConn`, so cp_id is recomputed per
# inbound frame from `conn.path`.
fn build_on_message(db :: Db) -> (WsConn, WsMessage) -> [io, time, sql] WsAction {
  fn (conn :: WsConn, m :: WsMessage) -> [io, time, sql] WsAction {
    let cp_id := cp_id_from_path(conn.path)
    match m {
      WsText(raw) => {
        let out := handle_raw(db, cp_id, raw)
        if out == "" {
          WsNoOp
        } else {
          WsSend(out)
        }
      },
      WsClose => {
        let __lex_discard_11 := io.print(str.concat("  [", str.concat(cp_id, "] connection closed")))
        WsNoOp
      },
      WsPing => WsNoOp,
      WsBinary(_) => WsNoOp,
    }
  }
}

# ---- Tiny helpers ------------------------------------------------
fn json_str_or(j :: jv.Json, key :: Str, default :: Str) -> Str {
  match jv.get_field(j, key) {
    Some(JStr(s)) => s,
    _ => default,
  }
}

fn json_int_or(j :: jv.Json, key :: Str, default :: Int) -> Int {
  match jv.get_field(j, key) {
    Some(JInt(n)) => n,
    _ => default,
  }
}

# ---- Entry point -------------------------------------------------
fn main() -> [net, io, time, sql, fs_write, env] Nil {
  let path := db_path()
  let __lex_discard_12 := io.print("CSMS v1.6 (sqlite)  ws://localhost:9000/ocpp/<cp_id>")
  let __lex_discard_13 := io.print(str.concat("  db: ", path))
  match sql.open(path) {
    Err(e) => io.print(str.concat("  ! sql.open failed: ", e.message)),
    Ok(db) => match init_db(db) {
      Err(e) => io.print(str.concat("  ! schema init failed: ", e.message)),
      Ok(_) => {
        let __lex_discard_14 := io.print("  schema ready; pre-seeded allowed_tags with USER-001")
        net.serve_ws_fn(9000, cp.version_v16(), build_on_message(db))
      },
    },
  }
}

