# lex-ocpp example — Timed OCPP 1.6 charge-point simulator
#
# Like cp_simulator_v16.lex but drives a real 60-second charging session
# using time.sleep_ms between steps:
#
#   Boot → StatusNotification(Available) → Authorize → StartTransaction
#     ── sleep 20 s ──
#   MeterValues  (sample 1 of 2, 83 Wh cumulative)
#     ── sleep 20 s ──
#   MeterValues  (sample 2 of 2, 167 Wh cumulative)
#     ── sleep 20 s ──
#   StopTransaction (250 Wh total) → StatusNotification(Available)
#
# Energy model: 15 kW charger running for 60 s = 250 Wh
#   sample at 20 s → 83 Wh   (≈ 15 000 W × 20 / 3600)
#   sample at 40 s → 167 Wh
#   stop    at 60 s → 250 Wh
#
# Run via the depot orchestrator:
#   bash examples/run_depot.sh
#
# Or standalone:
#   CP_ID=CP-001 ID_TAG=USER-001 \
#     lex run --allow-effects net,io,time,env \
#     examples/cp_simulator_v16_timed.lex main

import "std.io"   as io
import "std.net"  as net
import "std.str"  as str
import "std.int"  as int
import "std.list" as list
import "std.time" as time
import "std.env"  as env

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/charge_point"  as cp
import "../src/v16/enums"     as en

# ---- Configuration -----------------------------------------------

fn default_cp_id()  -> Str { "SIM-CP-001" }
fn default_id_tag() -> Str { "USER-001" }

type Config = {
  cp_id  :: Str,
  id_tag :: Str,
}

fn config_from_env() -> [env] Config {
  let c := match env.get("CP_ID")  { Some(v) => v, None => default_cp_id()  }
  let t := match env.get("ID_TAG") { Some(v) => v, None => default_id_tag() }
  { cp_id: c, id_tag: t }
}

fn csms_url_for(cp_id :: Str) -> Str {
  str.concat("ws://localhost:9000/ocpp/", cp_id)
}

# ---- Energy / timing constants -----------------------------------
#
# 15 kW charger, 60-second session → 250 Wh total.
# Two intermediate samples at 20 s and 40 s.

fn vendor() -> Str { "ACME" }
fn model()  -> Str { "Depot-Sim-15kW" }
fn connector_id() -> Int { 1 }

fn meter_start_wh()   -> Int { 0 }
fn meter_sample1_wh() -> Int { 83 }    # 20 s into session
fn meter_sample2_wh() -> Int { 167 }   # 40 s into session
fn meter_stop_wh()    -> Int { 250 }   # 60 s, session complete

fn sample_interval_ms() -> Int { 20000 }   # 20 s between samples

# ---- Frame builders ----------------------------------------------

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

fn start_call(mid :: Str, id_tag :: Str, ts :: Str) -> Str {
  msg.encode(msg.new_call(mid, "StartTransaction",
    JObj([
      ("connectorId", JInt(connector_id())),
      ("idTag",       JStr(id_tag)),
      ("meterStart",  JInt(meter_start_wh())),
      ("timestamp",   JStr(ts)),
    ])))
}

fn meter_call(mid :: Str, tx_id :: Int, wh :: Int, ts :: Str) -> Str {
  msg.encode(msg.new_call(mid, "MeterValues",
    JObj([
      ("connectorId",   JInt(connector_id())),
      ("transactionId", JInt(tx_id)),
      ("meterValue", JList([
        JObj([
          ("timestamp",    JStr(ts)),
          ("sampledValue", JList([
            JObj([("value", JStr(int.to_str(wh)))]),
          ])),
        ]),
      ])),
    ])))
}

fn heartbeat_call(mid :: Str) -> Str {
  msg.encode(msg.new_call(mid, "Heartbeat", JObj([])))
}

fn stop_call(mid :: Str, tx_id :: Int, ts :: Str) -> Str {
  msg.encode(msg.new_call(mid, "StopTransaction",
    JObj([
      ("transactionId", JInt(tx_id)),
      ("meterStop",     JInt(meter_stop_wh())),
      ("timestamp",     JStr(ts)),
      ("reason",        JStr(en.reason_local())),
    ])))
}

fn stub_call_result(mid :: Str) -> Str {
  msg.encode(msg.new_call_result(mid,
    JObj([("status", JStr("Accepted"))])))
}

# ---- Step identifiers --------------------------------------------
#
# State machine encoded in OCPP message IDs (echoed by CSMS).
# tx-carrying steps use "kind:txN" so the handler can parse N back
# without shared mutable state.

fn step_boot()         -> Str { "boot" }
fn step_status_init()  -> Str { "status:init" }
fn step_auth()         -> Str { "auth" }
fn step_start()        -> Str { "start" }
fn step_status_final() -> Str { "status:final" }

fn step_meter1(tx :: Int)     -> Str { str.concat("meter1:tx", int.to_str(tx)) }
fn step_meter2(tx :: Int)     -> Str { str.concat("meter2:tx", int.to_str(tx)) }
fn step_heartbeat(tx :: Int)  -> Str { str.concat("heartbeat:tx", int.to_str(tx)) }
fn step_stop(tx :: Int)       -> Str { str.concat("stop:tx",      int.to_str(tx)) }

