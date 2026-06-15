# lex-ocpp — OCPP 1.6 payload validators
#
# One `ModelSchema` + companion `validate_<action>` validator per
# OCPP 1.6J Action. Registering with `route.handler_with_schema`
# rejects malformed payloads at the framework boundary before the
# handler runs, and surfaces every failing field at once (lex-schema
# accumulates errors).
#
# Schemas follow the OCPP 1.6 spec exactly (Errata 2019-12-13):
# field names match the wire JSON, required/optional flags match
# the spec's req/.conf tables, and enum fields use `StrOneOf` over
# the matching `enums.all_*()` catalog.
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/schema" as s

import "lex-schema/error" as e

import "lex-schema/constraints" as c

import "./enums" as en

# ============================================================
# CP → CS request schemas
# ============================================================
# ---- Authorize.req ----------------------------------------------
fn authorize_req_schema() -> s.ModelSchema {
  { title: "AuthorizeRequest", description: "OCPP 1.6 — Authorize.req", fields: [s.required_str("idTag", [StrNonEmpty, StrMaxLen(20)])] }
}

fn validate_authorize_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(authorize_req_schema(), j)
}

# ---- BootNotification.req ---------------------------------------
fn boot_notification_req_schema() -> s.ModelSchema {
  { title: "BootNotificationRequest", description: "OCPP 1.6 — BootNotification.req", fields: [s.required_str("chargePointVendor", [StrNonEmpty, StrMaxLen(20)]), s.required_str("chargePointModel", [StrNonEmpty, StrMaxLen(20)]), s.optional(s.required_str("chargePointSerialNumber", [StrMaxLen(25)])), s.optional(s.required_str("chargeBoxSerialNumber", [StrMaxLen(25)])), s.optional(s.required_str("firmwareVersion", [StrMaxLen(50)])), s.optional(s.required_str("iccid", [StrMaxLen(20)])), s.optional(s.required_str("imsi", [StrMaxLen(20)])), s.optional(s.required_str("meterType", [StrMaxLen(25)])), s.optional(s.required_str("meterSerialNumber", [StrMaxLen(25)]))] }
}

fn validate_boot_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(boot_notification_req_schema(), j)
}

# ---- Heartbeat.req ----------------------------------------------
fn heartbeat_req_schema() -> s.ModelSchema {
  { title: "HeartbeatRequest", description: "OCPP 1.6 — Heartbeat.req", fields: [] }
}

fn validate_heartbeat_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(heartbeat_req_schema(), j)
}

# ---- StatusNotification.req -------------------------------------
fn status_notification_req_schema() -> s.ModelSchema {
  { title: "StatusNotificationRequest", description: "OCPP 1.6 — StatusNotification.req", fields: [s.required_int("connectorId", [IntNonNegative]), s.required_str("errorCode", [StrOneOf(en.all_charge_point_error_code())]), s.required_str("status", [StrOneOf(en.all_charge_point_status())]), s.optional(s.required_str("info", [StrMaxLen(50)])), s.optional(s.required_str("timestamp", [StrNonEmpty])), s.optional(s.required_str("vendorId", [StrMaxLen(255)])), s.optional(s.required_str("vendorErrorCode", [StrMaxLen(50)]))] }
}

fn validate_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(status_notification_req_schema(), j)
}

# ---- StartTransaction.req ---------------------------------------
fn start_transaction_req_schema() -> s.ModelSchema {
  { title: "StartTransactionRequest", description: "OCPP 1.6 — StartTransaction.req", fields: [s.required_int("connectorId", [IntPositive]), s.required_str("idTag", [StrNonEmpty, StrMaxLen(20)]), s.required_int("meterStart", []), s.optional(s.required_int("reservationId", [])), s.required_str("timestamp", [StrNonEmpty])] }
}

fn validate_start_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(start_transaction_req_schema(), j)
}

# ---- StopTransaction.req ----------------------------------------
fn stop_transaction_req_schema() -> s.ModelSchema {
  { title: "StopTransactionRequest", description: "OCPP 1.6 — StopTransaction.req", fields: [s.optional(s.required_str("idTag", [StrMaxLen(20)])), s.required_int("meterStop", []), s.required_str("timestamp", [StrNonEmpty]), s.required_int("transactionId", []), s.optional(s.required_str("reason", [StrOneOf(en.all_stop_reason())]))] }
}

fn validate_stop_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(stop_transaction_req_schema(), j)
}

