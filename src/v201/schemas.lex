# lex-ocpp — OCPP 2.0.1 payload validators
#
# Scope: the highest-traffic Calls in OCPP 2.0.1 — boot / heartbeat
# / authorize / status / transaction / meter / data-transfer plus
# the three reset / start / stop admin commands. Add more by
# following the same pattern; the OCPP 2.0.1 spec defines ~64
# actions and the surface here covers the ~10 every CSMS must
# implement.
#
# Conventions:
#   - Nested record types (IdToken, ChargingStation, Modem,
#     EVSE, MeterValue, …) are surfaced as `ModelSchema` values
#     so they can be reused across messages.
#   - Optional fields use `s.optional(...)` to flip required → false.
#   - Enum fields use `StrOneOf` over the matching `enums.all_*()`
#     catalog from `v201/enums.lex`.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/schema" as s

import "lex-schema/error" as e

import "lex-schema/constraints" as c

import "./enums" as en

# ============================================================
# Shared nested schemas
# ============================================================
# ---- ModemType --------------------------------------------------
fn modem_schema() -> s.ModelSchema {
  { title: "Modem", description: "", fields: [s.optional(s.required_str("iccid", [StrMaxLen(20)])), s.optional(s.required_str("imsi", [StrMaxLen(20)]))] }
}

# ---- ChargingStationType ----------------------------------------
fn charging_station_schema() -> s.ModelSchema {
  { title: "ChargingStation", description: "", fields: [s.optional(s.required_str("serialNumber", [StrMaxLen(25)])), s.required_str("model", [StrNonEmpty, StrMaxLen(20)]), s.required_str("vendorName", [StrNonEmpty, StrMaxLen(50)]), s.optional(s.required_str("firmwareVersion", [StrMaxLen(50)])), s.optional(s.required_object("modem", modem_schema()))] }
}

# ---- IdTokenType ------------------------------------------------
fn id_token_schema() -> s.ModelSchema {
  { title: "IdToken", description: "", fields: [s.required_str("idToken", [StrNonEmpty, StrMaxLen(36)]), s.required_str("type", [StrOneOf(en.all_id_token_type())])] }
}

# ---- IdTokenInfoType (response side) ----------------------------
fn id_token_info_schema() -> s.ModelSchema {
  { title: "IdTokenInfo", description: "", fields: [s.required_str("status", [StrOneOf(en.all_authorization_status())]), s.optional(s.required_str("cacheExpiryDateTime", [StrNonEmpty])), s.optional(s.required_int("chargingPriority", [])), s.optional(s.required_str("language1", [StrMaxLen(8)])), s.optional(s.required_str("language2", [StrMaxLen(8)])), s.optional(s.required_array("evseId", KInt([]), []))] }
}

# ---- StatusInfoType ---------------------------------------------
fn status_info_schema() -> s.ModelSchema {
  { title: "StatusInfo", description: "", fields: [s.required_str("reasonCode", [StrNonEmpty, StrMaxLen(20)]), s.optional(s.required_str("additionalInfo", [StrMaxLen(512)]))] }
}

# ---- EVSEType ---------------------------------------------------
fn evse_schema() -> s.ModelSchema {
  { title: "EVSE", description: "", fields: [s.required_int("id", [IntNonNegative]), s.optional(s.required_int("connectorId", [IntNonNegative]))] }
}

# ---- TransactionType --------------------------------------------
fn transaction_schema() -> s.ModelSchema {
  { title: "Transaction", description: "", fields: [s.required_str("transactionId", [StrNonEmpty, StrMaxLen(36)]), s.optional(s.required_str("chargingState", [StrOneOf(en.all_charging_state())])), s.optional(s.required_int("timeSpentCharging", [IntNonNegative])), s.optional(s.required_str("stoppedReason", [StrNonEmpty])), s.optional(s.required_int("remoteStartId", []))] }
}

