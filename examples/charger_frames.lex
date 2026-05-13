# lex-ocpp example — charger-side frame construction (no transport)
#
# lex-lang ships a WebSocket *server* (`net.serve_ws_fn`) but not yet
# a client, so this example focuses on the charger half of the
# protocol that doesn't need network access: building the frames a
# charge point would send to a CSMS.
#
# Pipe the printed frames into a `wscat` session against the CSMS in
# examples/csms_v16.lex to drive a real session.
#
# Run:
#   lex run --allow-effects io examples/charger_frames.lex main

import "std.io"   as io
import "std.str"  as str
import "std.int"  as int
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages"      as msg
import "../src/v16/enums"     as en
import "../src/v16/datatypes" as dt

# ---- Frame builders ---------------------------------------------
#
# Each helper returns the wire string ready for `ws.send`. The
# message-id sequence is the caller's responsibility (UUIDs in a
# real system; monotonic integers here for legibility).

fn boot_notification(message_id :: Str, vendor :: Str, model :: Str) -> Str {
  msg.encode(msg.new_call(message_id, "BootNotification",
    JObj([
      ("chargePointVendor", JStr(vendor)),
      ("chargePointModel",  JStr(model)),
    ])))
}

fn heartbeat(message_id :: Str) -> Str {
  msg.encode(msg.new_call(message_id, "Heartbeat", JObj([])))
}

fn status_notification(
  message_id  :: Str,
  connector_id :: Int,
  status       :: Str
) -> Str {
  msg.encode(msg.new_call(message_id, "StatusNotification",
    JObj([
      ("connectorId", JInt(connector_id)),
      ("errorCode",   JStr(en.ec_no_error())),
      ("status",      JStr(status)),
    ])))
}

fn authorize(message_id :: Str, id_tag :: Str) -> Str {
  msg.encode(msg.new_call(message_id, "Authorize",
    JObj([("idTag", JStr(id_tag))])))
}

fn start_transaction(
  message_id   :: Str,
  connector_id :: Int,
  id_tag       :: Str,
  meter_start  :: Int,
  timestamp    :: Str
) -> Str {
  msg.encode(msg.new_call(message_id, "StartTransaction",
    JObj([
      ("connectorId", JInt(connector_id)),
      ("idTag",       JStr(id_tag)),
      ("meterStart",  JInt(meter_start)),
      ("timestamp",   JStr(timestamp)),
    ])))
}

fn meter_values(
  message_id   :: Str,
  connector_id :: Int,
  timestamp    :: Str,
  energy_wh    :: Int
) -> Str {
  let sv := dt.sampled_value(int.to_str(energy_wh))
  let sv2 := { value: sv.value, context: Some(en.rc_sample_periodic()),
               format: None,
               measurand: Some(en.ms_energy_active_import_register()),
               phase: None, location: None, unit: Some(en.uom_wh()) }
  let mv := dt.meter_value(timestamp, [sv2])
  msg.encode(msg.new_call(message_id, "MeterValues",
    JObj([
      ("connectorId", JInt(connector_id)),
      ("meterValue",  JList([dt.meter_value_to_json(mv)])),
    ])))
}

fn stop_transaction(
  message_id      :: Str,
  transaction_id  :: Int,
  meter_stop      :: Int,
  timestamp       :: Str,
  reason          :: Str
) -> Str {
  msg.encode(msg.new_call(message_id, "StopTransaction",
    JObj([
      ("transactionId", JInt(transaction_id)),
      ("meterStop",     JInt(meter_stop)),
      ("timestamp",     JStr(timestamp)),
      ("reason",        JStr(reason)),
    ])))
}

# ---- Scripted session --------------------------------------------
#
# A canonical charging-session frame sequence. Print each line; you
# can copy them into wscat against the CSMS to exercise it end-to-end.

fn main() -> [io] Nil {
  let _ := io.print("=== OCPP 1.6 charger frame sequence ===")
  let _ := io.print(boot_notification("m1", "ACME", "Model-X"))
  let _ := io.print(status_notification("m2", 1, en.cp_available()))
  let _ := io.print(authorize("m3", "USER-001"))
  let _ := io.print(start_transaction("m4", 1, "USER-001", 0,
                                       "2026-05-13T12:00:00Z"))
  let _ := io.print(meter_values("m5", 1, "2026-05-13T12:30:00Z", 7500))
  let _ := io.print(stop_transaction("m6", 42, 15000,
                                      "2026-05-13T13:00:00Z",
                                      en.reason_local()))
  let _ := io.print(heartbeat("m7"))
  ()
}