# ---- MeterValues.req --------------------------------------------
fn meter_values_req_schema() -> s.ModelSchema {
  { title: "MeterValuesRequest", description: "OCPP 1.6 — MeterValues.req", fields: [s.required_int("connectorId", [IntNonNegative]), s.optional(s.required_int("transactionId", [])), s.required_array("meterValue", KObject(meter_value_schema()), [ListNonEmpty])] }
}

fn meter_value_schema() -> s.ModelSchema {
  { title: "MeterValue", description: "", fields: [s.required_str("timestamp", [StrNonEmpty]), s.required_array("sampledValue", KObject(sampled_value_schema()), [ListNonEmpty])] }
}

fn sampled_value_schema() -> s.ModelSchema {
  { title: "SampledValue", description: "", fields: [s.required_str("value", [StrNonEmpty]), s.optional(s.required_str("context", [StrOneOf(en.all_reading_context())])), s.optional(s.required_str("format", [StrOneOf(en.all_value_format())])), s.optional(s.required_str("measurand", [StrOneOf(en.all_measurand())])), s.optional(s.required_str("phase", [StrOneOf(en.all_phase())])), s.optional(s.required_str("location", [StrOneOf(en.all_location())])), s.optional(s.required_str("unit", [StrOneOf(en.all_unit_of_measure())]))] }
}

fn validate_meter_values_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(meter_values_req_schema(), j)
}

# ---- DataTransfer.req -------------------------------------------
fn data_transfer_req_schema() -> s.ModelSchema {
  { title: "DataTransferRequest", description: "OCPP 1.6 — DataTransfer.req", fields: [s.required_str("vendorId", [StrNonEmpty, StrMaxLen(255)]), s.optional(s.required_str("messageId", [StrMaxLen(50)])), s.optional(s.required_str("data", []))] }
}

fn validate_data_transfer_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(data_transfer_req_schema(), j)
}

# ---- FirmwareStatusNotification.req -----------------------------
fn firmware_status_notification_req_schema() -> s.ModelSchema {
  { title: "FirmwareStatusNotificationRequest", description: "OCPP 1.6 — FirmwareStatusNotification.req", fields: [s.required_str("status", [StrOneOf(en.all_firmware_status())])] }
}

fn validate_firmware_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(firmware_status_notification_req_schema(), j)
}

# ---- DiagnosticsStatusNotification.req --------------------------
fn diagnostics_status_notification_req_schema() -> s.ModelSchema {
  { title: "DiagnosticsStatusNotificationRequest", description: "OCPP 1.6 — DiagnosticsStatusNotification.req", fields: [s.required_str("status", [StrOneOf(en.all_diagnostics_status())])] }
}

fn validate_diagnostics_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(diagnostics_status_notification_req_schema(), j)
}

# ============================================================
# CS → CP request schemas
# ============================================================
#
# When the *charger* registers handlers (because the CSMS is the
# initiator), these are the validators it needs. Spec coverage here
# is partial-by-design: the 8 most-commonly-implemented commands.
# Add more by writing a schema + validator pair that follows the
# pattern above.
# ---- Reset.req ---------------------------------------------------
fn reset_req_schema() -> s.ModelSchema {
  { title: "ResetRequest", description: "OCPP 1.6 — Reset.req", fields: [s.required_str("type", [StrOneOf(en.all_reset_type())])] }
}

fn validate_reset_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(reset_req_schema(), j)
}

# ---- ChangeAvailability.req -------------------------------------
fn change_availability_req_schema() -> s.ModelSchema {
  { title: "ChangeAvailabilityRequest", description: "OCPP 1.6 — ChangeAvailability.req", fields: [s.required_int("connectorId", [IntNonNegative]), s.required_str("type", [StrOneOf(en.all_availability_type())])] }
}

fn validate_change_availability_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(change_availability_req_schema(), j)
}

# ---- ChangeConfiguration.req ------------------------------------
fn change_configuration_req_schema() -> s.ModelSchema {
  { title: "ChangeConfigurationRequest", description: "OCPP 1.6 — ChangeConfiguration.req", fields: [s.required_str("key", [StrNonEmpty, StrMaxLen(50)]), s.required_str("value", [StrMaxLen(500)])] }
}

fn validate_change_configuration_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(change_configuration_req_schema(), j)
}

