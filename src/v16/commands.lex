# lex-ocpp — OCPP 1.6 CS→CP typed command representations
#
# Typed request and response records for every CS→CP command.
# Two halves:
#   - Request types: structured alternatives to raw JSON, built by
#     the CSMS and serialised via frames.lex.
#   - Response types: parsed from the CallResult payload the CP
#     sends back. Use the `parse_*_conf` helpers below.
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

import "./datatypes" as dt

import "./enums" as en

# ---- CancelReservation ------------------------------------------
type CancelReservationConf = { status :: Str }

fn parse_cancel_reservation_conf(j :: jv.Json) -> CancelReservationConf {
  { status: str_field(j, "status", en.cancel_rejected()) }
}

# ---- ChangeAvailability -----------------------------------------
type ChangeAvailabilityConf = { status :: Str }

fn parse_change_availability_conf(j :: jv.Json) -> ChangeAvailabilityConf {
  { status: str_field(j, "status", en.avail_status_rejected()) }
}

# ---- ChangeConfiguration ----------------------------------------
type ChangeConfigurationConf = { status :: Str }

fn parse_change_configuration_conf(j :: jv.Json) -> ChangeConfigurationConf {
  { status: str_field(j, "status", en.cfg_rejected()) }
}

# ---- ClearCache -------------------------------------------------
type ClearCacheConf = { status :: Str }

fn parse_clear_cache_conf(j :: jv.Json) -> ClearCacheConf {
  { status: str_field(j, "status", en.accepted()) }
}

# ---- ClearChargingProfile ---------------------------------------
type ClearChargingProfileConf = { status :: Str }

fn parse_clear_charging_profile_conf(j :: jv.Json) -> ClearChargingProfileConf {
  { status: str_field(j, "status", en.ccp_unknown()) }
}

# ---- GetCompositeSchedule ---------------------------------------
type GetCompositeScheduleConf = { status :: Str, connector_id :: Option[Int], schedule_start :: Option[Str], charging_schedule :: Option[jv.Json] }

fn parse_get_composite_schedule_conf(j :: jv.Json) -> GetCompositeScheduleConf {
  { status: str_field(j, "status", en.accepted()), connector_id: opt_int_field(j, "connectorId"), schedule_start: opt_str_field(j, "scheduleStart"), charging_schedule: jv.get_field(j, "chargingSchedule") }
}

# ---- GetConfiguration -------------------------------------------
type KeyValue = { key :: Str, readonly :: Bool, value :: Option[Str] }

type GetConfigurationConf = { configuration_key :: List[KeyValue], unknown_key :: List[Str] }

fn parse_key_value(j :: jv.Json) -> KeyValue {
  { key: str_field(j, "key", ""), readonly: bool_field(j, "readonly", false), value: opt_str_field(j, "value") }
}

fn parse_get_configuration_conf(j :: jv.Json) -> GetConfigurationConf {
  let cfg_keys := match jv.get_field(j, "configurationKey") {
    Some(JList(items)) => list.fold(items, [], fn (acc :: List[KeyValue], item :: jv.Json) -> List[KeyValue] {
      list.concat(acc, [parse_key_value(item)])
    }),
    _ => [],
  }
  let unk_keys := match jv.get_field(j, "unknownKey") {
    Some(JList(items)) => list.fold(items, [], fn (acc :: List[Str], item :: jv.Json) -> List[Str] {
      match item {
        JStr(s) => list.concat(acc, [s]),
        _ => acc,
      }
    }),
    _ => [],
  }
  { configuration_key: cfg_keys, unknown_key: unk_keys }
}

# ---- GetDiagnostics ---------------------------------------------
type GetDiagnosticsConf = { file_name :: Option[Str] }

fn parse_get_diagnostics_conf(j :: jv.Json) -> GetDiagnosticsConf {
  { file_name: opt_str_field(j, "fileName") }
}