# ---- SampledValueType + MeterValueType --------------------------
fn sampled_value_schema() -> s.ModelSchema {
  { title: "SampledValue", description: "", fields: [s.required_float("value", []), s.optional(s.required_str("context", [StrNonEmpty])), s.optional(s.required_str("measurand", [StrNonEmpty])), s.optional(s.required_str("phase", [StrNonEmpty])), s.optional(s.required_str("location", [StrNonEmpty]))] }
}

fn meter_value_schema() -> s.ModelSchema {
  { title: "MeterValue", description: "", fields: [s.required_str("timestamp", [StrNonEmpty]), s.required_array("sampledValue", KObject(sampled_value_schema()), [ListNonEmpty])] }
}

# ============================================================
# CP → CSMS request schemas
# ============================================================
# ---- BootNotification.req ---------------------------------------
fn boot_notification_req_schema() -> s.ModelSchema {
  { title: "BootNotificationRequest", description: "OCPP 2.0.1 — BootNotification.req", fields: [s.required_object("chargingStation", charging_station_schema()), s.required_str("reason", [StrOneOf(en.all_boot_reason())])] }
}

fn validate_boot_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(boot_notification_req_schema(), j)
}

# ---- Heartbeat.req ----------------------------------------------
fn heartbeat_req_schema() -> s.ModelSchema {
  { title: "HeartbeatRequest", description: "OCPP 2.0.1 — Heartbeat.req", fields: [] }
}

fn validate_heartbeat_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(heartbeat_req_schema(), j)
}

# ---- Authorize.req ----------------------------------------------
fn authorize_req_schema() -> s.ModelSchema {
  { title: "AuthorizeRequest", description: "OCPP 2.0.1 — Authorize.req", fields: [s.required_object("idToken", id_token_schema()), s.optional(s.required_str("certificate", [StrMaxLen(5500)]))] }
}

fn validate_authorize_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(authorize_req_schema(), j)
}

# ---- StatusNotification.req -------------------------------------
fn status_notification_req_schema() -> s.ModelSchema {
  { title: "StatusNotificationRequest", description: "OCPP 2.0.1 — StatusNotification.req", fields: [s.required_str("timestamp", [StrNonEmpty]), s.required_str("connectorStatus", [StrOneOf(en.all_connector_status())]), s.required_int("evseId", [IntNonNegative]), s.required_int("connectorId", [IntNonNegative])] }
}

fn validate_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(status_notification_req_schema(), j)
}

# ---- TransactionEvent.req ---------------------------------------
fn transaction_event_req_schema() -> s.ModelSchema {
  { title: "TransactionEventRequest", description: "OCPP 2.0.1 — TransactionEvent.req", fields: [s.required_str("eventType", [StrOneOf(en.all_transaction_event())]), s.required_str("timestamp", [StrNonEmpty]), s.required_str("triggerReason", [StrOneOf(en.all_trigger_reason())]), s.required_int("seqNo", [IntNonNegative]), s.required_object("transactionInfo", transaction_schema()), s.optional(s.required_object("idToken", id_token_schema())), s.optional(s.required_object("evse", evse_schema())), s.optional(s.required_array("meterValue", KObject(meter_value_schema()), [])), s.optional(s.required_bool("offline")), s.optional(s.required_int("numberOfPhasesUsed", [IntNonNegative])), s.optional(s.required_float("cableMaxCurrent", [])), s.optional(s.required_int("reservationId", []))] }
}

fn validate_transaction_event_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(transaction_event_req_schema(), j)
}

# ---- MeterValues.req --------------------------------------------
fn meter_values_req_schema() -> s.ModelSchema {
  { title: "MeterValuesRequest", description: "OCPP 2.0.1 — MeterValues.req", fields: [s.required_int("evseId", [IntNonNegative]), s.required_array("meterValue", KObject(meter_value_schema()), [ListNonEmpty])] }
}

fn validate_meter_values_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(meter_values_req_schema(), j)
}

