# lex-ocpp example — Depot CSMS (OCPP 1.6, SQLite, lex-web)
#
# Depot-oriented CSMS using lex-web's ws.serve for cleaner WebSocket
# handling. Differences from the raw net.serve_ws_fn version:
#
#   - ws.last_segment(conn.path) replaces the manual cp_id_from_path helper.
#   - ws.send / ws.noop replace raw WsSend / WsNoOp constructors.
#   - INSERT ... RETURNING id replaces last_insert_rowid(), which races
#     when multiple CPs commit StartTransaction concurrently on a shared
#     DB connection.
#
# Seeds USER-001 … USER-010 at startup. Default DB: /tmp/depot.db.
#
# Run standalone:
#   lex run --allow-effects net,io,time,sql,fs_write,env \
#     examples/depot_csms.lex main
#
# Via the orchestrator (recommended):
#   bash examples/run_depot.sh
#
# Inspect after a run:
#   sqlite3 /tmp/depot.db \
#     'SELECT cp_id, id_tag, meter_stop - meter_start AS wh FROM transactions;'

import "std.io"   as io
import "std.net"  as net
import "std.str"  as str
import "std.int"  as int
import "std.list" as list
import "std.sql"  as sql
import "std.env"  as env
import "std.time" as time

import "lex-schema/json_value" as jv
import "lex-web/ws"            as ws   # last_segment, send, noop helpers

import "../src/messages"     as msg
import "../src/error"        as oe
import "../src/route"        as route
import "../src/charge_point" as cp
import "../src/v16/action"   as a
import "../src/v16/enums"    as en
import "../src/v16/schemas"  as sch

# ---- Configuration -----------------------------------------------

fn default_db_path() -> Str { "/tmp/depot.db" }

fn db_path() -> [env] Str {
  match env.get("CSMS_DB") {
    Some(p) => p,
    None    => default_db_path(),
  }
}

fn boot_interval_s() -> Int { 300 }

# ---- Schema -------------------------------------------------------

fn ddl_charge_points() -> Str {
  "CREATE TABLE IF NOT EXISTS charge_points (
     cp_id      TEXT PRIMARY KEY,
     vendor     TEXT,
     model      TEXT,
     last_boot  TEXT
   )"
}

fn ddl_allowed_tags() -> Str {
  "CREATE TABLE IF NOT EXISTS allowed_tags (
     id_tag      TEXT PRIMARY KEY,
     description TEXT
   )"
}

fn ddl_transactions() -> Str {
  "CREATE TABLE IF NOT EXISTS transactions (
     id           INTEGER PRIMARY KEY AUTOINCREMENT,
     cp_id        TEXT NOT NULL,
     connector_id INTEGER NOT NULL,
     id_tag       TEXT NOT NULL,
     meter_start  INTEGER NOT NULL,
     meter_stop   INTEGER,
     start_ts     TEXT NOT NULL,
     stop_ts      TEXT,
     reason       TEXT
   )"
}

fn ddl_meter_values() -> Str {
  "CREATE TABLE IF NOT EXISTS meter_values (
     id             INTEGER PRIMARY KEY AUTOINCREMENT,
     cp_id          TEXT NOT NULL,
     transaction_id INTEGER,
     connector_id   INTEGER NOT NULL,
     value_wh       INTEGER NOT NULL,
     ts             TEXT NOT NULL
   )"
}

fn ddl_status_log() -> Str {
  "CREATE TABLE IF NOT EXISTS status_log (
     id           INTEGER PRIMARY KEY AUTOINCREMENT,
     cp_id        TEXT NOT NULL,
     connector_id INTEGER,
     status       TEXT NOT NULL,
     error_code   TEXT,
     ts           TEXT NOT NULL
   )"
}

fn init_db(db :: Db) -> [sql] Result[Unit, SqlError] {
  match sql.exec(db, ddl_charge_points(), []) {
    Err(e) => Err(e),
    Ok(_)  => match sql.exec(db, ddl_allowed_tags(), []) {
      Err(e) => Err(e),
      Ok(_)  => match sql.exec(db, ddl_transactions(), []) {
        Err(e) => Err(e),
        Ok(_)  => match sql.exec(db, ddl_meter_values(), []) {
          Err(e) => Err(e),
          Ok(_)  => match sql.exec(db, ddl_status_log(), []) {
            Err(e) => Err(e),
            Ok(_)  => seed_depot_tags(db, depot_tag_list()),
          },
        },
      },
    },
  }
}

# ---- Tag seeding -------------------------------------------------

