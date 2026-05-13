# lex-ocpp example — minimal v2.1 CSMS over WebSocket
#
# OCPP 2.1 over the same WS transport as v1.6 and v2.0.1. Wires
# handlers for the v2.1-specific Calls (battery swap, periodic
# event streams, DER control, allowed-energy-transfer, dynamic
# schedule, tariff change, priority charging) on top of the
# v2.0.1 carry-overs (boot / heartbeat / status / transaction /
# meter / authorize / data-transfer).
#
# Run:
#   lex run --allow-effects net,io,time examples/csms_v21.lex main
#
# The WebSocket subprotocol is "ocpp2.1"; bidirectional chargers
# should connect to:
#   ws://localhost:9002/ocpp/<charger-id>

import "std.io"   as io
import "std.net"  as net
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/route"         as route
import "../src/charge_point"  as cp
import "../src/v21/action"    as a
import "../src/v21/enums"     as en
import "../src/v21/schemas"   as sch

# ---- Handlers ---------------------------------------------------
#
# Carry-overs first, then 2.1 additions. Every handler is pure;
# real persistence / logging would plug in via `charge_point_io`
# and the [io, time, sql] effect upper bound.

fn on_boot(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("currentTime", JStr("2026-05-13T12:00:00Z")),
    ("interval",    JInt(300)),
    ("status",      JStr(en.reg_accepted())),
  ]))
}

fn on_heartbeat(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn on_authorize(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("idTokenInfo", JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_transaction_event(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_data_transfer(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.dt_accepted()))]))
}

# ---- 2.1 additions ----------------------------------------------

fn on_battery_swap(_payload :: jv.Json) -> route.HandlerResult {
  # BatterySwap.conf is empty. A real CSMS would persist the swap
  # event + battery telemetry; we just accept it here.
  route.ok(JObj([]))
}

fn on_notify_allowed_energy_transfer(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.gen_accepted()))]))
}

fn on_open_periodic_event_stream(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.pes_status_accepted()))]))
}

fn on_close_periodic_event_stream(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.pes_status_accepted()))]))
}

fn on_notify_periodic_event_stream(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_get_der_control(_payload :: jv.Json) -> route.HandlerResult {
  # A real CSMS would return the active DER control list. Stub here.
  route.ok(JObj([("status", JStr(en.der_status_accepted()))]))
}

fn on_set_der_control(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.der_status_accepted()))]))
}

fn on_clear_der_control(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.der_status_accepted()))]))
}

fn on_notify_der_alarm(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_notify_der_start_stop(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_change_transaction_tariff(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.tc_accepted()))]))
}

fn on_notify_web_payment_started(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_use_priority_charging(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.pc_accepted()))]))
}

fn on_update_dynamic_schedule(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.gen_accepted()))]))
}

# Available enum is missing — the GenericStatus we want here is
# 2.1's `gen_accepted`. It lives under the v21/enums module.

# ---- ChargePoint wiring ----------------------------------------

fn ge(en_value :: Str) -> Bool { not (en_value == "") }

fn central_system() -> cp.ChargePoint {
  cp.new_v21("csms-v21-example")
    # carry-overs
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.boot_notification(),
           sch.validate_boot_notification_req, on_boot)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.heartbeat(),
           sch.validate_heartbeat_req, on_heartbeat)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.authorize(),
           sch.validate_authorize_req, on_authorize)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.status_notification(),
           sch.validate_status_notification_req, on_status_notification)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.transaction_event(),
           sch.validate_transaction_event_req, on_transaction_event)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.data_transfer(),
           sch.validate_data_transfer_req, on_data_transfer)
       }
    # 2.1 additions
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.battery_swap(),
           sch.validate_battery_swap_req, on_battery_swap)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.notify_allowed_energy_transfer(),
           sch.validate_notify_allowed_energy_transfer_req,
           on_notify_allowed_energy_transfer)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.notify_periodic_event_stream(),
           sch.validate_notify_periodic_event_stream_req,
           on_notify_periodic_event_stream)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.open_periodic_event_stream(),
           sch.validate_open_periodic_event_stream_req,
           on_open_periodic_event_stream)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.close_periodic_event_stream(),
           sch.validate_close_periodic_event_stream_req,
           on_close_periodic_event_stream)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.get_der_control(),
           sch.validate_get_der_control_req, on_get_der_control)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.set_der_control(),
           sch.validate_set_der_control_req, on_set_der_control)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.clear_der_control(),
           sch.validate_clear_der_control_req, on_clear_der_control)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.notify_der_alarm(),
           sch.validate_notify_der_alarm_req, on_notify_der_alarm)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.notify_der_start_stop(),
           sch.validate_notify_der_start_stop_req, on_notify_der_start_stop)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.change_transaction_tariff(),
           sch.validate_change_transaction_tariff_req,
           on_change_transaction_tariff)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.notify_web_payment_started(),
           sch.validate_notify_web_payment_started_req,
           on_notify_web_payment_started)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.use_priority_charging(),
           sch.validate_use_priority_charging_req,
           on_use_priority_charging)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.update_dynamic_schedule(),
           sch.validate_update_dynamic_schedule_req,
           on_update_dynamic_schedule)
       }
}

# ---- WebSocket adapter ----------------------------------------

fn on_message(_conn :: WsConn, m :: WsMessage) -> WsAction {
  match m {
    WsText(raw) => match cp.handle_raw(central_system(), raw) {
      Ok(out) => WsSend(out),
      Err(fe) => WsSend(msg.encode(msg.new_call_error(
                   "", fe.code, fe.message, JObj([])))),
    },
    WsClose => WsNoOp,
    _       => WsNoOp,
  }
}

# ---- Entry point ----------------------------------------------

fn main() -> [net, io, time] Nil {
  let _ := io.print("CSMS v2.1  ws://localhost:9002/ocpp/<charger-id>")
  let _ := io.print("subprotocol: ocpp2.1   (bidirectional / DER / periodic-stream-aware)")
  net.serve_ws_fn(9002, cp.version_v21(), on_message)
}
