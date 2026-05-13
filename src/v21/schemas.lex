# lex-ocpp — OCPP 2.1 payload validators
#
# Two halves:
#
#   1. Carry-overs from 2.0.1 (BootNotification, Heartbeat, Authorize,
#      StatusNotification, TransactionEvent, MeterValues, DataTransfer,
#      FirmwareStatusNotification, SecurityEventNotification, Reset,
#      RequestStartTransaction, RequestStopTransaction, TriggerMessage,
#      ChangeAvailability) — payload shapes are unchanged from 2.0.1
#      but a handful of enums grew (IdTokenType, ChargingState,
#      EnergyTransferMode). Re-validated here with the 2.1 enum
#      catalog so future drift is local to this file.
#
#   2. 2.1-additions — BatterySwap, NotifyAllowedEnergyTransfer,
#      NotifyPeriodicEventStream / OpenPeriodicEventStream /
#      ClosePeriodicEventStream / AdjustPeriodicEventStream,
#      GetDERControl / SetDERControl / ClearDERControl /
#      NotifyDERAlarm / NotifyDERStartStop, ChangeTransactionTariff,
#      NotifyWebPaymentStarted, UsePriorityCharging,
#      UpdateDynamicSchedule.
#
# Scope: ~25 actions, covering the 2.0.1 baseline + every 2.1
# *addition* used in practice. The remaining v2.1 admin commands
# (GetTariffs, ClearTariffs, etc.) follow the same shape as their
# v201 equivalents and can be added as the user need arises.

import "std.list" as list

import "lex-schema/json_value"  as jv
import "lex-schema/schema"      as s
import "lex-schema/error"       as e
import "lex-schema/constraints" as c

import "./enums" as en

# ============================================================
# Shared nested schemas (mostly reuse 2.0.1 shapes — re-declared
# here so v21 callers need only one import root).
# ============================================================

fn modem_schema() -> s.ModelSchema {
  {
    title: "Modem", description: "",
    fields: [
      s.optional(s.required_str("iccid", [StrMaxLen(20)])),
      s.optional(s.required_str("imsi",  [StrMaxLen(20)])),
    ],
  }
}

fn charging_station_schema() -> s.ModelSchema {
  {
    title: "ChargingStation", description: "",
    fields: [
      s.optional(s.required_str("serialNumber",   [StrMaxLen(25)])),
      s.required_str("model",                      [StrNonEmpty, StrMaxLen(20)]),
      s.required_str("vendorName",                 [StrNonEmpty, StrMaxLen(50)]),
      s.optional(s.required_str("firmwareVersion", [StrMaxLen(50)])),
      s.optional(s.required_object("modem",        modem_schema())),
    ],
  }
}

# IdToken — note the v2.1 enum catalog covers VIN + ISO15118v20.
fn id_token_schema() -> s.ModelSchema {
  {
    title: "IdToken", description: "",
    fields: [
      s.required_str("idToken", [StrNonEmpty, StrMaxLen(36)]),
      s.required_str("type",    [StrOneOf(en.all_id_token_type())]),
    ],
  }
}

fn evse_schema() -> s.ModelSchema {
  {
    title: "EVSE", description: "",
    fields: [
      s.required_int("id",                    [IntNonNegative]),
      s.optional(s.required_int("connectorId", [IntNonNegative])),
    ],
  }
}

# Transaction — includes 2.1's "Discharging" state via the enum.
fn transaction_schema() -> s.ModelSchema {
  {
    title: "Transaction", description: "",
    fields: [
      s.required_str("transactionId", [StrNonEmpty, StrMaxLen(36)]),
      s.optional(s.required_str("chargingState",     [StrOneOf(en.all_charging_state())])),
      s.optional(s.required_int("timeSpentCharging", [IntNonNegative])),
      s.optional(s.required_str("stoppedReason",     [StrNonEmpty])),
      s.optional(s.required_int("remoteStartId",     [])),
    ],
  }
}

