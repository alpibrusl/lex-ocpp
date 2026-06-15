# lex-ocpp example — minimal v2.0.1 CSMS over WebSocket
#
# Smaller surface than the v1.6 example: a CSMS that handles the
# half-dozen Calls every OCPP 2.0.1 charging station must send at
# minimum (BootNotification, Heartbeat, Authorize, StatusNotification,
# TransactionEvent, MeterValues).
#
# Run:
#   lex run --allow-effects net,io,time examples/csms_v201.lex main
#
# The WebSocket subprotocol is "ocpp2.0.1"; chargers should connect to
#   ws://localhost:9001/ocpp/<charger-id>

import "std.io" as io

import "std.net" as net

import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages" as msg

import "../src/route" as route

import "../src/charge_point" as cp

import "../src/v201/action" as a

import "../src/v201/enums" as en

import "../src/v201/schemas" as sch

# ---- Handlers ---------------------------------------------------
fn on_boot_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z")), ("interval", JInt(300)), ("status", JStr(en.reg_accepted()))]))
}

fn on_heartbeat(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn on_authorize(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("idTokenInfo", JObj([("status", JStr(en.auth_accepted()))]))]))
}

fn on_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_transaction_event(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_meter_values(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_data_transfer(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.dt_accepted()))]))
}

fn on_security_event_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_firmware_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

# ---- Registry ----------------------------------------------------
fn central_system() -> cp.ChargePoint {
  ((((((((cp.new_v201("csms-example") |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.boot_notification(), sch.validate_boot_notification_req, on_boot_notification)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.heartbeat(), sch.validate_heartbeat_req, on_heartbeat)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.authorize(), sch.validate_authorize_req, on_authorize)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.status_notification(), sch.validate_status_notification_req, on_status_notification)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.transaction_event(), sch.validate_transaction_event_req, on_transaction_event)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.meter_values(), sch.validate_meter_values_req, on_meter_values)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.data_transfer(), sch.validate_data_transfer_req, on_data_transfer)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.security_event_notification(), sch.validate_security_event_notification_req, on_security_event_notification)
  }) |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
    cp.handler_with_schema(c, a.firmware_status_notification(), sch.validate_firmware_status_notification_req, on_firmware_status_notification)
  }
}

# ---- WebSocket adapter -----------------------------------------
fn on_message(_conn :: WsConn, m :: WsMessage) -> WsAction {
  match m {
    WsText(raw) => match cp.handle_raw(central_system(), raw) {
      Ok(out) => WsSend(out),
      Err(fe) => WsSend(msg.encode(msg.new_call_error("", fe.code, fe.message, JObj([])))),
    },
    WsClose => WsNoOp,
    _ => WsNoOp,
  }
}

# ---- Entry point -----------------------------------------------
fn main() -> [net, io, time] Nil {
  let __lex_discard_1 := io.print("CSMS v2.0.1  ws://localhost:9001/ocpp/<charger-id>")
  net.serve_ws_fn(9001, cp.version_v201(), on_message)
}

