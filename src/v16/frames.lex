# lex-ocpp — OCPP 1.6 CS→CP outbound frame builders
#
# Pure functions that build the wire Str for every CS→CP command.
# The CSMS-side counterpart to examples/charger_frames.lex.
#
# Usage:
#   let frame := frames.reset("msg-42", en.reset_hard())
#   ws.send(conn, frame)                  # once outbound WS send lands
#   # or: WsSend(frame) from an on_message handler
#
# All functions are pure — no effects needed.

import "std.list" as list

import "lex-schema/json_value" as jv

import "../messages" as msg
import "./action"    as a
import "./datatypes" as dt

# ---- CancelReservation ------------------------------------------

fn cancel_reservation(message_id :: Str, reservation_id :: Int) -> Str {
  msg.encode(msg.new_call(message_id, a.cancel_reservation(),
    JObj([("reservationId", JInt(reservation_id))])))
}

# ---- ChangeAvailability -----------------------------------------

fn change_availability(
  message_id   :: Str,
  connector_id :: Int,
  avail_type   :: Str
) -> Str {
  msg.encode(msg.new_call(message_id, a.change_availability(),
    JObj([
      ("connectorId", JInt(connector_id)),
      ("type",        JStr(avail_type)),
    ])))
}

# ---- ChangeConfiguration ----------------------------------------

fn change_configuration(
  message_id :: Str,
  key        :: Str,
  value      :: Str
) -> Str {
  msg.encode(msg.new_call(message_id, a.change_configuration(),
    JObj([
      ("key",   JStr(key)),
      ("value", JStr(value)),
    ])))
}

# ---- ClearCache -------------------------------------------------

fn clear_cache(message_id :: Str) -> Str {
  msg.encode(msg.new_call(message_id, a.clear_cache(), JObj([])))
}

# ---- ClearChargingProfile ---------------------------------------
#
# All four filter fields are optional — send an empty payload to
# clear every profile on the charge point.

fn clear_charging_profile(
  message_id   :: Str,
  id           :: Option[Int],
  connector_id :: Option[Int],
  purpose      :: Option[Str],
  stack_level  :: Option[Int]
) -> Str {
  let e0 := []
  let e1 := match id {
    None    => e0,
    Some(n) => list.concat(e0, [("id", JInt(n))]),
  }
  let e2 := match connector_id {
    None    => e1,
    Some(n) => list.concat(e1, [("connectorId", JInt(n))]),
  }
  let e3 := match purpose {
    None    => e2,
    Some(s) => list.concat(e2, [("chargingProfilePurpose", JStr(s))]),
  }
  let e4 := match stack_level {
    None    => e3,
    Some(n) => list.concat(e3, [("stackLevel", JInt(n))]),
  }
  msg.encode(msg.new_call(message_id, a.clear_charging_profile(), JObj(e4)))
}

# ---- GetCompositeSchedule ---------------------------------------

fn get_composite_schedule(
  message_id         :: Str,
  connector_id       :: Int,
  duration           :: Int,
  charging_rate_unit :: Option[Str]
) -> Str {
  let base := [
    ("connectorId", JInt(connector_id)),
    ("duration",    JInt(duration)),
  ]
  let fields := match charging_rate_unit {
    None    => base,
    Some(u) => list.concat(base, [("chargingRateUnit", JStr(u))]),
  }
  msg.encode(msg.new_call(message_id, a.get_composite_schedule(), JObj(fields)))
}

# ---- GetConfiguration -------------------------------------------
#
# Empty `keys` list omits the field (request all config keys).

fn get_configuration(message_id :: Str, keys :: List[Str]) -> Str {
  let payload := if list.is_empty(keys) {
    JObj([])
  } else {
    JObj([("key", JList(list.map(keys, fn (k :: Str) -> jv.Json { JStr(k) })))])
  }
  msg.encode(msg.new_call(message_id, a.get_configuration(), payload))
}

# ---- GetDiagnostics ---------------------------------------------

fn get_diagnostics(
  message_id     :: Str,
  location       :: Str,
  retries        :: Option[Int],
  retry_interval :: Option[Int],
  start_time     :: Option[Str],
  stop_time      :: Option[Str]
) -> Str {
  let e0 := [("location", JStr(location))]
  let e1 := match retries {
    None    => e0,
    Some(n) => list.concat(e0, [("retries", JInt(n))]),
  }
  let e2 := match retry_interval {
    None    => e1,
    Some(n) => list.concat(e1, [("retryInterval", JInt(n))]),
  }
  let e3 := match start_time {
    None    => e2,
    Some(s) => list.concat(e2, [("startTime", JStr(s))]),
  }
  let e4 := match stop_time {
    None    => e3,
    Some(s) => list.concat(e3, [("stopTime", JStr(s))]),
  }
  msg.encode(msg.new_call(message_id, a.get_diagnostics(), JObj(e4)))
}

# ---- GetLocalListVersion ----------------------------------------

fn get_local_list_version(message_id :: Str) -> Str {
  msg.encode(msg.new_call(message_id, a.get_local_list_version(), JObj([])))
}