fn sampled_value_schema() -> s.ModelSchema {
  {
    title: "SampledValue", description: "",
    fields: [
      s.required_float("value", []),
      s.optional(s.required_str("context",   [StrNonEmpty])),
      s.optional(s.required_str("measurand", [StrNonEmpty])),
      s.optional(s.required_str("phase",     [StrNonEmpty])),
      s.optional(s.required_str("location",  [StrNonEmpty])),
    ],
  }
}

fn meter_value_schema() -> s.ModelSchema {
  {
    title: "MeterValue", description: "",
    fields: [
      s.required_str("timestamp",      [StrNonEmpty]),
      s.required_array("sampledValue", KObject(sampled_value_schema()), [ListNonEmpty]),
    ],
  }
}

# ============================================================
# Carry-overs from 2.0.1 (validated against v2.1 enums)
# ============================================================

fn boot_notification_req_schema() -> s.ModelSchema {
  {
    title: "BootNotificationRequest",
    description: "OCPP 2.1 — BootNotification.req",
    fields: [
      s.required_object("chargingStation", charging_station_schema()),
      s.required_str("reason", [StrOneOf(en.all_boot_reason())]),
    ],
  }
}

fn validate_boot_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(boot_notification_req_schema(), j)
}

fn heartbeat_req_schema() -> s.ModelSchema {
  { title: "HeartbeatRequest",
    description: "OCPP 2.1 — Heartbeat.req",
    fields: [] }
}

fn validate_heartbeat_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(heartbeat_req_schema(), j)
}

fn authorize_req_schema() -> s.ModelSchema {
  {
    title: "AuthorizeRequest",
    description: "OCPP 2.1 — Authorize.req",
    fields: [
      s.required_object("idToken", id_token_schema()),
      s.optional(s.required_str("certificate", [StrMaxLen(5500)])),
    ],
  }
}

fn validate_authorize_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(authorize_req_schema(), j)
}

fn status_notification_req_schema() -> s.ModelSchema {
  {
    title: "StatusNotificationRequest",
    description: "OCPP 2.1 — StatusNotification.req",
    fields: [
      s.required_str("timestamp",       [StrNonEmpty]),
      s.required_str("connectorStatus", [StrOneOf(en.all_connector_status())]),
      s.required_int("evseId",          [IntNonNegative]),
      s.required_int("connectorId",     [IntNonNegative]),
    ],
  }
}

fn validate_status_notification_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(status_notification_req_schema(), j)
}

fn transaction_event_req_schema() -> s.ModelSchema {
  {
    title: "TransactionEventRequest",
    description: "OCPP 2.1 — TransactionEvent.req",
    fields: [
      s.required_str("eventType",       [StrOneOf(en.all_transaction_event())]),
      s.required_str("timestamp",       [StrNonEmpty]),
      s.required_int("seqNo",           [IntNonNegative]),
      s.required_object("transactionInfo", transaction_schema()),
      s.optional(s.required_object("idToken",  id_token_schema())),
      s.optional(s.required_object("evse",     evse_schema())),
      s.optional(s.required_array("meterValue",
        KObject(meter_value_schema()), [])),
      s.optional(s.required_bool("offline")),
      s.optional(s.required_int("numberOfPhasesUsed", [IntNonNegative])),
      s.optional(s.required_float("cableMaxCurrent",  [])),
      s.optional(s.required_int("reservationId",      [])),
    ],
  }
}

fn validate_transaction_event_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(transaction_event_req_schema(), j)
}

fn data_transfer_req_schema() -> s.ModelSchema {
  {
    title: "DataTransferRequest",
    description: "OCPP 2.1 — DataTransfer.req",
    fields: [
      s.required_str("vendorId",         [StrNonEmpty, StrMaxLen(255)]),
      s.optional(s.required_str("messageId", [StrMaxLen(50)])),
      s.optional(s.required_str("data",      [])),
    ],
  }
}

fn validate_data_transfer_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(data_transfer_req_schema(), j)
}

fn reset_req_schema() -> s.ModelSchema {
  {
    title: "ResetRequest",
    description: "OCPP 2.1 — Reset.req",
    fields: [
      s.required_str("type",   [StrOneOf(en.all_reset_type())]),
      s.optional(s.required_int("evseId", [IntNonNegative])),
    ],
  }
}