fn depot_tag_list() -> List[Str] {
  ["USER-001", "USER-002", "USER-003", "USER-004", "USER-005",
   "USER-006", "USER-007", "USER-008", "USER-009", "USER-010"]
}

fn seed_depot_tags(db :: Db, tags :: List[Str]) -> [sql] Result[Unit, SqlError] {
  match list.head(tags) {
    None => Ok(()),
    Some(tag) =>
      match sql.exec(db,
        "INSERT OR IGNORE INTO allowed_tags (id_tag, description) VALUES (?, ?)",
        [PStr(tag), PStr("depot driver card")])
      {
        Err(e) => Err(e),
        Ok(_)  => seed_depot_tags(db, list.tail(tags)),
      },
  }
}

# ---- Per-action handlers -----------------------------------------

fn on_boot(
  db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let vendor := json_str_or(payload, "chargePointVendor", "")
  let model  := json_str_or(payload, "chargePointModel",  "")
  let _ := io.print(str.concat("  [", str.concat(cp_id,
            str.concat("] Boot vendor=",
              str.concat(vendor, str.concat(" model=", model))))))
  match sql.exec(db,
    "INSERT INTO charge_points (cp_id, vendor, model, last_boot)
       VALUES (?, ?, ?, ?)
     ON CONFLICT(cp_id) DO UPDATE SET
       vendor=excluded.vendor, model=excluded.model,
       last_boot=excluded.last_boot",
    [PStr(cp_id), PStr(vendor), PStr(model), PStr(now)])
  {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_)  => HOk(JObj([
      ("currentTime", JStr(now)),
      ("interval",    JInt(boot_interval_s())),
      ("status",      JStr(en.reg_accepted())),
    ])),
  }
}

fn on_status(
  db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let status  := json_str_or(payload, "status",      "?")
  let err_c   := json_str_or(payload, "errorCode",   en.ec_no_error())
  let _ := io.print(str.concat("  [", str.concat(cp_id,
            str.concat("] Status conn=", str.concat(int.to_str(conn_id),
              str.concat(" ", status))))))
  match sql.exec(db,
    "INSERT INTO status_log (cp_id, connector_id, status, error_code, ts)
       VALUES (?, ?, ?, ?, ?)",
    [PStr(cp_id), PInt(conn_id), PStr(status), PStr(err_c), PStr(now)])
  {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_)  => HOk(JObj([])),
  }
}

fn on_authorize(
  db :: Db, cp_id :: Str, payload :: jv.Json, _now :: Str
) -> [io, sql] route.HandlerResult {
  let id_tag  := json_str_or(payload, "idTag", "")
  let allowed := tag_is_allowed(db, id_tag)
  let status  := if allowed { en.auth_accepted() } else { en.auth_invalid() }
  let _ := io.print(str.concat("  [", str.concat(cp_id,
            str.concat("] Authorize idTag=", str.concat(id_tag,
              str.concat(" -> ", status))))))
  HOk(JObj([("idTagInfo", JObj([("status", JStr(status))]))]))
}

fn tag_is_allowed(db :: Db, id_tag :: Str) -> [sql] Bool {
  let res :: Result[List[{ id_tag :: Str }], SqlError] :=
    sql.query(db,
      "SELECT id_tag FROM allowed_tags WHERE id_tag = ?",
      [PStr(id_tag)])
  match res {
    Err(_)   => false,
    Ok(rows) => not list.is_empty(rows),
  }
}

# Use INSERT ... RETURNING id to get the exact rowid of the inserted
# transaction atomically — avoids the last_insert_rowid() race when
# multiple CPs commit StartTransaction concurrently on one DB handle.
fn on_start_tx(
  db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let id_tag  := json_str_or(payload, "idTag",       "")
  let m_start := json_int_or(payload, "meterStart",  0)
  let ts      := json_str_or(payload, "timestamp",   now)
  let res :: Result[List[{ id :: Int }], SqlError] :=
    sql.query(db,
      "INSERT INTO transactions
         (cp_id, connector_id, id_tag, meter_start, start_ts)
         VALUES (?, ?, ?, ?, ?) RETURNING id",
      [PStr(cp_id), PInt(conn_id), PStr(id_tag), PInt(m_start), PStr(ts)])
  match res {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(rows) => match list.head(rows) {
      None    => HErr(oe.internal_err("RETURNING id returned no rows")),
      Some(r) => {
        let tx_id := r.id
        let _ := io.print(str.concat("  [", str.concat(cp_id,
                  str.concat("] StartTransaction tx=", int.to_str(tx_id)))))
        let auth_status := if tag_is_allowed(db, id_tag) {
          en.auth_accepted()
        } else {
          en.auth_invalid()
        }
        HOk(JObj([
          ("transactionId", JInt(tx_id)),
          ("idTagInfo",     JObj([("status", JStr(auth_status))])),
        ]))
      },
    },
  }
}