# ---- RemoteStartTransaction -------------------------------------

fn remote_start_transaction(
  message_id   :: Str,
  id_tag       :: Str,
  connector_id :: Option[Int]
) -> Str {
  let base := [("idTag", JStr(id_tag))]
  let fields := match connector_id {
    None    => base,
    Some(n) => list.concat([("connectorId", JInt(n))], base),
  }
  msg.encode(msg.new_call(message_id, a.remote_start_transaction(), JObj(fields)))
}

# ---- RemoteStopTransaction --------------------------------------

fn remote_stop_transaction(message_id :: Str, transaction_id :: Int) -> Str {
  msg.encode(msg.new_call(message_id, a.remote_stop_transaction(),
    JObj([("transactionId", JInt(transaction_id))])))
}

# ---- ReserveNow -------------------------------------------------

fn reserve_now(
  message_id     :: Str,
  connector_id   :: Int,
  expiry_date    :: Str,
  id_tag         :: Str,
  reservation_id :: Int
) -> Str {
  msg.encode(msg.new_call(message_id, a.reserve_now(),
    JObj([
      ("connectorId",   JInt(connector_id)),
      ("expiryDate",    JStr(expiry_date)),
      ("idTag",         JStr(id_tag)),
      ("reservationId", JInt(reservation_id)),
    ])))
}

# ---- Reset ------------------------------------------------------

fn reset(message_id :: Str, reset_type :: Str) -> Str {
  msg.encode(msg.new_call(message_id, a.reset(),
    JObj([("type", JStr(reset_type))])))
}

# ---- SendLocalList ----------------------------------------------
#
# Empty list omits localAuthorizationList — valid for Full updates
# that clear the local list.

fn send_local_list(
  message_id      :: Str,
  list_version    :: Int,
  update_type     :: Str,
  local_auth_list :: List[dt.AuthorizationData]
) -> Str {
  let base := [
    ("listVersion", JInt(list_version)),
    ("updateType",  JStr(update_type)),
  ]
  let fields := if list.is_empty(local_auth_list) {
    base
  } else {
    list.concat(base, [("localAuthorizationList",
      JList(list.map(local_auth_list,
        fn (a :: dt.AuthorizationData) -> jv.Json {
          dt.authorization_data_to_json(a)
        })))])
  }
  msg.encode(msg.new_call(message_id, a.send_local_list(), JObj(fields)))
}

# ---- SetChargingProfile -----------------------------------------

fn set_charging_profile(
  message_id       :: Str,
  connector_id     :: Int,
  charging_profile :: dt.ChargingProfile
) -> Str {
  msg.encode(msg.new_call(message_id, a.set_charging_profile(),
    JObj([
      ("connectorId",        JInt(connector_id)),
      ("csChargingProfiles", dt.charging_profile_to_json(charging_profile)),
    ])))
}

# ---- TriggerMessage ---------------------------------------------

fn trigger_message(
  message_id        :: Str,
  requested_message :: Str,
  connector_id      :: Option[Int]
) -> Str {
  let base := [("requestedMessage", JStr(requested_message))]
  let fields := match connector_id {
    None    => base,
    Some(n) => list.concat(base, [("connectorId", JInt(n))]),
  }
  msg.encode(msg.new_call(message_id, a.trigger_message(), JObj(fields)))
}

# ---- UnlockConnector --------------------------------------------

fn unlock_connector(message_id :: Str, connector_id :: Int) -> Str {
  msg.encode(msg.new_call(message_id, a.unlock_connector(),
    JObj([("connectorId", JInt(connector_id))])))
}

# ---- UpdateFirmware ---------------------------------------------

fn update_firmware(
  message_id     :: Str,
  location       :: Str,
  retrieve_date  :: Str,
  retries        :: Option[Int],
  retry_interval :: Option[Int]
) -> Str {
  let e0 := [
    ("location",     JStr(location)),
    ("retrieveDate", JStr(retrieve_date)),
  ]
  let e1 := match retries {
    None    => e0,
    Some(n) => list.concat(e0, [("retries", JInt(n))]),
  }
  let e2 := match retry_interval {
    None    => e1,
    Some(n) => list.concat(e1, [("retryInterval", JInt(n))]),
  }
  msg.encode(msg.new_call(message_id, a.update_firmware(), JObj(e2)))
}

# ---- DataTransfer (bidirectional) --------------------------------

fn data_transfer(
  message_id     :: Str,
  vendor_id      :: Str,
  message_id_str :: Option[Str],
  data           :: Option[Str]
) -> Str {
  let e0 := [("vendorId", JStr(vendor_id))]
  let e1 := match message_id_str {
    None    => e0,
    Some(s) => list.concat(e0, [("messageId", JStr(s))]),
  }
  let e2 := match data {
    None    => e1,
    Some(s) => list.concat(e1, [("data", JStr(s))]),
  }
  msg.encode(msg.new_call(message_id, a.data_transfer(), JObj(e2)))
}