fn validate_reset_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(reset_req_schema(), j)
}

# ============================================================
# v2.1 additions
# ============================================================

# ---- BatterySwap.req --------------------------------------------

fn battery_data_schema() -> s.ModelSchema {
  {
    title: "BatteryData", description: "",
    fields: [
      s.required_int("evseId",       [IntNonNegative]),
      s.required_str("serialNumber", [StrNonEmpty, StrMaxLen(50)]),
      s.required_float("soC",        [FloatInRange(0.0, 100.0)]),
      s.required_float("soH",        [FloatInRange(0.0, 100.0)]),
      s.optional(s.required_str("productionDate", [StrNonEmpty])),
      s.optional(s.required_str("vendorInfo",     [StrMaxLen(500)])),
    ],
  }
}

fn battery_swap_req_schema() -> s.ModelSchema {
  {
    title: "BatterySwapRequest",
    description: "OCPP 2.1 — BatterySwap.req",
    fields: [
      s.required_str("eventType", [StrOneOf(en.all_battery_swap_event())]),
      s.required_object("idToken", id_token_schema()),
      s.required_int("requestId",  []),
      s.required_array("batteryData",
        KObject(battery_data_schema()), [ListNonEmpty]),
    ],
  }
}

fn validate_battery_swap_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(battery_swap_req_schema(), j)
}

# ---- NotifyAllowedEnergyTransfer.req ----------------------------

fn notify_allowed_energy_transfer_req_schema() -> s.ModelSchema {
  {
    title: "NotifyAllowedEnergyTransferRequest",
    description: "OCPP 2.1 — NotifyAllowedEnergyTransfer.req",
    fields: [
      s.required_int("transactionId", []),
      s.required_array("allowedEnergyTransfer",
        KStr([StrOneOf(en.all_energy_transfer_mode())]),
        [ListNonEmpty]),
    ],
  }
}

fn validate_notify_allowed_energy_transfer_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_allowed_energy_transfer_req_schema(), j)
}

# ---- OpenPeriodicEventStream.req --------------------------------

fn periodic_event_stream_params_schema() -> s.ModelSchema {
  {
    title: "PeriodicEventStreamParams", description: "",
    fields: [
      s.required_int("interval", [IntInRange(1, 86400)]),
      s.required_int("values",   [IntInRange(1, 100)]),
    ],
  }
}

fn open_periodic_event_stream_req_schema() -> s.ModelSchema {
  {
    title: "OpenPeriodicEventStreamRequest",
    description: "OCPP 2.1 — OpenPeriodicEventStream.req",
    fields: [
      s.required_object("constantStreamData",
        periodic_event_stream_params_schema()),
    ],
  }
}

fn validate_open_periodic_event_stream_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(open_periodic_event_stream_req_schema(), j)
}

# ---- ClosePeriodicEventStream.req -------------------------------

fn close_periodic_event_stream_req_schema() -> s.ModelSchema {
  {
    title: "ClosePeriodicEventStreamRequest",
    description: "OCPP 2.1 — ClosePeriodicEventStream.req",
    fields: [
      s.required_int("id", [IntNonNegative]),
    ],
  }
}

fn validate_close_periodic_event_stream_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(close_periodic_event_stream_req_schema(), j)
}

# ---- NotifyPeriodicEventStream.req ------------------------------

fn stream_data_element_schema() -> s.ModelSchema {
  {
    title: "StreamDataElement", description: "",
    fields: [
      s.required_float("t", []),
      s.required_str("v",   [StrMaxLen(2500)]),
    ],
  }
}

fn notify_periodic_event_stream_req_schema() -> s.ModelSchema {
  {
    title: "NotifyPeriodicEventStreamRequest",
    description: "OCPP 2.1 — NotifyPeriodicEventStream.req",
    fields: [
      s.required_int("id",      [IntNonNegative]),
      s.required_str("pending", [StrNonEmpty]),
      s.required_str("basetime", [StrNonEmpty]),
      s.required_int("seqNo",   [IntNonNegative]),
      s.required_array("data",  KObject(stream_data_element_schema()),
                                [ListNonEmpty]),
    ],
  }
}

