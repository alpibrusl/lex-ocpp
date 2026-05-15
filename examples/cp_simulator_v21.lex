# lex-ocpp example — OCPP 2.1 charge-point simulator (over WebSocket)
#
# Sibling of `cp_simulator_v16.lex` for the OCPP 2.1 wire protocol.
# Pair this with `examples/csms_v21.lex`:
#
#   # Terminal A — OCPP 2.1 CSMS
#   lex run --allow-effects net,io,time examples/csms_v21.lex main
#
#   # Terminal B — charge point
#   CP_ID=CS-001 ID_TOKEN=USER-001 \
#     lex run --allow-effects net,io,env examples/cp_simulator_v21.lex main
#
# Differences from the 1.6 simulator:
#   - Subprotocol `ocpp2.1`, port 9002 (csms_v21.lex default).
#   - `BootNotification.chargingStation` carries vendorName/model (and
#     2.1 mandates a `reason` enum value, e.g. "PowerUp").
#   - `Authorize` takes an `idToken` *record* (`{idToken, type}`), not
#     a bare `idTag` string. Authorize response key is `idTokenInfo`.
#   - **`TransactionEvent` replaces Start/StopTransaction.** A single
#     action with `eventType` in {Started, Updated, Ended} carries the
#     transaction state machine; the CP assigns `transactionId` (a
#     Str, not Int), CSMS just acks.
#   - `StatusNotification` carries `connectorStatus`, `evseId`,
#     `connectorId`, `timestamp` — no `errorCode`.
#
# Session script:
#   BootNotification(reason=PowerUp)
#   StatusNotification(connectorStatus=Available)
#   Authorize(idToken=$ID_TOKEN, type=ISO14443)
#   TransactionEvent(eventType=Started,  seqNo=0, chargingState=Charging)
#   TransactionEvent(eventType=Updated,  seqNo=1, chargingState=Charging)
#   Heartbeat
#   TransactionEvent(eventType=Ended,    seqNo=2, stoppedReason=Local)
#   StatusNotification(connectorStatus=Available)

import "std.io"   as io
import "std.net"  as net
import "std.str"  as str
import "std.int"  as int
import "std.list" as list
import "std.env"  as env

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/charge_point"  as cp
import "../src/v21/enums"     as en

# ---- Configuration -----------------------------------------------

fn default_cp_id()    -> Str { "SIM-CS-001" }
fn default_id_token() -> Str { "USER-001" }

type Config = {
  cp_id    :: Str,
  id_token :: Str,
}

fn config_from_env() -> [env] Config {
  let cp_v := match env.get("CP_ID")    { Some(v) => v, None => default_cp_id() }
  let id_v := match env.get("ID_TOKEN") { Some(v) => v, None => default_id_token() }
  { cp_id: cp_v, id_token: id_v }
}

fn csms_url_for(cs :: Str) -> Str {
  str.concat("ws://localhost:9002/ocpp/", cs)
}

fn vendor()       -> Str { "ACME" }
fn model()        -> Str { "Model-X-Sim21" }
fn evse_id()      -> Int { 1 }
fn connector_id() -> Int { 1 }
fn meter_start_wh() -> Int { 0 }
fn meter_mid_wh()   -> Int { 7500 }
fn meter_stop_wh()  -> Int { 15000 }

# Hardcoded timestamps — swap for `time.now_str()` for live runs.
fn ts_boot()    -> Str { "2026-05-15T08:00:00Z" }
fn ts_tx_open() -> Str { "2026-05-15T08:00:05Z" }
fn ts_tx_mid()  -> Str { "2026-05-15T08:30:00Z" }
fn ts_tx_end()  -> Str { "2026-05-15T09:00:00Z" }

# The CP picks transactionId in 2.1 (string, ≤36 chars).
fn txn_id() -> Str { "txn-demo-1" }

# 2.1's authorization status enum returns "Accepted" for the happy
# path; csms_v21.lex stubs every Authorize to Accepted.
fn id_token_type() -> Str { "ISO14443" }

# ---- Frame builders ----------------------------------------------

