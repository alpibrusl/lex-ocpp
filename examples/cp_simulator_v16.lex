# lex-ocpp example — OCPP 1.6 charge-point simulator (over WebSocket)
#
# A runnable charge point that dials out to a CSMS over `ws://` and
# replays a full charging session:
#
#     BootNotification
#         ↓ CallResult
#     StatusNotification(Available)
#         ↓
#     Authorize(idTag=USER-001)
#         ↓
#     StartTransaction
#         ↓ (txId comes back in the result; we thread it
#           through subsequent message IDs)
#     MeterValues  ──→  Heartbeat  ──→  StopTransaction
#         ↓
#     StatusNotification(Available)   # session done
#
# Pair this with `examples/csms_v16.lex` (or csms_v16_stateful.lex
# adapted for transport): start the CSMS first, then this simulator.
#
#   # Terminal A  — CSMS
#   lex run --allow-effects net,io,time examples/csms_v16.lex main
#
#   # Terminal B — Charge point simulator
#   lex run --allow-effects net,io,time \
#     examples/cp_simulator_v16.lex main
#
# The on_open / on_message callbacks are stateless (Lex has no mutable
# globals), so the session state machine is encoded **in the OCPP
# message ID** that the CSMS echoes back. Each step looks at the
# inbound CallResult's message_id to decide what to send next; the
# transactionId returned by StartTransaction is encoded into the IDs
# of subsequent frames (e.g. "stop:42") so StopTransaction can recover
# it from its own message_id without needing shared state.
#
# Effects:
#   - [net] for net.dial_ws
#   - [io]  for io.print logging
#   - [time] currently unused; reserved for `time.now_str()` when the
#           example is extended to drive periodic Heartbeats from a
#           timer rather than the response chain.
#
# Notes:
#   - `WsAction` only carries `WsSend`, `WsSendBinary`, and `WsNoOp` —
#     there's no client-initiated `WsClose` (#TODO upstream). The
#     simulator emits `WsNoOp` at the end of the script; press Ctrl-C
#     to terminate the process.
#   - CSMS-initiated Calls (e.g. RemoteStartTransaction) are answered
#     with a stub `{status: "Accepted"}` CallResult so the demo
#     survives an interactive CSMS poking at it.

import "std.io"   as io
import "std.net"  as net
import "std.str"  as str
import "std.int"  as int
import "std.list" as list
import "std.env"  as env

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/charge_point"  as cp
import "../src/v16/enums"     as en

# ---- Configuration -----------------------------------------------
#
# `CP_ID` and `ID_TAG` come from the environment so multiple
# simulator processes can dial the same CSMS with distinct identities:
#
#   CP_ID=CP-001 ID_TAG=USER-001 lex run ... examples/cp_simulator_v16.lex main
#   CP_ID=CP-002 ID_TAG=USER-002 lex run ... examples/cp_simulator_v16.lex main
#
# Defaults preserve the single-CP run-and-go behaviour for users who
# just want to point a simulator at csms_v16.lex without setting env.

fn default_cp_id() -> Str { "SIM-CP-001" }
fn default_id_tag() -> Str { "USER-001" }

# Snapshot of the per-process identity, read once in `main` from env
# and threaded through every frame builder. Keeping it as a record
# (rather than a `()->[env]` lookup at each call site) means the
# `on_open` / `on_message` closures only need `[io]`, not `[io, env]`,
# which keeps dial_ws's effect row clean.
type Config = {
  cp_id  :: Str,
  id_tag :: Str,
}

fn config_from_env() -> [env] Config {
  let cp := match env.get("CP_ID") { Some(v) => v, None => default_cp_id() }
  let it := match env.get("ID_TAG") { Some(v) => v, None => default_id_tag() }
  { cp_id: cp, id_tag: it }
}

fn csms_url_for(cp :: Str) -> Str {
  str.concat("ws://localhost:9000/ocpp/", cp)
}

fn vendor() -> Str { "ACME" }
fn model()  -> Str { "Model-X-Sim" }
fn connector_id() -> Int { 1 }
fn meter_start_wh() -> Int { 0 }
fn meter_stop_wh()  -> Int { 15000 }
fn sample_wh()      -> Int { 7500 }

# Hardcoded timestamps keep the example deterministic. Swap for
# `time.now_str()` if you want real wall-clock values (and add
# `[time]` to every handler in the chain).
fn ts_start()  -> Str { "2026-05-15T08:00:00Z" }
fn ts_sample() -> Str { "2026-05-15T08:30:00Z" }
fn ts_stop()   -> Str { "2026-05-15T09:00:00Z" }

# ---- Frame builders (charge-point side) --------------------------