fn validate_notify_periodic_event_stream_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_periodic_event_stream_req_schema(), j)
}

# ---- GetDERControl.req ------------------------------------------

fn get_der_control_req_schema() -> s.ModelSchema {
  {
    title: "GetDERControlRequest",
    description: "OCPP 2.1 — GetDERControl.req",
    fields: [
      s.required_int("requestId",   []),
      s.optional(s.required_bool("isDefault")),
      s.optional(s.required_str("controlType",
        [StrOneOf(en.all_der_control_type())])),
      s.optional(s.required_str("controlId", [StrMaxLen(36)])),
    ],
  }
}

fn validate_get_der_control_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(get_der_control_req_schema(), j)
}

# ---- SetDERControl.req ------------------------------------------

fn set_der_control_req_schema() -> s.ModelSchema {
  {
    title: "SetDERControlRequest",
    description: "OCPP 2.1 — SetDERControl.req",
    fields: [
      s.required_bool("isDefault"),
      s.required_str("controlId",   [StrNonEmpty, StrMaxLen(36)]),
      s.required_str("controlType", [StrOneOf(en.all_der_control_type())]),
    ],
  }
}

fn validate_set_der_control_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(set_der_control_req_schema(), j)
}

# ---- ClearDERControl.req ----------------------------------------

fn clear_der_control_req_schema() -> s.ModelSchema {
  {
    title: "ClearDERControlRequest",
    description: "OCPP 2.1 — ClearDERControl.req",
    fields: [
      s.required_bool("isDefault"),
      s.optional(s.required_str("controlType",
        [StrOneOf(en.all_der_control_type())])),
      s.optional(s.required_str("controlId", [StrMaxLen(36)])),
    ],
  }
}

fn validate_clear_der_control_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(clear_der_control_req_schema(), j)
}

# ---- NotifyDERAlarm.req -----------------------------------------

fn notify_der_alarm_req_schema() -> s.ModelSchema {
  {
    title: "NotifyDERAlarmRequest",
    description: "OCPP 2.1 — NotifyDERAlarm.req",
    fields: [
      s.required_str("controlType", [StrOneOf(en.all_der_control_type())]),
      s.required_str("timestamp",   [StrNonEmpty]),
      s.optional(s.required_str("gridEventFault", [StrMaxLen(255)])),
      s.optional(s.required_bool("alarmEnded")),
      s.optional(s.required_str("extraInfo",      [StrMaxLen(200)])),
    ],
  }
}

fn validate_notify_der_alarm_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_der_alarm_req_schema(), j)
}

# ---- NotifyDERStartStop.req -------------------------------------

fn notify_der_start_stop_req_schema() -> s.ModelSchema {
  {
    title: "NotifyDERStartStopRequest",
    description: "OCPP 2.1 — NotifyDERStartStop.req",
    fields: [
      s.required_str("controlId", [StrNonEmpty, StrMaxLen(36)]),
      s.required_bool("started"),
      s.required_str("timestamp", [StrNonEmpty]),
    ],
  }
}

fn validate_notify_der_start_stop_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_der_start_stop_req_schema(), j)
}

# ---- ChangeTransactionTariff.req --------------------------------

fn change_transaction_tariff_req_schema() -> s.ModelSchema {
  {
    title: "ChangeTransactionTariffRequest",
    description: "OCPP 2.1 — ChangeTransactionTariff.req",
    fields: [
      s.required_str("transactionId", [StrNonEmpty, StrMaxLen(36)]),
      s.required_str("tariffId",      [StrNonEmpty, StrMaxLen(60)]),
    ],
  }
}

fn validate_change_transaction_tariff_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(change_transaction_tariff_req_schema(), j)
}

# ---- NotifyWebPaymentStarted.req --------------------------------

fn notify_web_payment_started_req_schema() -> s.ModelSchema {
  {
    title: "NotifyWebPaymentStartedRequest",
    description: "OCPP 2.1 — NotifyWebPaymentStarted.req",
    fields: [
      s.required_int("evseId",  [IntNonNegative]),
      s.required_int("timeout", [IntNonNegative]),
    ],
  }
}

