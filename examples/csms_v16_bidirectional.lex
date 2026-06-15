# lex-ocpp example — OCPP 1.6 bidirectional CSMS (CS→CP command dispatch)
#
# Extends csms_v16_sqlite.lex with full CS→CP command support:
#
#   - Two extra DDL tables:
#       pending_commands  — CS→CP frames queued for delivery
#       cs_to_cp_log      — completed CS→CP exchanges (sent frame + response)
#   - Proper FrameCallResult dispatch: matches message_id back to the
#     pending_commands table to record the CP's response.
#   - Outbound command delivery via Heartbeat piggyback: when the CP
#     sends a Heartbeat and there is a pending command for that CP, the
#     CSMS replies with the pending command frame instead of the
#     Heartbeat.conf.  The Heartbeat.conf is intentionally omitted for
#     that tick; the CP will send another Heartbeat on its next cycle.
#
# Note on the piggyback constraint
# ---------------------------------
# lex-web's `serve_ws_fn` returns a single WsAction per inbound frame
# (alpibrusl/lex-web#4 tracks outbound server-push). The piggyback
# pattern is the cleanest workaround available today:
#   1. CP sends Heartbeat → CSMS replies with pending CS→CP Call
#   2. CP processes Call → sends CallResult (matched by message_id)
#   3. CSMS records result in cs_to_cp_log, removes from pending_commands
# Commands are enqueued by inserting a row into pending_commands
# (e.g. via `sqlite3 /tmp/csms.db "INSERT INTO pending_commands ..."`)
# while the CSMS is running.
#
# Run:
#   lex run --allow-effects net,io,time,sql,fs_write,env \
#     examples/csms_v16_bidirectional.lex main
#
# Queue a RemoteStartTransaction for CP-001:
#   sqlite3 /tmp/csms.db \
#     "INSERT INTO pending_commands (cp_id,message_id,action,frame)
#      VALUES ('CP-001','msg-rmt-01','RemoteStartTransaction',
#        '[2,\"msg-rmt-01\",\"RemoteStartTransaction\",{\"idTag\":\"USER-001\"}]');"

import "std.io" as io

import "std.net" as net

import "std.str" as str

import "std.int" as int

import "std.list" as list

import "std.sql" as sql

import "std.env" as env

import "std.time" as time

import "lex-schema/json_value" as jv

import "../src/messages" as msg

import "../src/error" as oe

import "../src/route" as route

import "../src/charge_point" as cp

import "../src/v16/action" as a

import "../src/v16/enums" as en

import "../src/v16/schemas" as sch

import "../src/v16/commands" as cmd

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

fn ddl_pending_commands() -> Str {
  "CREATE TABLE IF NOT EXISTS pending_commands (\n     id         INTEGER PRIMARY KEY AUTOINCREMENT,\n     cp_id      TEXT NOT NULL,\n     message_id TEXT NOT NULL UNIQUE,\n     action     TEXT NOT NULL,\n     frame      TEXT NOT NULL,\n     queued_at  TEXT NOT NULL\n   )"
}

fn ddl_cs_to_cp_log() -> Str {
  "CREATE TABLE IF NOT EXISTS cs_to_cp_log (\n     id          INTEGER PRIMARY KEY AUTOINCREMENT,\n     cp_id       TEXT NOT NULL,\n     message_id  TEXT NOT NULL,\n     action      TEXT NOT NULL,\n     sent_frame  TEXT NOT NULL,\n     status      TEXT,\n     response_json TEXT,\n     sent_at     TEXT NOT NULL,\n     responded_at TEXT\n   )"
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
            Ok(_) => match sql.exec(db, ddl_pending_commands(), []) {
              Err(e) => Err(e),
              Ok(_) => match sql.exec(db, ddl_cs_to_cp_log(), []) {
                Err(e) => Err(e),
                Ok(_) => seed_allowed_tags(db),
              },
            },
          },
        },
      },
    },
  }
}