fn on_meter_values(
  db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let tx_id   := match jv.get_field(payload, "transactionId") {
    Some(JInt(n)) => n, _ => 0
  }
  let sample := extract_first_sample(payload, now)
  let _ := io.print(str.concat("  [", str.concat(cp_id,
            str.concat("] MeterValues tx=", str.concat(int.to_str(tx_id),
              str.concat(" wh=", int.to_str(sample.value_wh)))))))
  let tx_param := if tx_id == 0 { PNull } else { PInt(tx_id) }
  match sql.exec(db,
    "INSERT INTO meter_values
       (cp_id, transaction_id, connector_id, value_wh, ts)
       VALUES (?, ?, ?, ?, ?)",
    [PStr(cp_id), tx_param, PInt(conn_id), PInt(sample.value_wh), PStr(sample.ts)])
  {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_)  => HOk(JObj([])),
  }
}

type Sample = { value_wh :: Int, ts :: Str }

fn extract_first_sample(payload :: jv.Json, now :: Str) -> Sample {
  match jv.get_field(payload, "meterValue") {
    Some(JList(mvs)) => match list.head(mvs) {
      Some(mv) => sample_from_mv(mv, now),
      None     => { value_wh: 0, ts: now },
    },
    _ => { value_wh: 0, ts: now },
  }
}

fn sample_from_mv(mv :: jv.Json, now :: Str) -> Sample {
  let ts := match jv.get_field(mv, "timestamp") {
    Some(JStr(t)) => t, _ => now,
  }
  let wh := match jv.get_field(mv, "sampledValue") {
    Some(JList(svs)) => match list.head(svs) {
      Some(sv) => wh_from_sv(sv), None => 0,
    },
    _ => 0,
  }
  { value_wh: wh, ts: ts }
}

fn wh_from_sv(sv :: jv.Json) -> Int {
  match jv.get_field(sv, "value") {
    Some(JStr(v)) => match str.to_int(v) { Some(n) => n, None => 0 },
    Some(JInt(n)) => n,
    _             => 0,
  }
}

fn on_heartbeat(
  _db :: Db, cp_id :: Str, _payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let _ := io.print(str.concat("  [", str.concat(cp_id, "] Heartbeat")))
  HOk(JObj([("currentTime", JStr(now))]))
}

fn on_stop_tx(
  db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str
) -> [io, sql] route.HandlerResult {
  let tx_id  := json_int_or(payload, "transactionId", 0)
  let m_stop := json_int_or(payload, "meterStop",     0)
  let ts     := json_str_or(payload, "timestamp",     now)
  let reason := json_str_or(payload, "reason",        en.reason_local())
  let _ := io.print(str.concat("  [", str.concat(cp_id,
            str.concat("] StopTransaction tx=", str.concat(int.to_str(tx_id),
              str.concat(" wh=", int.to_str(m_stop)))))))
  match sql.exec(db,
    "UPDATE transactions SET meter_stop = ?, stop_ts = ?, reason = ?
       WHERE id = ? AND cp_id = ?",
    [PInt(m_stop), PStr(ts), PStr(reason), PInt(tx_id), PStr(cp_id)])
  {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_)  => HOk(JObj([
      ("idTagInfo", JObj([("status", JStr(en.auth_accepted()))])),
    ])),
  }
}

fn on_data_transfer(
  _db :: Db, cp_id :: Str, _payload :: jv.Json, _now :: Str
) -> [io, sql] route.HandlerResult {
  let _ := io.print(str.concat("  [", str.concat(cp_id, "] DataTransfer (stub)")))
  HOk(JObj([("status", JStr(en.dt_accepted()))]))
}

# ---- Dispatch -----------------------------------------------------

