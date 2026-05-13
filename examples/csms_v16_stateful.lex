# lex-ocpp example — stateful v1.6 CSMS (in-process, no transport)
#
# Demonstrates `route_io.dispatch` / `charge_point_io` — the
# effectful dispatch path. Handlers can use `[io, time, sql]`:
#
#   - `io.print(...)` for inbound-frame logging
#   - timestamps from the response builder (canned here; a real CSMS
#     would call `time.now_iso()` once that builtin lands)
#   - `[sql]` persistence via lex-orm's `q.run_*` family (left as an
#     extension exercise — drops in via the same pattern as
#     lex-web/examples/with_lex_orm.lex)
#
# The example processes a hardcoded sequence of inbound frames in
# memory and prints the response for each, simulating what a real
# CSMS would see over a WebSocket without needing a network.
#
# Run:
#   lex run --allow-effects io,sql,time examples/csms_v16_stateful.lex main

import "std.io"   as io
import "std.int"  as int
import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages"         as msg
import "../src/error"            as oe
import "../src/route"            as route
import "../src/route_io"         as rio
import "../src/charge_point_io"  as cp_io
import "../src/v16/action"       as a
import "../src/v16/enums"        as en
import "../src/v16/schemas"      as sch

# ---- Effectful handlers -----------------------------------------
#
# Each handler logs the inbound frame via `io.print` before
# constructing its response. A real CSMS would also `q.run_insert`
# (lex-orm) to persist transactions / meter values; we leave that
# as an extension since it needs an open SQLite handle.

fn on_boot(payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let _ := io.print(str.concat("  ← BootNotification ",
                                jv.stringify(payload)))
  HOk(JObj([
    ("currentTime", JStr("2026-05-13T12:00:00Z")),
    ("interval",    JInt(300)),
    ("status",      JStr(en.reg_accepted())),
  ]))
}

fn on_heartbeat(_payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let _ := io.print("  ← Heartbeat")
  HOk(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn on_status_notification(payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let status_str := match jv.get_field(payload, "status") {
    Some(JStr(s)) => s,
    _             => "?",
  }
  let _ := io.print(str.concat("  ← StatusNotification status=", status_str))
  HOk(JObj([]))
}

fn on_authorize(payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let id_tag := match jv.get_field(payload, "idTag") {
    Some(JStr(s)) => s,
    _             => "",
  }
  let _ := io.print(str.concat("  ← Authorize idTag=", id_tag))
  HOk(JObj([
    ("idTagInfo", JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_start_transaction(payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let _ := io.print(str.concat("  ← StartTransaction ", jv.stringify(payload)))
  # A real CSMS allocates `transactionId` from the DB. Stub with 42.
  HOk(JObj([
    ("transactionId", JInt(42)),
    ("idTagInfo",     JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_stop_transaction(payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let _ := io.print(str.concat("  ← StopTransaction ", jv.stringify(payload)))
  HOk(JObj([
    ("idTagInfo", JObj([("status", JStr(en.auth_accepted()))])),
  ]))
}

fn on_meter_values(_payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  let _ := io.print("  ← MeterValues")
  HOk(JObj([]))
}

# ---- Registry wiring --------------------------------------------

fn central_system() -> cp_io.IOChargePoint {
  cp_io.new_v16("stateful-csms")
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.boot_notification(),
           sch.validate_boot_notification_req, on_boot)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.heartbeat(),
           sch.validate_heartbeat_req, on_heartbeat)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.status_notification(),
           sch.validate_status_notification_req, on_status_notification)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.authorize(),
           sch.validate_authorize_req, on_authorize)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.start_transaction(),
           sch.validate_start_transaction_req, on_start_transaction)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.stop_transaction(),
           sch.validate_stop_transaction_req, on_stop_transaction)
       }
    |> fn (c :: cp_io.IOChargePoint) -> cp_io.IOChargePoint {
         cp_io.handler_with_schema(c, a.meter_values(),
           sch.validate_meter_values_req, on_meter_values)
       }
}

# ---- Scripted inbound sequence ----------------------------------
#
# A canonical charging session, replayed against the stateful
# dispatcher. Drop your real wire frames here (or pipe them in
# from a WS subscriber) to drive integration tests.

fn scripted_frames() -> List[Str] {
  [
    msg.encode(msg.new_call("m1", "BootNotification",
      JObj([
        ("chargePointVendor", JStr("ACME")),
        ("chargePointModel",  JStr("Model-X")),
      ]))),
    msg.encode(msg.new_call("m2", "StatusNotification",
      JObj([
        ("connectorId", JInt(1)),
        ("errorCode",   JStr(en.ec_no_error())),
        ("status",      JStr(en.cp_available())),
      ]))),
    msg.encode(msg.new_call("m3", "Authorize",
      JObj([("idTag", JStr("USER-001"))]))),
    msg.encode(msg.new_call("m4", "StartTransaction",
      JObj([
        ("connectorId", JInt(1)),
        ("idTag",       JStr("USER-001")),
        ("meterStart",  JInt(0)),
        ("timestamp",   JStr("2026-05-13T12:00:00Z")),
      ]))),
    msg.encode(msg.new_call("m5", "Heartbeat", JObj([]))),
    msg.encode(msg.new_call("m6", "StopTransaction",
      JObj([
        ("transactionId", JInt(42)),
        ("meterStop",     JInt(15000)),
        ("timestamp",     JStr("2026-05-13T13:00:00Z")),
        ("reason",        JStr(en.reason_local())),
      ]))),
  ]
}

# ---- Entry point -------------------------------------------------

fn main() -> [io, time, sql] Nil {
  let _ := io.print("=== Stateful OCPP 1.6 CSMS — in-process simulation ===")
  let csms := central_system()
  let _ := list.fold(scripted_frames(), 0,
    fn (i :: Int, raw :: Str) -> [io, time, sql] Int {
      let _ := io.print(str.concat("frame[", str.concat(int.to_str(i), "]")))
      match cp_io.handle_raw(csms, raw) {
        Err(fe) => {
          let _ := io.print(str.concat("  → ProtocolError: ", fe.message))
          i + 1
        },
        Ok(out) => {
          let _ := io.print(str.concat("  → ", out))
          i + 1
        },
      }
    })
  ()
}