fn seed_allowed_tags(db :: Db) -> [sql] Result[Unit, SqlError] {
  match sql.exec(db, "INSERT OR IGNORE INTO allowed_tags (id_tag, description) VALUES (?, ?)", [PStr("USER-001"), PStr("default demo card")]) {
    Err(e) => Err(e),
    Ok(_) => Ok(()),
  }
}

# ---- WS path → cp_id ---------------------------------------------
fn cp_id_from_path(path :: Str) -> Str {
  match str.strip_prefix(path, "/ocpp/") {
    Some(id) => id,
    None => match str.strip_prefix(path, "/") {
      Some(id) => id,
      None => "unknown",
    },
  }
}

# ---- CP→CS handlers (identical to csms_v16_sqlite.lex) -----------
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

fn on_start_tx(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let conn_id := json_int_or(payload, "connectorId", 0)
  let id_tag := json_str_or(payload, "idTag", "")
  let m_start := json_int_or(payload, "meterStart", 0)
  let ts := json_str_or(payload, "timestamp", now)
  match sql.exec(db, "INSERT INTO transactions (cp_id, connector_id, id_tag, meter_start, start_ts)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), PInt(conn_id), PStr(id_tag), PInt(m_start), PStr(ts)]) {
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
  let tx_id := match jv.get_field(payload, "transactionId") {
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
  match sql.exec(db, "INSERT INTO meter_values (cp_id, transaction_id, connector_id, value_wh, ts)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), tx_param, PInt(conn_id), PInt(value_wh), PStr(ts)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([])),
  }
}

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

fn on_stop_tx(db :: Db, cp_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] route.HandlerResult {
  let tx_id := json_int_or(payload, "transactionId", 0)
  let m_stop := json_int_or(payload, "meterStop", 0)
  let ts := json_str_or(payload, "timestamp", now)
  let reason := json_str_or(payload, "reason", en.reason_local())
  let __lex_discard_6 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] StopTransaction tx=", str.concat(int.to_str(tx_id), str.concat(" reason=", reason))))))
  match sql.exec(db, "UPDATE transactions SET meter_stop=?, stop_ts=?, reason=?\n       WHERE id=? AND cp_id=?", [PInt(m_stop), PStr(ts), PStr(reason), PInt(tx_id), PStr(cp_id)]) {
    Err(e) => HErr(oe.internal_err(e.message)),
    Ok(_) => HOk(JObj([("idTagInfo", JObj([("status", JStr(en.auth_accepted()))]))])),
  }
}

fn on_data_transfer(_db :: Db, cp_id :: Str, _payload :: jv.Json, _now :: Str) -> [io, sql] route.HandlerResult {
  let __lex_discard_7 := io.print(str.concat("  [", str.concat(cp_id, "] DataTransfer (stub)")))
  HOk(JObj([("status", JStr(en.dt_accepted()))]))
}

# ---- Heartbeat with pending-command piggyback --------------------
#
# If there is a queued CS→CP command for this CP, return it instead
# of the Heartbeat.conf. The CP will miss one Heartbeat.conf (it
# retries on its next interval). The dequeued command is moved from
# pending_commands to cs_to_cp_log.
type PendingRow = { id :: Int, message_id :: Str, action :: Str, frame :: Str }

fn dequeue_pending(db :: Db, cp_id :: Str) -> [sql] Option[PendingRow] {
  let res :: Result[List[PendingRow], SqlError] := sql.query(db, "SELECT id, message_id, action, frame FROM pending_commands\n         WHERE cp_id=? ORDER BY id LIMIT 1", [PStr(cp_id)])
  match res {
    Err(_) => None,
    Ok(rows) => list.head(rows),
  }
}

fn mark_sent(db :: Db, row :: PendingRow, cp_id :: Str, now :: Str) -> [sql] Unit {
  let __lex_discard_8 := sql.exec(db, "INSERT INTO cs_to_cp_log\n       (cp_id, message_id, action, sent_frame, sent_at)\n       VALUES (?, ?, ?, ?, ?)", [PStr(cp_id), PStr(row.message_id), PStr(row.action), PStr(row.frame), PStr(now)])
  let __lex_discard_9 := sql.exec(db, "DELETE FROM pending_commands WHERE id=?", [PInt(row.id)])
  ()
}

fn on_heartbeat(db :: Db, cp_id :: Str, _payload :: jv.Json, now :: Str) -> [io, sql] Str {
  match dequeue_pending(db, cp_id) {
    None => {
      let __lex_discard_10 := io.print(str.concat("  [", str.concat(cp_id, "] Heartbeat")))
      msg.encode(msg.new_call_result("heartbeat", JObj([("currentTime", JStr(now))])))
    },
    Some(row) => {
      let __lex_discard_11 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] → sending pending command ", row.action))))
      let __lex_discard_12 := mark_sent(db, row, cp_id, now)
      row.frame
    },
  }
}