# ---- ClearCache.req ---------------------------------------------
fn clear_cache_req_schema() -> s.ModelSchema {
  { title: "ClearCacheRequest", description: "OCPP 1.6 — ClearCache.req", fields: [] }
}

fn validate_clear_cache_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(clear_cache_req_schema(), j)
}

# ---- GetConfiguration.req ---------------------------------------
fn get_configuration_req_schema() -> s.ModelSchema {
  { title: "GetConfigurationRequest", description: "OCPP 1.6 — GetConfiguration.req", fields: [s.optional(s.required_array("key", KStr([StrMaxLen(50)]), []))] }
}

fn validate_get_configuration_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(get_configuration_req_schema(), j)
}

# ---- RemoteStartTransaction.req ---------------------------------
fn remote_start_transaction_req_schema() -> s.ModelSchema {
  { title: "RemoteStartTransactionRequest", description: "OCPP 1.6 — RemoteStartTransaction.req", fields: [s.optional(s.required_int("connectorId", [IntPositive])), s.required_str("idTag", [StrNonEmpty, StrMaxLen(20)])] }
}

fn validate_remote_start_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(remote_start_transaction_req_schema(), j)
}

# ---- RemoteStopTransaction.req ----------------------------------
fn remote_stop_transaction_req_schema() -> s.ModelSchema {
  { title: "RemoteStopTransactionRequest", description: "OCPP 1.6 — RemoteStopTransaction.req", fields: [s.required_int("transactionId", [])] }
}

fn validate_remote_stop_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(remote_stop_transaction_req_schema(), j)
}

# ---- UnlockConnector.req ----------------------------------------
fn unlock_connector_req_schema() -> s.ModelSchema {
  { title: "UnlockConnectorRequest", description: "OCPP 1.6 — UnlockConnector.req", fields: [s.required_int("connectorId", [IntPositive])] }
}

fn validate_unlock_connector_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(unlock_connector_req_schema(), j)
}

# ---- TriggerMessage.req -----------------------------------------
fn trigger_message_req_schema() -> s.ModelSchema {
  { title: "TriggerMessageRequest", description: "OCPP 1.6 — TriggerMessage.req", fields: [s.required_str("requestedMessage", [StrOneOf(en.all_message_trigger())]), s.optional(s.required_int("connectorId", [IntPositive]))] }
}

fn validate_trigger_message_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(trigger_message_req_schema(), j)
}

# ============================================================
# Bulk lookup
# ============================================================
#
# Maps action name → validator. Useful for higher-level dispatchers
# that want to validate every Call uniformly without re-registering.
type ActionValidator = { action :: Str, validator :: (jv.Json) -> Result[jv.Json, List[e.Error]] }

fn all_request_validators() -> List[ActionValidator] {
  [{ action: "Authorize", validator: validate_authorize_req }, { action: "BootNotification", validator: validate_boot_notification_req }, { action: "Heartbeat", validator: validate_heartbeat_req }, { action: "StatusNotification", validator: validate_status_notification_req }, { action: "StartTransaction", validator: validate_start_transaction_req }, { action: "StopTransaction", validator: validate_stop_transaction_req }, { action: "MeterValues", validator: validate_meter_values_req }, { action: "DataTransfer", validator: validate_data_transfer_req }, { action: "FirmwareStatusNotification", validator: validate_firmware_status_notification_req }, { action: "DiagnosticsStatusNotification", validator: validate_diagnostics_status_notification_req }, { action: "Reset", validator: validate_reset_req }, { action: "ChangeAvailability", validator: validate_change_availability_req }, { action: "ChangeConfiguration", validator: validate_change_configuration_req }, { action: "ClearCache", validator: validate_clear_cache_req }, { action: "GetConfiguration", validator: validate_get_configuration_req }, { action: "RemoteStartTransaction", validator: validate_remote_start_transaction_req }, { action: "RemoteStopTransaction", validator: validate_remote_stop_transaction_req }, { action: "UnlockConnector", validator: validate_unlock_connector_req }, { action: "TriggerMessage", validator: validate_trigger_message_req }]
}

fn find_validator(action :: Str) -> Option[(jv.Json) -> Result[jv.Json, List[e.Error]]] {
  list.fold(all_request_validators(), None, fn (acc :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]], av :: ActionValidator) -> Option[(jv.Json) -> Result[jv.Json, List[e.Error]]] {
    match acc {
      Some(_) => acc,
      None => if av.action == action {
        Some(av.validator)
      } else {
        None
      },
    }
  })
}