fn boot_call(mid :: Str) -> Str {
  msg.encode(msg.new_call(mid, "BootNotification",
    JObj([
      ("chargePointVendor", JStr(vendor())),
      ("chargePointModel",  JStr(model())),
    ])))
}

fn status_call(mid :: Str, status :: Str) -> Str {
  msg.encode(msg.new_call(mid, "StatusNotification",
    JObj([
      ("connectorId", JInt(connector_id())),
      ("errorCode",   JStr(en.ec_no_error())),
      ("status",      JStr(status)),
    ])))
}

fn authorize_call(mid :: Str, id_tag :: Str) -> Str {
  msg.encode(msg.new_call(mid, "Authorize",
    JObj([("idTag", JStr(id_tag))])))
}

fn start_call(mid :: Str, id_tag :: Str) -> Str {
  msg.encode(msg.new_call(mid, "StartTransaction",
    JObj([
      ("connectorId", JInt(connector_id())),
      ("idTag",       JStr(id_tag)),
      ("meterStart",  JInt(meter_start_wh())),
      ("timestamp",   JStr(ts_start())),
    ])))
}

fn meter_call(mid :: Str, tx_id :: Int) -> Str {
  # The "value" field in MeterValues / SampledValue is wire-typed as
  # a Str in OCPP 1.6 (not an Int) — render the integer accordingly.
  # `transactionId` is optional in OCPP 1.6 MeterValues; including it
  # lets a stateful CSMS correlate the row with the right transaction.
  msg.encode(msg.new_call(mid, "MeterValues",
    JObj([
      ("connectorId",   JInt(connector_id())),
      ("transactionId", JInt(tx_id)),
      ("meterValue",  JList([
        JObj([
          ("timestamp",    JStr(ts_sample())),
          ("sampledValue", JList([
            JObj([("value", JStr(int.to_str(sample_wh())))]),
          ])),
        ]),
      ])),
    ])))
}

fn heartbeat_call(mid :: Str) -> Str {
  msg.encode(msg.new_call(mid, "Heartbeat", JObj([])))
}

fn stop_call(mid :: Str, tx_id :: Int) -> Str {
  msg.encode(msg.new_call(mid, "StopTransaction",
    JObj([
      ("transactionId", JInt(tx_id)),
      ("meterStop",     JInt(meter_stop_wh())),
      ("timestamp",     JStr(ts_stop())),
      ("reason",        JStr(en.reason_local())),
    ])))
}

# Stub reply to any CSMS-initiated Call — most v1.6 commands accept
# `{status: "Accepted"}` so it's enough for an interactive smoke test.
fn stub_call_result(mid :: Str) -> Str {
  msg.encode(msg.new_call_result(mid,
    JObj([("status", JStr("Accepted"))])))
}

# ---- Step identifiers --------------------------------------------
#
# These string constants form the state machine that lives in the
# message IDs we send. The CSMS echoes each ID back in the matching
# CallResult, so `next_step(inbound_id)` is deterministic.

fn step_boot()         -> Str { "boot" }
fn step_status_init()  -> Str { "status:init" }
fn step_auth()         -> Str { "auth" }
fn step_start()        -> Str { "start" }
fn step_status_final() -> Str { "status:final" }

# Steps that carry a transaction id forward use a "kind:tx" suffix.
fn step_meter(tx :: Int)      -> Str { str.concat("meter:tx",     int_str(tx)) }
fn step_heartbeat(tx :: Int)  -> Str { str.concat("heartbeat:tx", int_str(tx)) }
fn step_stop(tx :: Int)       -> Str { str.concat("stop:tx",      int_str(tx)) }

# ---- Inbound dispatch -------------------------------------------

fn on_open() -> [io] WsAction {
  let _ := io.print("→ open: sending BootNotification")
  WsSend(boot_call(step_boot()))
}

fn on_text(raw :: Str, id_tag :: Str) -> [io] WsAction {
  let _ := io.print(str.concat("← ", raw))
  match msg.parse(raw) {
    Err(fe) => {
      let _ := io.print(str.concat("! parse error: ", fe.message))
      WsNoOp
    },
    Ok(FrameCallResult(r)) => on_result(r.message_id, r.payload, id_tag),
    Ok(FrameCallError(e))  => {
      let _ := io.print(str.concat("! CallError ",
        str.concat(e.error_code, str.concat(": ", e.description))))
      WsNoOp
    },
    Ok(FrameCall(c))       => {
      # CSMS sent us a Call (e.g. RemoteStartTransaction). Reply with
      # a stub `Accepted`. The simulator doesn't model the full CP
      # surface; extend this with `route.dispatch` if you need to.
      let _ := io.print(str.concat("  (stub-replying to CSMS Call: ", c.action))
      WsSend(stub_call_result(c.message_id))
    },
  }
}