# ---- CS→CP CallResult dispatch -----------------------------------
#
# When the CP responds to a CS→CP command, match message_id back to
# cs_to_cp_log and record the response.
fn on_call_result(db :: Db, cp_id :: Str, message_id :: Str, payload :: jv.Json, now :: Str) -> [io, sql] Unit {
  let payload_str := jv.stringify(payload)
  let status := match jv.get_field(payload, "status") {
    Some(JStr(s)) => s,
    _ => "ok",
  }
  let __lex_discard_13 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] CallResult msg=", str.concat(message_id, str.concat(" status=", status))))))
  let __lex_discard_14 := sql.exec(db, "UPDATE cs_to_cp_log\n       SET status=?, response_json=?, responded_at=?\n       WHERE cp_id=? AND message_id=?", [PStr(status), PStr(payload_str), PStr(now), PStr(cp_id), PStr(message_id)])
  ()
}

# ---- CP→CS dispatch ----------------------------------------------
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
              msg.new_call_result(message_id, JObj([("currentTime", JStr(now))]))
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
                  let __lex_discard_15 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] NotImplemented: ", action))))
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
  let now := time.now_str()
  match msg.parse(raw) {
    Err(fe) => msg.encode(msg.new_call_error("", fe.code, fe.message, JObj([]))),
    Ok(FrameCall(c)) => {
      if c.action == a.heartbeat() {
        on_heartbeat(db, cp_id, c.payload, now)
      } else {
        msg.encode(dispatch_call(db, cp_id, c.action, c.message_id, c.payload, now))
      }
    },
    Ok(FrameCallResult(r)) => {
      let __lex_discard_16 := on_call_result(db, cp_id, r.message_id, r.payload, now)
      ""
    },
    Ok(FrameCallError(er)) => {
      let __lex_discard_17 := io.print(str.concat("  [", str.concat(cp_id, str.concat("] inbound CallError: ", er.description))))
      ""
    },
  }
}

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
        let __lex_discard_18 := io.print(str.concat("  [", str.concat(cp_id, "] connection closed")))
        WsNoOp
      },
      WsPing => WsNoOp,
      WsBinary(_) => WsNoOp,
    }
  }
}

# ---- Helpers -------------------------------------------------------
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

# ---- Entry point --------------------------------------------------
fn main() -> [net, io, time, sql, fs_write, env] Nil {
  let path := db_path()
  let __lex_discard_19 := io.print("CSMS v1.6 (bidirectional)  ws://localhost:9000/ocpp/<cp_id>")
  let __lex_discard_20 := io.print(str.concat("  db: ", path))
  match sql.open(path) {
    Err(e) => io.print(str.concat("  ! sql.open failed: ", e.message)),
    Ok(db) => match init_db(db) {
      Err(e) => io.print(str.concat("  ! schema init failed: ", e.message)),
      Ok(_) => {
        let __lex_discard_21 := io.print("  schema ready; queue commands via pending_commands table")
        net.serve_ws_fn(9000, cp.version_v16(), build_on_message(db))
      },
    },
  }
}

