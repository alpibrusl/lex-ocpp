# lex-ocpp — OCPP 2.1 action catalog
#
# OCPP 2.1 (Open Charge Alliance, 2024) is an additive evolution
# of OCPP 2.0.1 — the RPC framing is unchanged (`[2, id, action,
# payload]` / `[3, …]` / `[4, …]`), and most of the 2.0.1 action
# names carry over with backward-compatible payload shapes.
#
# The deltas:
#
#   1. ISO 15118-20 / bidirectional charging (V2G, V2H, V2L, V2X) —
#      `NotifyAllowedEnergyTransfer`, `UsePriorityCharging`.
#   2. Battery swapping — `BatterySwap`, `RequestBatterySwap`.
#   3. Periodic event streams (high-frequency telemetry) —
#      `OpenPeriodicEventStream`, `ClosePeriodicEventStream`,
#      `NotifyPeriodicEventStream`, `AdjustPeriodicEventStream`,
#      `GetPeriodicEventStream`.
#   4. DER (Distributed Energy Resources) control —
#      `GetDERControl`, `SetDERControl`, `ClearDERControl`,
#      `NotifyDERAlarm`, `NotifyDERStartStop`, `ReportDERControl`.
#   5. Tariff & settlement — `ChangeTransactionTariff`,
#      `NotifySettlement`, `NotifyWebPaymentStarted`,
#      `GetTariffs`, `ClearTariffs`, `SetDefaultTariff`.
#   6. New dynamic-schedule flow — `UpdateDynamicSchedule`,
#      `PullDynamicScheduleUpdate`.
#
# WebSocket subprotocol: `"ocpp2.1"`. Use `cp_io.new_v21(id)` or
# `cp.new_v21(id)` to build a ChargePoint targeting 2.1.

# ============================================================
# Charging Station → CSMS (inherits the 2.0.1 surface + adds 2.1)
# ============================================================

fn authorize()                          -> Str { "Authorize" }
fn boot_notification()                  -> Str { "BootNotification" }
fn cleared_charging_limit()             -> Str { "ClearedChargingLimit" }
fn data_transfer()                      -> Str { "DataTransfer" }
fn firmware_status_notification()       -> Str { "FirmwareStatusNotification" }
fn get_15118ev_certificate()            -> Str { "Get15118EVCertificate" }
fn get_certificate_status()             -> Str { "GetCertificateStatus" }
fn heartbeat()                          -> Str { "Heartbeat" }
fn log_status_notification()            -> Str { "LogStatusNotification" }
fn meter_values()                       -> Str { "MeterValues" }
fn notify_charging_limit()              -> Str { "NotifyChargingLimit" }
fn notify_customer_information()        -> Str { "NotifyCustomerInformation" }
fn notify_display_messages()            -> Str { "NotifyDisplayMessages" }
fn notify_ev_charging_needs()           -> Str { "NotifyEVChargingNeeds" }
fn notify_ev_charging_schedule()        -> Str { "NotifyEVChargingSchedule" }
fn notify_event()                       -> Str { "NotifyEvent" }
fn notify_monitoring_report()           -> Str { "NotifyMonitoringReport" }
fn notify_report()                      -> Str { "NotifyReport" }
fn publish_firmware_status_notification() -> Str { "PublishFirmwareStatusNotification" }
fn report_charging_profiles()           -> Str { "ReportChargingProfiles" }
fn reservation_status_update()          -> Str { "ReservationStatusUpdate" }
fn security_event_notification()        -> Str { "SecurityEventNotification" }
fn sign_certificate()                   -> Str { "SignCertificate" }
fn status_notification()                -> Str { "StatusNotification" }
fn transaction_event()                  -> Str { "TransactionEvent" }

# 2.1 additions (CP → CSMS)
fn battery_swap()                       -> Str { "BatterySwap" }
fn notify_allowed_energy_transfer()     -> Str { "NotifyAllowedEnergyTransfer" }
fn notify_periodic_event_stream()       -> Str { "NotifyPeriodicEventStream" }
fn notify_settlement()                  -> Str { "NotifySettlement" }
fn notify_web_payment_started()         -> Str { "NotifyWebPaymentStarted" }
fn notify_der_alarm()                   -> Str { "NotifyDERAlarm" }
fn notify_der_start_stop()              -> Str { "NotifyDERStartStop" }
fn report_der_control()                 -> Str { "ReportDERControl" }
fn pull_dynamic_schedule_update()       -> Str { "PullDynamicScheduleUpdate" }
fn request_battery_swap()               -> Str { "RequestBatterySwap" }

# ============================================================
# CSMS → Charging Station (inherits 2.0.1 + adds 2.1)
# ============================================================