# Decide the next outbound Call from the inbound CallResult's
# message_id. Unrecognised IDs end the session (WsNoOp).
fn on_result(mid :: Str, payload :: jv.Json, id_tag :: Str) -> [io] WsAction {
  if mid == step_boot() {
    emit("StatusNotification(Available)", status_call(step_status_init(),
      en.cp_available()))
  } else { if mid == step_status_init() {
    emit("Authorize", authorize_call(step_auth(), id_tag))
  } else { if mid == step_auth() {
    if authorize_accepted(payload) {
      emit("StartTransaction", start_call(step_start(), id_tag))
    } else {
      let _ := io.print(str.concat(
        "× Authorize rejected; session aborts. idTagInfo: ",
        jv.stringify(payload)))
      WsNoOp
    }
  } else { if mid == step_start() {
    # Extract transactionId from the StartTransaction response.
    let tx := tx_id_from(payload)
    emit("MeterValues", meter_call(step_meter(tx), tx))
  } else {
    on_result_tx(mid)
  } } } }
}

# The tx-carrying steps. Pulls the txId back out of the inbound
# message_id so we can pass it forward.
fn on_result_tx(mid :: Str) -> [io] WsAction {
  let tx := tx_from_step_id(mid)
  if starts_with(mid, "meter:tx") {
    emit("Heartbeat", heartbeat_call(step_heartbeat(tx)))
  } else { if starts_with(mid, "heartbeat:tx") {
    emit("StopTransaction", stop_call(step_stop(tx), tx))
  } else { if starts_with(mid, "stop:tx") {
    emit("StatusNotification(Available)",
         status_call(step_status_final(), en.cp_available()))
  } else { if mid == step_status_final() {
    let _ := io.print("=== session complete; idling (Ctrl-C to exit) ===")
    WsNoOp
  } else {
    let _ := io.print(str.concat("? unknown step id: ", mid))
    WsNoOp
  } } } }
}

fn emit(label :: Str, frame :: Str) -> [io] WsAction {
  let _ := io.print(str.concat("→ ", str.concat(label, str.concat(": ", frame))))
  WsSend(frame)
}

# ---- Tiny helpers (kept inline — no `[io]`, no `[time]`) -------

# StartTransaction response payload: `{"transactionId": 42, ...}`.
# Default to 0 if missing so the session keeps progressing under
# adversarial / partial CSMS implementations.
fn tx_id_from(payload :: jv.Json) -> Int {
  match jv.get_field(payload, "transactionId") {
    Some(JInt(n)) => n,
    _             => 0,
  }
}

# Authorize response is `{"idTagInfo":{"status":"Accepted"|"Invalid"|...}}`.
# Only "Accepted" lets the CP proceed to StartTransaction.
fn authorize_accepted(payload :: jv.Json) -> Bool {
  match jv.get_field(payload, "idTagInfo") {
    Some(info) => match jv.get_field(info, "status") {
      Some(JStr(s)) => s == en.auth_accepted(),
      _             => false,
    },
    None => false,
  }
}

# Recover the numeric tx suffix from an id like "meter:tx42".
# Returns 0 on unexpected shape — caller treats that as a noop step.
fn tx_from_step_id(mid :: Str) -> Int {
  match list.head(list.tail(str.split(mid, ":tx"))) {
    Some(n) => str_to_int_or(n, 0),
    None    => 0,
  }
}

# `str.to_int` returns `Option[Int]`; collapse to a default.
fn str_to_int_or(s :: Str, default :: Int) -> Int {
  match str.to_int(s) {
    Some(n) => n,
    None    => default,
  }
}

# Lex's int→str lives in std.int; one-arg wrapper keeps the call sites
# in `step_meter` etc. terse.
fn int_str(n :: Int) -> Str { int.to_str(n) }

fn starts_with(s :: Str, prefix :: Str) -> Bool {
  str.starts_with(s, prefix)
}

# ---- Entry point -------------------------------------------------

fn make_on_message(
  id_tag :: Str
) -> (WsMessage) -> [io] WsAction {
  fn (m :: WsMessage) -> [io] WsAction {
    match m {
      WsText(raw) => on_text(raw, id_tag),
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
  let _ := io.print(str.concat("=== cp_simulator_v16 [", str.concat(cfg.cp_id,
            str.concat("] → ", url))))
  let _ := io.print(str.concat("    subprotocol: ", cp.version_v16()))
  let _ := io.print(str.concat("    id_tag: ",      cfg.id_tag))
  match net.dial_ws(url, cp.version_v16(), on_open, make_on_message(cfg.id_tag)) {
    Ok(_)  => io.print("dial finished cleanly"),
    Err(e) => io.print(str.concat("dial failed: ", e)),
  }
}