fn dispatch_call(
  db :: Db, cp_id :: Str, action :: Str,
  message_id :: Str, payload :: jv.Json, now :: Str
) -> [io, time, sql] msg.Frame {
  if action == a.boot_notification() {
    handle(message_id, sch.validate_boot_notification_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_boot(db, cp_id, p, now)
      })
  } else { if action == a.status_notification() {
    handle(message_id, sch.validate_status_notification_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_status(db, cp_id, p, now)
      })
  } else { if action == a.authorize() {
    handle(message_id, sch.validate_authorize_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_authorize(db, cp_id, p, now)
      })
  } else { if action == a.start_transaction() {
    handle(message_id, sch.validate_start_transaction_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_start_tx(db, cp_id, p, now)
      })
  } else { if action == a.meter_values() {
    handle(message_id, sch.validate_meter_values_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_meter_values(db, cp_id, p, now)
      })
  } else { if action == a.heartbeat() {
    handle(message_id, sch.validate_heartbeat_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_heartbeat(db, cp_id, p, now)
      })
  } else { if action == a.stop_transaction() {
    handle(message_id, sch.validate_stop_transaction_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_stop_tx(db, cp_id, p, now)
      })
  } else { if action == a.data_transfer() {
    handle(message_id, sch.validate_data_transfer_req,
      payload, fn (p :: jv.Json) -> [io, sql] route.HandlerResult {
        on_data_transfer(db, cp_id, p, now)
      })
  } else {
    let _ := io.print(str.concat("  [", str.concat(cp_id,
              str.concat("] NotImplemented: ", action))))
    let oerr := oe.not_implemented_err(action)
    msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details)
  } } } } } } } }
}

fn handle(
  message_id :: Str,
  validator  :: (jv.Json) -> Result[jv.Json,
                              List[{ path :: Str, code :: Str, message :: Str }]],
  payload    :: jv.Json,
  body       :: (jv.Json) -> [io, sql] route.HandlerResult
) -> [io, sql] msg.Frame {
  match validator(payload) {
    Err(es) => {
      let oerr := oe.from_schema_errors(es)
      msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details)
    },
    Ok(normalized) => match body(normalized) {
      HOk(out)   => msg.new_call_result(message_id, out),
      HErr(oerr) => msg.new_call_error(
                      message_id, oerr.code, oerr.description, oerr.details),
    },
  }
}

# ---- WS adapter (lex-web) -----------------------------------------
#
# ws.last_segment("/ocpp/CP-001") == "CP-001"
# ws.send / ws.noop replace raw WsSend / WsNoOp constructors.

fn handle_raw(db :: Db, cp_id :: Str, raw :: Str) -> [io, time, sql] Str {
  match msg.parse(raw) {
    Err(fe) => msg.encode(msg.new_call_error(
                "", fe.code, fe.message, JObj([]))),
    Ok(FrameCall(c)) => {
      let now := time.now_str()
      msg.encode(dispatch_call(db, cp_id, c.action,
                               c.message_id, c.payload, now))
    },
    Ok(FrameCallResult(_)) => "",
    Ok(FrameCallError(e))  => {
      let _ := io.print(str.concat("  [", str.concat(cp_id,
                str.concat("] inbound CallError: ", e.description))))
      ""
    },
  }
}

fn build_on_message(
  db :: Db
) -> (WsConn, WsMessage) -> [io, time, sql] WsAction {
  fn (conn :: WsConn, m :: WsMessage) -> [io, time, sql] WsAction {
    let cp_id := ws.last_segment(conn.path)
    match m {
      WsText(raw) => {
        let out := handle_raw(db, cp_id, raw)
        if out == "" { ws.noop() } else { ws.send(out) }
      },
      WsClose     => {
        let _ := io.print(str.concat("  [", str.concat(cp_id, "] disconnected")))
        ws.noop()
      },
      WsPing      => ws.noop(),
      WsBinary(_) => ws.noop(),
    }
  }
}

# ---- Tiny helpers ------------------------------------------------

fn json_str_or(j :: jv.Json, key :: Str, default :: Str) -> Str {
  match jv.get_field(j, key) {
    Some(JStr(s)) => s,
    _             => default,
  }
}

fn json_int_or(j :: jv.Json, key :: Str, default :: Int) -> Int {
  match jv.get_field(j, key) {
    Some(JInt(n)) => n,
    _             => default,
  }
}

# ---- Entry point -------------------------------------------------

fn main() -> [net, io, time, sql, fs_write, env] Nil {
  let path := db_path()
  let _ := io.print("=== Depot CSMS (OCPP 1.6, SQLite, lex-web) ===")
  let _ := io.print("    ws://localhost:9000/ocpp/<cp_id>")
  let _ := io.print(str.concat("    db:   ", path))
  let _ := io.print("    tags: USER-001 ... USER-010")
  match sql.open(path) {
    Err(e) => io.print(str.concat("! sql.open: ", e.message)),
    Ok(db) => match init_db(db) {
      Err(e) => io.print(str.concat("! schema init: ", e.message)),
      Ok(_)  => {
        let _ := io.print("    schema ready; accepting connections...")
        net.serve_ws_fn(9000, cp.version_v16(), build_on_message(db))
      },
    },
  }
}