# ---- DataTransfer.req -------------------------------------------
fn data_transfer_req_schema() -> s.ModelSchema {
  { title: "DataTransferRequest", description: "OCPP 2.0.1 — DataTransfer.req", fields: [s.required_str("vendorId", [StrNonEmpty, StrMaxLen(255)]), s.optional(s.required_str("messageId", [StrMaxLen(50)])), s.optional(s.required_str("data", []))] }
}

fn validate_data_transfer_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(data_transfer_req_schema(), j)
}

# ---- FirmwareStatusNotification.req -----------------------------
fn firmware_status_notification_req_schema() -> s.ModelSchema {
  { title: "FirmwareStatusNotificationRequest", description: "OCPP 2.0.1 — FirmwareStatusNotification.req", fields: [s.required_str("status", [StrOneOf(en.all_firmware_status())]), s.optional(s.required_int("requestId", []))] }
}

fn validate_firmware_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(firmware_status_notification_req_schema(), j)
}

# ---- SecurityEventNotification.req ------------------------------
fn security_event_notification_req_schema() -> s.ModelSchema {
  { title: "SecurityEventNotificationRequest", description: "OCPP 2.0.1 — SecurityEventNotification.req", fields: [s.required_str("type", [StrNonEmpty, StrMaxLen(50)]), s.required_str("timestamp", [StrNonEmpty]), s.optional(s.required_str("techInfo", [StrMaxLen(255)]))] }
}

fn validate_security_event_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(security_event_notification_req_schema(), j)
}

# ============================================================
# CSMS → CP request schemas (selected)
# ============================================================
# ---- Reset.req --------------------------------------------------
fn reset_req_schema() -> s.ModelSchema {
  { title: "ResetRequest", description: "OCPP 2.0.1 — Reset.req", fields: [s.required_str("type", [StrOneOf(en.all_reset_type())]), s.optional(s.required_int("evseId", [IntNonNegative]))] }
}

fn validate_reset_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(reset_req_schema(), j)
}

# ---- RequestStartTransaction.req --------------------------------
fn request_start_transaction_req_schema() -> s.ModelSchema {
  { title: "RequestStartTransactionRequest", description: "OCPP 2.0.1 — RequestStartTransaction.req", fields: [s.optional(s.required_int("evseId", [IntNonNegative])), s.required_int("remoteStartId", []), s.required_object("idToken", id_token_schema())] }
}

fn validate_request_start_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(request_start_transaction_req_schema(), j)
}

# ---- RequestStopTransaction.req ---------------------------------
fn request_stop_transaction_req_schema() -> s.ModelSchema {
  { title: "RequestStopTransactionRequest", description: "OCPP 2.0.1 — RequestStopTransaction.req", fields: [s.required_str("transactionId", [StrNonEmpty, StrMaxLen(36)])] }
}

fn validate_request_stop_transaction_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(request_stop_transaction_req_schema(), j)
}

# ---- TriggerMessage.req -----------------------------------------
fn trigger_message_req_schema() -> s.ModelSchema {
  { title: "TriggerMessageRequest", description: "OCPP 2.0.1 — TriggerMessage.req", fields: [s.required_str("requestedMessage", [StrOneOf(en.all_message_trigger())]), s.optional(s.required_object("evse", evse_schema()))] }
}

fn validate_trigger_message_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(trigger_message_req_schema(), j)
}

# ---- ChangeAvailability.req -------------------------------------
fn change_availability_req_schema() -> s.ModelSchema {
  { title: "ChangeAvailabilityRequest", description: "OCPP 2.0.1 — ChangeAvailability.req", fields: [s.required_str("operationalStatus", [StrOneOf(["Inoperative", "Operative"])]), s.optional(s.required_object("evse", evse_schema()))] }
}

fn validate_change_availability_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(change_availability_req_schema(), j)
}

# ---- ClearCache.req ---------------------------------------------
fn clear_cache_req_schema() -> s.ModelSchema {
  { title: "ClearCacheRequest", description: "OCPP 2.0.1 — ClearCache.req", fields: [] }
}

fn validate_clear_cache_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(clear_cache_req_schema(), j)
}