fn boot_call(mid :: Str) -> Str {
  msg.encode(msg.new_call(mid, "BootNotification",
    JObj([
      ("chargingStation", JObj([
        ("model",      JStr(model())),
        ("vendorName", JStr(vendor())),
      ])),
      ("reason", JStr("PowerUp")),
    ])))
}

fn status_call(mid :: Str, status :: Str) -> Str {
  msg.encode(msg.new_call(mid, "StatusNotification",
    JObj([
      ("timestamp",       JStr(ts_boot())),
      ("connectorStatus", JStr(status)),
      ("evseId",          JInt(evse_id())),
      ("connectorId",     JInt(connector_id())),
    ])))
}

fn authorize_call(mid :: Str, id_token :: Str) -> Str {
  msg.encode(msg.new_call(mid, "Authorize",
    JObj([
      ("idToken", JObj([
        ("idToken", JStr(id_token)),
        ("type",    JStr(id_token_type())),
      ])),
    ])))
}

# In OCPP 2.1 `sampledValue.value` is a **number** (Float), unlike
# v1.6 where it was wire-typed as a string — the lex-schema validator
# rejects the v1.6 shape with PropertyConstraintViolation.
fn meter_value_obj(ts :: Str, wh :: Int) -> jv.Json {
  JObj([
    ("timestamp", JStr(ts)),
    ("sampledValue", JList([
      JObj([("value", JFloat(int.to_float(wh)))]),
    ])),
  ])
}

fn tx_event_call(
  mid           :: Str,
  event_type    :: Str,
  seq_no        :: Int,
  charging_state :: Str,
  stopped_reason :: Str,
  meter_ts      :: Str,
  meter_wh      :: Int,
  id_token      :: Str
) -> Str {
  let tx_info_base := [
    ("transactionId", JStr(txn_id())),
    ("chargingState", JStr(charging_state)),
  ]
  let tx_info := if stopped_reason == "" {
    tx_info_base
  } else {
    list.concat(tx_info_base, [("stoppedReason", JStr(stopped_reason))])
  }
  let id_token_obj := JObj([
    ("idToken", JStr(id_token)),
    ("type",    JStr(id_token_type())),
  ])
  msg.encode(msg.new_call(mid, "TransactionEvent",
    JObj([
      ("eventType",       JStr(event_type)),
      ("timestamp",       JStr(meter_ts)),
      ("seqNo",           JInt(seq_no)),
      ("transactionInfo", JObj(tx_info)),
      ("idToken",         id_token_obj),
      ("evse",            JObj([
        ("id",          JInt(evse_id())),
        ("connectorId", JInt(connector_id())),
      ])),
      ("meterValue",      JList([meter_value_obj(meter_ts, meter_wh)])),
    ])))
}

fn heartbeat_call(mid :: Str) -> Str {
  msg.encode(msg.new_call(mid, "Heartbeat", JObj([])))
}

fn stub_call_result(mid :: Str) -> Str {
  msg.encode(msg.new_call_result(mid,
    JObj([("status", JStr(en.gen_accepted()))])))
}

# ---- Step identifiers (same trick as v16: state in message_id) --

fn step_boot()         -> Str { "boot" }
fn step_status_init()  -> Str { "status:init" }
fn step_auth()         -> Str { "auth" }
fn step_tx_started()   -> Str { "tx:started" }
fn step_tx_updated()   -> Str { "tx:updated" }
fn step_heartbeat()    -> Str { "heartbeat" }
fn step_tx_ended()     -> Str { "tx:ended" }
fn step_status_final() -> Str { "status:final" }

# ---- Inbound dispatch -------------------------------------------

fn on_open() -> [io] WsAction {
  let _ := io.print("-> open: sending BootNotification (PowerUp)")
  WsSend(boot_call(step_boot()))
}

