# lex-ocpp example — minimal v1.6 CSMS over WebSocket
#
# A self-contained Central System that:
#   1. Accepts WebSocket connections at ws://localhost:9000/ocpp/<id>
#      using the OCPP 1.6J subprotocol ("ocpp1.6").
#   2. Decodes inbound Call frames via lex-ocpp's framing layer.
#   3. Validates payloads against the per-action lex-schema
#      validators in src/v16/schemas.lex.
#   4. Hands off to a registered Lex handler (one per action).
#   5. Encodes the response (CallResult or CallError) back onto
#      the same WebSocket.
#
# Routing is wired up at the `central_system()` constructor —
# add or remove `handler(...)` calls there to extend the surface.
#
# Run:
#   lex run --allow-effects net,io,time examples/csms_v16.lex main
#
# Then point any OCPP 1.6 charger (mobilityhouse/ocpp's
# `examples/v16/charge_point.py` works) at:
#   ws://localhost:9000/ocpp/<charger-id>
#
# Adversarial scenario:
#   - A charger that sends `[2, "id", "MysteryAction", {}]` gets a
#     `CallError` with code `NotImplemented`. The framework refuses
#     to invoke any handler; the typecheck would catch missing
#     handlers at edit time if you used the constants from action.lex.
#   - A charger that sends `{"chargePointVendor": ""}` to
#     BootNotification gets a `PropertyConstraintViolation` with
#     details listing every failing constraint — never reaches the
#     handler.

import "std.io"   as io
import "std.net"  as net
import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/error"         as oe
import "../src/route"         as route
import "../src/charge_point"  as cp
import "../src/v16/action"    as a
import "../src/v16/enums"     as en
import "../src/v16/schemas"   as sch

# ---- Handler bodies (pure, per OCPP-1.6 §4) ----------------------
#
# Every handler takes the validated payload and returns a response
# payload (or an OcppError). The example uses canned timestamps and
# stub semantics — wire your own state machine in here.

fn on_boot_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("currentTime", JStr("2026-05-13T12:00:00Z")),
    ("interval",    JInt(300)),
    ("status",      JStr(en.reg_accepted())),
  ]))
}

fn on_heartbeat(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn on_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_authorize(payload :: jv.Json) -> route.HandlerResult {
  # Echo the inbound id_tag back as an Accepted IdTagInfo. A real CSMS
  # would consult a database / whitelist here.
  match jv.j_str("", payload, "idTag", []) {
    Err(_)    => route.fail(oe.err(oe.property_constraint_violation(),
                                   "missing idTag")),
    Ok(_)     => route.ok(JObj([
      ("idTagInfo", JObj([("status", JStr(en.auth_accepted()))])),
    ])),
  }
}

fn on_meter_values(_payload :: jv.Json) -> route.HandlerResult {
  # Spec: MeterValues.conf is empty. We accept everything and store
  # nothing — a real CSMS would persist via lex-orm.
  route.ok(JObj([]))
}

fn on_start_transaction(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("transactionId", JInt(42)),
    ("idTagInfo",     JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_stop_transaction(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("idTagInfo", JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_data_transfer(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("status", JStr(en.dt_accepted()))]))
}

fn on_firmware_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

fn on_diagnostics_status_notification(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([]))
}

# ---- Registry wiring --------------------------------------------

fn central_system() -> cp.ChargePoint {
  cp.new_v16("csms-example")
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.boot_notification(),
           sch.validate_boot_notification_req, on_boot_notification)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.heartbeat(),
           sch.validate_heartbeat_req, on_heartbeat)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.status_notification(),
           sch.validate_status_notification_req, on_status_notification)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.authorize(),
           sch.validate_authorize_req, on_authorize)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.meter_values(),
           sch.validate_meter_values_req, on_meter_values)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.start_transaction(),
           sch.validate_start_transaction_req, on_start_transaction)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.stop_transaction(),
           sch.validate_stop_transaction_req, on_stop_transaction)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.data_transfer(),
           sch.validate_data_transfer_req, on_data_transfer)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.firmware_status_notification(),
           sch.validate_firmware_status_notification_req,
           on_firmware_status_notification)
       }
    |> fn (c :: cp.ChargePoint) -> cp.ChargePoint {
         cp.handler_with_schema(c, a.diagnostics_status_notification(),
           sch.validate_diagnostics_status_notification_req,
           on_diagnostics_status_notification)
       }
}

# ---- WebSocket adapter -------------------------------------------
#
# The handler is pure — no [io], no [time]. Effects belong to
# `main()` where we can log them. On a parse failure we synthesise
# a CallError frame using the canonical OCPP `ProtocolError` code;
# if even that fails (e.g., the input has no message_id), we drop
# the frame by returning WsNoOp.

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

# ---- Entry point -------------------------------------------------

fn main() -> [net, io, time] Nil {
  let _ := io.print("CSMS v1.6  ws://localhost:9000/ocpp/<charger-id>")
  let _ := io.print(describe_routes())
  net.serve_ws_fn(9000, cp.version_v16(), on_message)
}

fn describe_routes() -> Str {
  str.concat("registered actions: ",
    list.fold(cp.actions(central_system()), "",
      fn (acc :: Str, action :: Str) -> Str {
        if acc == "" { action } else { str.concat(acc, str.concat(", ", action)) }
      }))
}