# ---- CancelReservation.req --------------------------------------
fn cancel_reservation_req_schema() -> s.ModelSchema {
  { title: "CancelReservationRequest", description: "OCPP 2.0.1 — CancelReservation.req", fields: [s.required_int("reservationId", [])] }
}

fn validate_cancel_reservation_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(cancel_reservation_req_schema(), j)
}

# ---- GetVariables.req -------------------------------------------
#
# Spec: `getVariableData` is a non-empty list of GetVariableData
# records, each carrying a Component + Variable reference. Use the
# shared component / variable schemas defined below.
fn component_schema() -> s.ModelSchema {
  { title: "Component", description: "", fields: [s.required_str("name", [StrNonEmpty, StrMaxLen(50)]), s.optional(s.required_str("instance", [StrMaxLen(50)])), s.optional(s.required_object("evse", evse_schema()))] }
}

fn variable_schema() -> s.ModelSchema {
  { title: "Variable", description: "", fields: [s.required_str("name", [StrNonEmpty, StrMaxLen(50)]), s.optional(s.required_str("instance", [StrMaxLen(50)]))] }
}

fn get_variable_data_schema() -> s.ModelSchema {
  { title: "GetVariableData", description: "", fields: [s.optional(s.required_str("attributeType", [StrOneOf(["Actual", "Target", "MinSet", "MaxSet"])])), s.required_object("component", component_schema()), s.required_object("variable", variable_schema())] }
}

fn get_variables_req_schema() -> s.ModelSchema {
  { title: "GetVariablesRequest", description: "OCPP 2.0.1 — GetVariables.req", fields: [s.required_array("getVariableData", KObject(get_variable_data_schema()), [ListNonEmpty])] }
}

fn validate_get_variables_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(get_variables_req_schema(), j)
}

# ---- SetVariables.req -------------------------------------------
fn set_variable_data_schema() -> s.ModelSchema {
  { title: "SetVariableData", description: "", fields: [s.optional(s.required_str("attributeType", [StrOneOf(["Actual", "Target", "MinSet", "MaxSet"])])), s.required_str("attributeValue", [StrMaxLen(1000)]), s.required_object("component", component_schema()), s.required_object("variable", variable_schema())] }
}

fn set_variables_req_schema() -> s.ModelSchema {
  { title: "SetVariablesRequest", description: "OCPP 2.0.1 — SetVariables.req", fields: [s.required_array("setVariableData", KObject(set_variable_data_schema()), [ListNonEmpty])] }
}

fn validate_set_variables_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(set_variables_req_schema(), j)
}

# ---- GetBaseReport.req ------------------------------------------
fn get_base_report_req_schema() -> s.ModelSchema {
  { title: "GetBaseReportRequest", description: "OCPP 2.0.1 — GetBaseReport.req", fields: [s.required_int("requestId", []), s.required_str("reportBase", [StrOneOf(["ConfigurationInventory", "FullInventory", "SummaryInventory"])])] }
}

fn validate_get_base_report_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(get_base_report_req_schema(), j)
}

# ---- NotifyEvent.req --------------------------------------------
fn event_data_schema() -> s.ModelSchema {
  { title: "EventData", description: "", fields: [s.required_int("eventId", []), s.required_str("timestamp", [StrNonEmpty]), s.required_str("trigger", [StrOneOf(["Alerting", "Delta", "Periodic"])]), s.required_str("actualValue", [StrMaxLen(2500)]), s.required_str("eventNotificationType", [StrOneOf(["HardWiredNotification", "HardWiredMonitor", "PreconfiguredMonitor", "CustomMonitor"])]), s.required_object("component", component_schema()), s.required_object("variable", variable_schema())] }
}

fn notify_event_req_schema() -> s.ModelSchema {
  { title: "NotifyEventRequest", description: "OCPP 2.0.1 — NotifyEvent.req", fields: [s.required_str("generatedAt", [StrNonEmpty]), s.required_int("seqNo", [IntNonNegative]), s.required_array("eventData", KObject(event_data_schema()), [ListNonEmpty]), s.optional(s.required_bool("tbc"))] }
}