# ---- Inbound dispatch --------------------------------------------

fn on_open() -> [io, time] WsAction {
  let _ := io.print("-> open: sending BootNotification")
  WsSend(boot_call(step_boot()))
}

fn on_text(raw :: Str, id_tag :: Str) -> [io, time] WsAction {
  let _ := io.print(str.concat("<- ", raw))
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
    Ok(FrameCall(c)) => {
      let _ := io.print(str.concat("  (stub reply to CSMS Call: ", c.action))
      WsSend(stub_call_result(c.message_id))
    },
  }
}

fn on_result(mid :: Str, payload :: jv.Json, id_tag :: Str) -> [io, time] WsAction {
  if mid == step_boot() {
    emit("StatusNotification(Available)",
         status_call(step_status_init(), en.cp_available()))
  } else { if mid == step_status_init() {
    emit("Authorize", authorize_call(step_auth(), id_tag))
  } else { if mid == step_auth() {
    if authorize_accepted(payload) {
      let ts := time.now_str()
      emit("StartTransaction", start_call(step_start(), id_tag, ts))
    } else {
      let _ := io.print("x Authorize rejected; aborting")
      WsNoOp
    }
  } else { if mid == step_start() {
    let tx := tx_id_from(payload)
    let _  := io.print(str.concat("  [sleeping 20s before MeterValues #1, tx=",
                int.to_str(tx)))
    let _  := time.sleep_ms(sample_interval_ms())
    let ts := time.now_str()
    emit("MeterValues #1", meter_call(step_meter1(tx), tx, meter_sample1_wh(), ts))
  } else {
    on_result_tx(mid)
  } } } }
}

# Handle the tx-carrying steps (meter1, meter2, heartbeat, stop, final status).
fn on_result_tx(mid :: Str) -> [io, time] WsAction {
  let tx := tx_from_step_id(mid)
  if str.starts_with(mid, "meter1:tx") {
    let _ := io.print(str.concat("  [sleeping 20s before MeterValues #2, tx=",
               int.to_str(tx)))
    let _ := time.sleep_ms(sample_interval_ms())
    let ts := time.now_str()
    emit("MeterValues #2", meter_call(step_meter2(tx), tx, meter_sample2_wh(), ts))
  } else { if str.starts_with(mid, "meter2:tx") {
    let _ := io.print(str.concat("  [sleeping 20s before StopTransaction, tx=",
               int.to_str(tx)))
    let _ := time.sleep_ms(sample_interval_ms())
    let ts := time.now_str()
    emit("StopTransaction", stop_call(step_stop(tx), tx, ts))
  } else { if str.starts_with(mid, "heartbeat:tx") {
    let ts := time.now_str()
    emit("StopTransaction", stop_call(step_stop(tx), tx, ts))
  } else { if str.starts_with(mid, "stop:tx") {
    emit("StatusNotification(Available)",
         status_call(step_status_final(), en.cp_available()))
  } else { if mid == step_status_final() {
    let _ := io.print("=== session complete (60s, 250 Wh); connection idle ===")
    WsNoOp
  } else {
    let _ := io.print(str.concat("? unknown step id: ", mid))
    WsNoOp
  } } } } }
}

fn emit(label :: Str, frame :: Str) -> [io] WsAction {
  let _ := io.print(str.concat("-> ", str.concat(label, str.concat(": ", frame))))
  WsSend(frame)
}

# ---- Helpers -----------------------------------------------------

fn tx_id_from(payload :: jv.Json) -> Int {
  match jv.get_field(payload, "transactionId") {
    Some(JInt(n)) => n,
    _             => 0,
  }
}

fn authorize_accepted(payload :: jv.Json) -> Bool {
  match jv.get_field(payload, "idTagInfo") {
    Some(info) => match jv.get_field(info, "status") {
      Some(JStr(s)) => s == en.auth_accepted(),
      _             => false,
    },
    None => false,
  }
}

# Parse txId from "meter1:tx42" → 42.
fn tx_from_step_id(mid :: Str) -> Int {
  match list.head(list.tail(str.split(mid, ":tx"))) {
    Some(n) => match str.to_int(n) { Some(i) => i, None => 0 },
    None    => 0,
  }
}

# ---- Entry point -------------------------------------------------

fn make_on_message(
  id_tag :: Str
) -> (WsMessage) -> [io, time] WsAction {
  fn (m :: WsMessage) -> [io, time] WsAction {
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

fn main() -> [net, io, time, env] Nil {
  let cfg := config_from_env()
  let url := csms_url_for(cfg.cp_id)
  let _ := io.print(str.concat("=== timed depot sim [", str.concat(cfg.cp_id,
            str.concat("] -> ", url))))
  let _ := io.print(str.concat("    id_tag: ", cfg.id_tag))
  let _ := io.print("    session: 60s | 2x MeterValues | 250 Wh @ 15 kW")
  match net.dial_ws(url, cp.version_v16(), on_open, make_on_message(cfg.id_tag)) {
    Ok(_)  => io.print("dial finished"),
    Err(e) => io.print(str.concat("dial failed: ", e)),
  }
}