fn on_text(raw :: Str, id_token :: Str) -> [io] WsAction {
  let _ := io.print(str.concat("<- ", raw))
  match msg.parse(raw) {
    Err(fe) => {
      let _ := io.print(str.concat("! parse error: ", fe.message))
      WsNoOp
    },
    Ok(FrameCallResult(r)) => on_result(r.message_id, r.payload, id_token),
    Ok(FrameCallError(e))  => {
      let _ := io.print(str.concat("! CallError ",
        str.concat(e.error_code, str.concat(": ", e.description))))
      WsNoOp
    },
    Ok(FrameCall(c))       => {
      let _ := io.print(str.concat("  (stub-replying to CSMS Call: ", c.action))
      WsSend(stub_call_result(c.message_id))
    },
  }
}

fn on_result(mid :: Str, payload :: jv.Json, id_token :: Str) -> [io] WsAction {
  if mid == step_boot() {
    emit("StatusNotification(Available)",
         status_call(step_status_init(), en.cs_available()))
  } else { if mid == step_status_init() {
    emit("Authorize", authorize_call(step_auth(), id_token))
  } else { if mid == step_auth() {
    if authorize_accepted(payload) {
      emit("TransactionEvent(Started)",
           tx_event_call(step_tx_started(), "Started", 0,
             en.ch_charging(), "",
             ts_tx_open(), meter_start_wh(), id_token))
    } else {
      let _ := io.print(str.concat(
        "× Authorize rejected; aborting. idTokenInfo: ",
        jv.stringify(payload)))
      WsNoOp
    }
  } else { if mid == step_tx_started() {
    emit("TransactionEvent(Updated)",
         tx_event_call(step_tx_updated(), "Updated", 1,
           en.ch_charging(), "",
           ts_tx_mid(), meter_mid_wh(), id_token))
  } else { if mid == step_tx_updated() {
    emit("Heartbeat", heartbeat_call(step_heartbeat()))
  } else { if mid == step_heartbeat() {
    emit("TransactionEvent(Ended)",
         tx_event_call(step_tx_ended(), "Ended", 2,
           en.ch_idle(), "Local",
           ts_tx_end(), meter_stop_wh(), id_token))
  } else { if mid == step_tx_ended() {
    emit("StatusNotification(Available)",
         status_call(step_status_final(), en.cs_available()))
  } else { if mid == step_status_final() {
    let _ := io.print("=== session complete; idling (Ctrl-C to exit) ===")
    WsNoOp
  } else {
    let _ := io.print(str.concat("? unknown step id: ", mid))
    WsNoOp
  } } } } } } } }
}

fn emit(label :: Str, frame :: Str) -> [io] WsAction {
  let _ := io.print(str.concat("-> ", str.concat(label, str.concat(": ", frame))))
  WsSend(frame)
}

# ---- Authorize response check -----------------------------------
#
# v2.1 response payload: `{"idTokenInfo":{"status":"Accepted"|"Invalid"|...}}`.

fn authorize_accepted(payload :: jv.Json) -> Bool {
  match jv.get_field(payload, "idTokenInfo") {
    Some(info) => match jv.get_field(info, "status") {
      Some(JStr(s)) => s == en.auth_accepted(),
      _             => false,
    },
    None => false,
  }
}

# ---- Entry point ------------------------------------------------

fn make_on_message(
  id_token :: Str
) -> (WsMessage) -> [io] WsAction {
  fn (m :: WsMessage) -> [io] WsAction {
    match m {
      WsText(raw) => on_text(raw, id_token),
      WsClose     => {
        let _ := io.print("<- server closed connection")
        WsNoOp
      },
      WsPing      => WsNoOp,
      WsBinary(_) => WsNoOp,
    }
  }
}

fn main() -> [net, io, env] Nil {
  let cfg := config_from_env()
  let url := csms_url_for(cfg.cp_id)
  let _ := io.print(str.concat("=== cp_simulator_v21 [", str.concat(cfg.cp_id,
            str.concat("] -> ", url))))
  let _ := io.print(str.concat("    subprotocol: ", cp.version_v21()))
  let _ := io.print(str.concat("    id_token: ",    cfg.id_token))
  match net.dial_ws(url, cp.version_v21(), on_open, make_on_message(cfg.id_token)) {
    Ok(_)  => io.print("dial finished cleanly"),
    Err(e) => io.print(str.concat("dial failed: ", e)),
  }
}