fn validate_notify_event_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_event_req_schema(), j)
}

# ---- LogStatusNotification.req ----------------------------------
fn log_status_notification_req_schema() -> s.ModelSchema {
  { title: "LogStatusNotificationRequest", description: "OCPP 2.0.1 — LogStatusNotification.req", fields: [s.required_str("status", [StrOneOf(["BadMessage", "Idle", "NotSupportedOperation", "PermissionDenied", "Uploaded", "UploadFailure", "Uploading", "AcceptedCanceled"])]), s.optional(s.required_int("requestId", []))] }
}

fn validate_log_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(log_status_notification_req_schema(), j)
}

# ---- SignCertificate.req ----------------------------------------
fn sign_certificate_req_schema() -> s.ModelSchema {
  { title: "SignCertificateRequest", description: "OCPP 2.0.1 — SignCertificate.req", fields: [s.required_str("csr", [StrNonEmpty, StrMaxLen(5500)]), s.optional(s.required_str("certificateType", [StrOneOf(["ChargingStationCertificate", "V2GCertificate"])]))] }
}

fn validate_sign_certificate_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(sign_certificate_req_schema(), j)
}

# ---- UpdateFirmware.req -----------------------------------------
fn firmware_type_schema() -> s.ModelSchema {
  { title: "Firmware", description: "", fields: [s.required_str("location", [StrNonEmpty, StrMaxLen(512)]), s.required_str("retrieveDateTime", [StrNonEmpty]), s.optional(s.required_str("installDateTime", [StrNonEmpty])), s.optional(s.required_str("signingCertificate", [StrMaxLen(5500)])), s.optional(s.required_str("signature", [StrMaxLen(800)]))] }
}

fn update_firmware_req_schema() -> s.ModelSchema {
  { title: "UpdateFirmwareRequest", description: "OCPP 2.0.1 — UpdateFirmware.req", fields: [s.optional(s.required_int("retries", [IntNonNegative])), s.optional(s.required_int("retryInterval", [IntNonNegative])), s.required_int("requestId", []), s.required_object("firmware", firmware_type_schema())] }
}

fn validate_update_firmware_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(update_firmware_req_schema(), j)
}

# ============================================================
# Bulk lookup
# ============================================================
type ActionValidator = { action :: Str, validator :: (jv.Json) -> Result[jv.Json, List[e.Error]] }

fn all_request_validators() -> List[ActionValidator] {
  [{ action: "Authorize", validator: validate_authorize_req }, { action: "BootNotification", validator: validate_boot_notification_req }, { action: "Heartbeat", validator: validate_heartbeat_req }, { action: "StatusNotification", validator: validate_status_notification_req }, { action: "TransactionEvent", validator: validate_transaction_event_req }, { action: "MeterValues", validator: validate_meter_values_req }, { action: "DataTransfer", validator: validate_data_transfer_req }, { action: "FirmwareStatusNotification", validator: validate_firmware_status_notification_req }, { action: "SecurityEventNotification", validator: validate_security_event_notification_req }, { action: "Reset", validator: validate_reset_req }, { action: "RequestStartTransaction", validator: validate_request_start_transaction_req }, { action: "RequestStopTransaction", validator: validate_request_stop_transaction_req }, { action: "TriggerMessage", validator: validate_trigger_message_req }, { action: "ChangeAvailability", validator: validate_change_availability_req }, { action: "ClearCache", validator: validate_clear_cache_req }, { action: "CancelReservation", validator: validate_cancel_reservation_req }, { action: "GetVariables", validator: validate_get_variables_req }, { action: "SetVariables", validator: validate_set_variables_req }, { action: "GetBaseReport", validator: validate_get_base_report_req }, { action: "NotifyEvent", validator: validate_notify_event_req }, { action: "LogStatusNotification", validator: validate_log_status_notification_req }, { action: "SignCertificate", validator: validate_sign_certificate_req }, { action: "UpdateFirmware", validator: validate_update_firmware_req }]
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