fn validate_notify_web_payment_started_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(notify_web_payment_started_req_schema(), j)
}

# ---- UsePriorityCharging.req ------------------------------------

fn use_priority_charging_req_schema() -> s.ModelSchema {
  {
    title: "UsePriorityChargingRequest",
    description: "OCPP 2.1 — UsePriorityCharging.req",
    fields: [
      s.required_str("transactionId", [StrNonEmpty, StrMaxLen(36)]),
      s.required_bool("activate"),
    ],
  }
}

fn validate_use_priority_charging_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(use_priority_charging_req_schema(), j)
}

# ---- UpdateDynamicSchedule.req ----------------------------------

fn schedule_update_schema() -> s.ModelSchema {
  {
    title: "ScheduleUpdate", description: "",
    fields: [
      s.required_float("limit", []),
      s.optional(s.required_int("numberPhases", [IntInRange(1, 3)])),
    ],
  }
}

fn update_dynamic_schedule_req_schema() -> s.ModelSchema {
  {
    title: "UpdateDynamicScheduleRequest",
    description: "OCPP 2.1 — UpdateDynamicSchedule.req",
    fields: [
      s.required_int("chargingProfileId",   []),
      s.required_object("scheduleUpdate",   schedule_update_schema()),
    ],
  }
}

fn validate_update_dynamic_schedule_req(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(update_dynamic_schedule_req_schema(), j)
}

# ============================================================
# Bulk lookup
# ============================================================

type ActionValidator = {
  action    :: Str,
  validator :: (jv.Json) -> Result[jv.Json, List[e.Error]],
}

fn all_request_validators() -> List[ActionValidator] {
  [
    # ---- shared with 2.0.1 ----
    { action: "Authorize",              validator: validate_authorize_req },
    { action: "BootNotification",       validator: validate_boot_notification_req },
    { action: "Heartbeat",              validator: validate_heartbeat_req },
    { action: "StatusNotification",     validator: validate_status_notification_req },
    { action: "TransactionEvent",       validator: validate_transaction_event_req },
    { action: "DataTransfer",           validator: validate_data_transfer_req },
    { action: "Reset",                  validator: validate_reset_req },
    # ---- 2.1 additions ----
    { action: "BatterySwap",            validator: validate_battery_swap_req },
    { action: "NotifyAllowedEnergyTransfer",
      validator: validate_notify_allowed_energy_transfer_req },
    { action: "OpenPeriodicEventStream",
      validator: validate_open_periodic_event_stream_req },
    { action: "ClosePeriodicEventStream",
      validator: validate_close_periodic_event_stream_req },
    { action: "NotifyPeriodicEventStream",
      validator: validate_notify_periodic_event_stream_req },
    { action: "GetDERControl",          validator: validate_get_der_control_req },
    { action: "SetDERControl",          validator: validate_set_der_control_req },
    { action: "ClearDERControl",        validator: validate_clear_der_control_req },
    { action: "NotifyDERAlarm",         validator: validate_notify_der_alarm_req },
    { action: "NotifyDERStartStop",     validator: validate_notify_der_start_stop_req },
    { action: "ChangeTransactionTariff",
      validator: validate_change_transaction_tariff_req },
    { action: "NotifyWebPaymentStarted",
      validator: validate_notify_web_payment_started_req },
    { action: "UsePriorityCharging",    validator: validate_use_priority_charging_req },
    { action: "UpdateDynamicSchedule",  validator: validate_update_dynamic_schedule_req },
  ]
}

fn find_validator(action :: Str) -> Option[(jv.Json) -> Result[jv.Json, List[e.Error]]] {
  list.fold(all_request_validators(), None,
    fn (acc :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]],
        av  :: ActionValidator) -> Option[(jv.Json) -> Result[jv.Json, List[e.Error]]] {
      match acc {
        Some(_) => acc,
        None    => if av.action == action { Some(av.validator) } else { None },
      }
    })
}