fn cancel_reservation()                 -> Str { "CancelReservation" }
fn certificate_signed()                 -> Str { "CertificateSigned" }
fn change_availability()                -> Str { "ChangeAvailability" }
fn clear_cache()                        -> Str { "ClearCache" }
fn clear_charging_profile()             -> Str { "ClearChargingProfile" }
fn clear_display_message()              -> Str { "ClearDisplayMessage" }
fn clear_variable_monitoring()          -> Str { "ClearVariableMonitoring" }
fn cost_updated()                       -> Str { "CostUpdated" }
fn customer_information()               -> Str { "CustomerInformation" }
fn delete_certificate()                 -> Str { "DeleteCertificate" }
fn get_base_report()                    -> Str { "GetBaseReport" }
fn get_charging_profiles()              -> Str { "GetChargingProfiles" }
fn get_composite_schedule()             -> Str { "GetCompositeSchedule" }
fn get_display_messages()               -> Str { "GetDisplayMessages" }
fn get_installed_certificate_ids()      -> Str { "GetInstalledCertificateIds" }
fn get_local_list_version()             -> Str { "GetLocalListVersion" }
fn get_log()                            -> Str { "GetLog" }
fn get_monitoring_report()              -> Str { "GetMonitoringReport" }
fn get_report()                         -> Str { "GetReport" }
fn get_transaction_status()             -> Str { "GetTransactionStatus" }
fn get_variables()                      -> Str { "GetVariables" }
fn install_certificate()                -> Str { "InstallCertificate" }
fn publish_firmware()                   -> Str { "PublishFirmware" }
fn request_start_transaction()          -> Str { "RequestStartTransaction" }
fn request_stop_transaction()           -> Str { "RequestStopTransaction" }
fn reserve_now()                        -> Str { "ReserveNow" }
fn reset()                              -> Str { "Reset" }
fn send_local_list()                    -> Str { "SendLocalList" }
fn set_charging_profile()               -> Str { "SetChargingProfile" }
fn set_display_message()                -> Str { "SetDisplayMessage" }
fn set_monitoring_base()                -> Str { "SetMonitoringBase" }
fn set_monitoring_level()               -> Str { "SetMonitoringLevel" }
fn set_network_profile()                -> Str { "SetNetworkProfile" }
fn set_variable_monitoring()            -> Str { "SetVariableMonitoring" }
fn set_variables()                      -> Str { "SetVariables" }
fn trigger_message()                    -> Str { "TriggerMessage" }
fn unlock_connector()                   -> Str { "UnlockConnector" }
fn unpublish_firmware()                 -> Str { "UnpublishFirmware" }
fn update_firmware()                    -> Str { "UpdateFirmware" }

# 2.1 additions (CSMS → CP)
fn adjust_periodic_event_stream()       -> Str { "AdjustPeriodicEventStream" }
fn open_periodic_event_stream()         -> Str { "OpenPeriodicEventStream" }
fn close_periodic_event_stream()        -> Str { "ClosePeriodicEventStream" }
fn get_periodic_event_stream()          -> Str { "GetPeriodicEventStream" }
fn get_der_control()                    -> Str { "GetDERControl" }
fn set_der_control()                    -> Str { "SetDERControl" }
fn clear_der_control()                  -> Str { "ClearDERControl" }
fn change_transaction_tariff()          -> Str { "ChangeTransactionTariff" }
fn get_tariffs()                        -> Str { "GetTariffs" }
fn clear_tariffs()                      -> Str { "ClearTariffs" }
fn set_default_tariff()                 -> Str { "SetDefaultTariff" }
fn update_dynamic_schedule()            -> Str { "UpdateDynamicSchedule" }
fn use_priority_charging()              -> Str { "UsePriorityCharging" }
fn vault()                              -> Str { "Vault" }

# ============================================================
# Bulk catalogs
# ============================================================

fn cs_to_csms() -> List[Str] {
  [
    # ---- shared with 2.0.1 ----
    authorize(), boot_notification(), cleared_charging_limit(),
    data_transfer(), firmware_status_notification(),
    get_15118ev_certificate(), get_certificate_status(),
    heartbeat(), log_status_notification(), meter_values(),
    notify_charging_limit(), notify_customer_information(),
    notify_display_messages(), notify_ev_charging_needs(),
    notify_ev_charging_schedule(), notify_event(),
    notify_monitoring_report(), notify_report(),
    publish_firmware_status_notification(),
    report_charging_profiles(), reservation_status_update(),
    security_event_notification(), sign_certificate(),
    status_notification(), transaction_event(),
    # ---- 2.1 additions ----
    battery_swap(), notify_allowed_energy_transfer(),
    notify_periodic_event_stream(), notify_settlement(),
    notify_web_payment_started(), notify_der_alarm(),
    notify_der_start_stop(), report_der_control(),
    pull_dynamic_schedule_update(), request_battery_swap(),
  ]
}

fn csms_to_cs() -> List[Str] {
  [
    # ---- shared with 2.0.1 ----
    cancel_reservation(), certificate_signed(), change_availability(),
    clear_cache(), clear_charging_profile(), clear_display_message(),
    clear_variable_monitoring(), cost_updated(), customer_information(),
    data_transfer(), delete_certificate(), get_base_report(),
    get_charging_profiles(), get_composite_schedule(),
    get_display_messages(), get_installed_certificate_ids(),
    get_local_list_version(), get_log(), get_monitoring_report(),
    get_report(), get_transaction_status(), get_variables(),
    install_certificate(), publish_firmware(),
    request_start_transaction(), request_stop_transaction(),
    reserve_now(), reset(), send_local_list(), set_charging_profile(),
    set_display_message(), set_monitoring_base(), set_monitoring_level(),
    set_network_profile(), set_variable_monitoring(), set_variables(),
    trigger_message(), unlock_connector(), unpublish_firmware(),
    update_firmware(),
    # ---- 2.1 additions ----
    adjust_periodic_event_stream(), open_periodic_event_stream(),
    close_periodic_event_stream(), get_periodic_event_stream(),
    get_der_control(), set_der_control(), clear_der_control(),
    change_transaction_tariff(), get_tariffs(), clear_tariffs(),
    set_default_tariff(), update_dynamic_schedule(),
    use_priority_charging(), vault(),
  ]
}
