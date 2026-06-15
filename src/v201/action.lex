# lex-ocpp — OCPP 2.0.1 action catalog
#
# Every action name OCPP 2.0.1 (Part 2 §1.1) defines, as a wire-
# exact string constant. Use these constants when registering
# handlers or constructing outbound Calls; the dispatcher matches
# on the exact string — typos surface as `NotImplemented` at
# runtime rather than typecheck failures.
#
# Two halves:
#   CP → CSMS (charging station-initiated)
#   CSMS → CP (CSMS-initiated)
# ============================================================
# Charging Station → CSMS
# ============================================================

fn authorize() -> Str {
  "Authorize"
}

fn boot_notification() -> Str {
  "BootNotification"
}

fn cleared_charging_limit() -> Str {
  "ClearedChargingLimit"
}

fn data_transfer() -> Str {
  "DataTransfer"
}

fn firmware_status_notification() -> Str {
  "FirmwareStatusNotification"
}

fn get_15118ev_certificate() -> Str {
  "Get15118EVCertificate"
}

fn get_certificate_status() -> Str {
  "GetCertificateStatus"
}

fn heartbeat() -> Str {
  "Heartbeat"
}

fn log_status_notification() -> Str {
  "LogStatusNotification"
}

fn meter_values() -> Str {
  "MeterValues"
}

fn notify_charging_limit() -> Str {
  "NotifyChargingLimit"
}

fn notify_customer_information() -> Str {
  "NotifyCustomerInformation"
}

fn notify_display_messages() -> Str {
  "NotifyDisplayMessages"
}

fn notify_ev_charging_needs() -> Str {
  "NotifyEVChargingNeeds"
}

fn notify_ev_charging_schedule() -> Str {
  "NotifyEVChargingSchedule"
}

fn notify_event() -> Str {
  "NotifyEvent"
}

fn notify_monitoring_report() -> Str {
  "NotifyMonitoringReport"
}

fn notify_report() -> Str {
  "NotifyReport"
}

fn publish_firmware_status_notification() -> Str {
  "PublishFirmwareStatusNotification"
}

fn report_charging_profiles() -> Str {
  "ReportChargingProfiles"
}

fn reservation_status_update() -> Str {
  "ReservationStatusUpdate"
}

fn security_event_notification() -> Str {
  "SecurityEventNotification"
}

fn sign_certificate() -> Str {
  "SignCertificate"
}

fn status_notification() -> Str {
  "StatusNotification"
}

fn transaction_event() -> Str {
  "TransactionEvent"
}

# ============================================================
# CSMS → Charging Station
# ============================================================
fn cancel_reservation() -> Str {
  "CancelReservation"
}

fn certificate_signed() -> Str {
  "CertificateSigned"
}

fn change_availability() -> Str {
  "ChangeAvailability"
}

fn clear_cache() -> Str {
  "ClearCache"
}

fn clear_charging_profile() -> Str {
  "ClearChargingProfile"
}

fn clear_display_message() -> Str {
  "ClearDisplayMessage"
}

fn clear_variable_monitoring() -> Str {
  "ClearVariableMonitoring"
}

fn cost_updated() -> Str {
  "CostUpdated"
}

fn customer_information() -> Str {
  "CustomerInformation"
}

fn delete_certificate() -> Str {
  "DeleteCertificate"
}

fn get_base_report() -> Str {
  "GetBaseReport"
}

fn get_charging_profiles() -> Str {
  "GetChargingProfiles"
}

fn get_composite_schedule() -> Str {
  "GetCompositeSchedule"
}

fn get_display_messages() -> Str {
  "GetDisplayMessages"
}

fn get_installed_certificate_ids() -> Str {
  "GetInstalledCertificateIds"
}

fn get_local_list_version() -> Str {
  "GetLocalListVersion"
}

fn get_log() -> Str {
  "GetLog"
}

fn get_monitoring_report() -> Str {
  "GetMonitoringReport"
}

fn get_report() -> Str {
  "GetReport"
}

fn get_transaction_status() -> Str {
  "GetTransactionStatus"
}

fn get_variables() -> Str {
  "GetVariables"
}

fn install_certificate() -> Str {
  "InstallCertificate"
}

fn publish_firmware() -> Str {
  "PublishFirmware"
}

fn request_start_transaction() -> Str {
  "RequestStartTransaction"
}

fn request_stop_transaction() -> Str {
  "RequestStopTransaction"
}

fn reserve_now() -> Str {
  "ReserveNow"
}

fn reset() -> Str {
  "Reset"
}

fn send_local_list() -> Str {
  "SendLocalList"
}

fn set_charging_profile() -> Str {
  "SetChargingProfile"
}

fn set_display_message() -> Str {
  "SetDisplayMessage"
}

fn set_monitoring_base() -> Str {
  "SetMonitoringBase"
}

fn set_monitoring_level() -> Str {
  "SetMonitoringLevel"
}

fn set_network_profile() -> Str {
  "SetNetworkProfile"
}

fn set_variable_monitoring() -> Str {
  "SetVariableMonitoring"
}

fn set_variables() -> Str {
  "SetVariables"
}

fn trigger_message() -> Str {
  "TriggerMessage"
}

fn unlock_connector() -> Str {
  "UnlockConnector"
}

fn unpublish_firmware() -> Str {
  "UnpublishFirmware"
}

fn update_firmware() -> Str {
  "UpdateFirmware"
}

# ============================================================
# Bulk catalogs
# ============================================================
fn cs_to_csms() -> List[Str] {
  [authorize(), boot_notification(), cleared_charging_limit(), data_transfer(), firmware_status_notification(), get_15118ev_certificate(), get_certificate_status(), heartbeat(), log_status_notification(), meter_values(), notify_charging_limit(), notify_customer_information(), notify_display_messages(), notify_ev_charging_needs(), notify_ev_charging_schedule(), notify_event(), notify_monitoring_report(), notify_report(), publish_firmware_status_notification(), report_charging_profiles(), reservation_status_update(), security_event_notification(), sign_certificate(), status_notification(), transaction_event()]
}

fn csms_to_cs() -> List[Str] {
  [cancel_reservation(), certificate_signed(), change_availability(), clear_cache(), clear_charging_profile(), clear_display_message(), clear_variable_monitoring(), cost_updated(), customer_information(), data_transfer(), delete_certificate(), get_base_report(), get_charging_profiles(), get_composite_schedule(), get_display_messages(), get_installed_certificate_ids(), get_local_list_version(), get_log(), get_monitoring_report(), get_report(), get_transaction_status(), get_variables(), install_certificate(), publish_firmware(), request_start_transaction(), request_stop_transaction(), reserve_now(), reset(), send_local_list(), set_charging_profile(), set_display_message(), set_monitoring_base(), set_monitoring_level(), set_network_profile(), set_variable_monitoring(), set_variables(), trigger_message(), unlock_connector(), unpublish_firmware(), update_firmware()]
}