# ---- GetLocalListVersion ----------------------------------------
type GetLocalListVersionConf = { list_version :: Int }

fn parse_get_local_list_version_conf(j :: jv.Json) -> GetLocalListVersionConf {
  { list_version: int_field(j, "listVersion", 0) }
}

# ---- RemoteStartTransaction -------------------------------------
type RemoteStartTransactionConf = { status :: Str }

fn parse_remote_start_transaction_conf(j :: jv.Json) -> RemoteStartTransactionConf {
  { status: str_field(j, "status", en.rejected()) }
}

# ---- RemoteStopTransaction --------------------------------------
type RemoteStopTransactionConf = { status :: Str }

fn parse_remote_stop_transaction_conf(j :: jv.Json) -> RemoteStopTransactionConf {
  { status: str_field(j, "status", en.rejected()) }
}

# ---- ReserveNow -------------------------------------------------
type ReserveNowConf = { status :: Str }

fn parse_reserve_now_conf(j :: jv.Json) -> ReserveNowConf {
  { status: str_field(j, "status", en.rsv_rejected()) }
}

# ---- Reset ------------------------------------------------------
type ResetConf = { status :: Str }

fn parse_reset_conf(j :: jv.Json) -> ResetConf {
  { status: str_field(j, "status", en.rejected()) }
}

# ---- SendLocalList ----------------------------------------------
type SendLocalListConf = { status :: Str }

fn parse_send_local_list_conf(j :: jv.Json) -> SendLocalListConf {
  { status: str_field(j, "status", en.upd_failed()) }
}

# ---- SetChargingProfile -----------------------------------------
type SetChargingProfileConf = { status :: Str }

fn parse_set_charging_profile_conf(j :: jv.Json) -> SetChargingProfileConf {
  { status: str_field(j, "status", en.cps_rejected()) }
}

# ---- TriggerMessage ---------------------------------------------
type TriggerMessageConf = { status :: Str }

fn parse_trigger_message_conf(j :: jv.Json) -> TriggerMessageConf {
  { status: str_field(j, "status", en.trg_not_implemented()) }
}

# ---- UnlockConnector --------------------------------------------
type UnlockConnectorConf = { status :: Str }

fn parse_unlock_connector_conf(j :: jv.Json) -> UnlockConnectorConf {
  { status: str_field(j, "status", en.unlock_unlock_failed()) }
}

# ---- UpdateFirmware ---------------------------------------------
type UpdateFirmwareConf = {  }

fn parse_update_firmware_conf(_j :: jv.Json) -> UpdateFirmwareConf {
  {  }
}

# ---- DataTransfer -----------------------------------------------
type DataTransferConf = { status :: Str, data :: Option[Str] }

fn parse_data_transfer_conf(j :: jv.Json) -> DataTransferConf {
  { status: str_field(j, "status", en.dt_accepted()), data: opt_str_field(j, "data") }
}

# ---- Field extraction helpers -----------------------------------
fn str_field(j :: jv.Json, key :: Str, default :: Str) -> Str {
  match jv.get_field(j, key) {
    Some(JStr(s)) => s,
    _ => default,
  }
}

fn int_field(j :: jv.Json, key :: Str, default :: Int) -> Int {
  match jv.get_field(j, key) {
    Some(JInt(n)) => n,
    _ => default,
  }
}

fn bool_field(j :: jv.Json, key :: Str, default :: Bool) -> Bool {
  match jv.get_field(j, key) {
    Some(JBool(b)) => b,
    _ => default,
  }
}

fn opt_str_field(j :: jv.Json, key :: Str) -> Option[Str] {
  match jv.get_field(j, key) {
    Some(JStr(s)) => Some(s),
    _ => None,
  }
}

fn opt_int_field(j :: jv.Json, key :: Str) -> Option[Int] {
  match jv.get_field(j, key) {
    Some(JInt(n)) => Some(n),
    _ => None,
  }
}

