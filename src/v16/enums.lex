# lex-ocpp — OCPP 1.6 enum string constants
#
# Each OCPP enum is exposed as:
#   - one `fn name() -> Str` per member (the exact wire string),
#   - one `fn all_<enum>() -> List[Str]` of every member, used by
#     lex-schema validators (`StrOneOf(all_xxx())`) to constrain
#     fields to the legal set.
#
# Variant ADTs would be more type-safe, but the OCPP spec lets
# vendors add private enum members (the "vendor extension" rule,
# §3.4), so a closed sum would force users to fork the library to
# add a custom status. Strings + an `all_*` validator give the
# same safety on the validation boundary while preserving
# extensibility.
#
# Enum coverage follows the OCPP 1.6 specification (Errata sheet
# 2019-12-13); a handful of less-used enums (ChargingProfileKind,
# RecurrencyKind, ChargingProfilePurpose) are included for
# SmartCharging conformance.

import "std.list" as list

# ---- AuthorizationStatus -----------------------------------------

fn auth_accepted()       -> Str { "Accepted" }
fn auth_blocked()        -> Str { "Blocked" }
fn auth_expired()        -> Str { "Expired" }
fn auth_invalid()        -> Str { "Invalid" }
fn auth_concurrent_tx()  -> Str { "ConcurrentTx" }

fn all_authorization_status() -> List[Str] {
  [auth_accepted(), auth_blocked(), auth_expired(),
   auth_invalid(), auth_concurrent_tx()]
}

# ---- RegistrationStatus ------------------------------------------

fn reg_accepted() -> Str { "Accepted" }
fn reg_pending()  -> Str { "Pending" }
fn reg_rejected() -> Str { "Rejected" }

fn all_registration_status() -> List[Str] {
  [reg_accepted(), reg_pending(), reg_rejected()]
}

# ---- ChargePointStatus (StatusNotification.status) ---------------

fn cp_available()       -> Str { "Available" }
fn cp_preparing()       -> Str { "Preparing" }
fn cp_charging()        -> Str { "Charging" }
fn cp_suspended_evse()  -> Str { "SuspendedEVSE" }
fn cp_suspended_ev()    -> Str { "SuspendedEV" }
fn cp_finishing()       -> Str { "Finishing" }
fn cp_reserved()        -> Str { "Reserved" }
fn cp_unavailable()     -> Str { "Unavailable" }
fn cp_faulted()         -> Str { "Faulted" }

fn all_charge_point_status() -> List[Str] {
  [cp_available(), cp_preparing(), cp_charging(),
   cp_suspended_evse(), cp_suspended_ev(), cp_finishing(),
   cp_reserved(), cp_unavailable(), cp_faulted()]
}

# ---- ChargePointErrorCode ----------------------------------------

fn ec_connector_lock_failure() -> Str { "ConnectorLockFailure" }
fn ec_ev_communication_error() -> Str { "EVCommunicationError" }
fn ec_ground_failure()         -> Str { "GroundFailure" }
fn ec_high_temperature()       -> Str { "HighTemperature" }
fn ec_internal_error()         -> Str { "InternalError" }
fn ec_local_list_conflict()    -> Str { "LocalListConflict" }
fn ec_no_error()               -> Str { "NoError" }
fn ec_other_error()            -> Str { "OtherError" }
fn ec_over_current_failure()   -> Str { "OverCurrentFailure" }
fn ec_over_voltage()           -> Str { "OverVoltage" }
fn ec_power_meter_failure()    -> Str { "PowerMeterFailure" }
fn ec_power_switch_failure()   -> Str { "PowerSwitchFailure" }
fn ec_reader_failure()         -> Str { "ReaderFailure" }
fn ec_reset_failure()          -> Str { "ResetFailure" }
fn ec_under_voltage()          -> Str { "UnderVoltage" }
fn ec_weak_signal()            -> Str { "WeakSignal" }

fn all_charge_point_error_code() -> List[Str] {
  [ec_connector_lock_failure(), ec_ev_communication_error(),
   ec_ground_failure(), ec_high_temperature(), ec_internal_error(),
   ec_local_list_conflict(), ec_no_error(), ec_other_error(),
   ec_over_current_failure(), ec_over_voltage(),
   ec_power_meter_failure(), ec_power_switch_failure(),
   ec_reader_failure(), ec_reset_failure(),
   ec_under_voltage(), ec_weak_signal()]
}

# ---- Reset (request) ---------------------------------------------

fn reset_hard() -> Str { "Hard" }
fn reset_soft() -> Str { "Soft" }

fn all_reset_type() -> List[Str] { [reset_hard(), reset_soft()] }

# ---- ResetStatus / GenericStatus ---------------------------------
#
# Many response enums in OCPP 1.6 are just Accepted/Rejected. We
# expose them as a shared `all_accepted_rejected` plus per-action
# aliases so callers can use the semantically right name.

fn accepted() -> Str { "Accepted" }
fn rejected() -> Str { "Rejected" }

fn all_accepted_rejected() -> List[Str] { [accepted(), rejected()] }

# ---- AvailabilityType (ChangeAvailability.type) ------------------

fn avail_inoperative() -> Str { "Inoperative" }
fn avail_operative()   -> Str { "Operative" }

fn all_availability_type() -> List[Str] {
  [avail_inoperative(), avail_operative()]
}

# ---- AvailabilityStatus -----------------------------------------

fn avail_status_accepted()   -> Str { "Accepted" }
fn avail_status_rejected()   -> Str { "Rejected" }
fn avail_status_scheduled()  -> Str { "Scheduled" }

fn all_availability_status() -> List[Str] {
  [avail_status_accepted(), avail_status_rejected(), avail_status_scheduled()]
}

# ---- ConfigurationStatus (ChangeConfiguration.status) ------------

fn cfg_accepted()         -> Str { "Accepted" }
fn cfg_rejected()         -> Str { "Rejected" }
fn cfg_reboot_required()  -> Str { "RebootRequired" }
fn cfg_not_supported()    -> Str { "NotSupported" }

fn all_configuration_status() -> List[Str] {
  [cfg_accepted(), cfg_rejected(), cfg_reboot_required(), cfg_not_supported()]
}

# ---- UnlockStatus ------------------------------------------------

fn unlock_unlocked()      -> Str { "Unlocked" }
fn unlock_unlock_failed() -> Str { "UnlockFailed" }
fn unlock_not_supported() -> Str { "NotSupported" }

fn all_unlock_status() -> List[Str] {
  [unlock_unlocked(), unlock_unlock_failed(), unlock_not_supported()]
}

# ---- DataTransferStatus ------------------------------------------

fn dt_accepted()             -> Str { "Accepted" }
fn dt_rejected()             -> Str { "Rejected" }
fn dt_unknown_message_id()   -> Str { "UnknownMessageId" }
fn dt_unknown_vendor_id()    -> Str { "UnknownVendorId" }

fn all_data_transfer_status() -> List[Str] {
  [dt_accepted(), dt_rejected(), dt_unknown_message_id(), dt_unknown_vendor_id()]
}

# ---- RemoteStartStopStatus --------------------------------------

fn remote_accepted() -> Str { "Accepted" }
fn remote_rejected() -> Str { "Rejected" }

fn all_remote_start_stop_status() -> List[Str] {
  [remote_accepted(), remote_rejected()]
}

# ---- TriggerMessageStatus ---------------------------------------

fn trg_accepted()       -> Str { "Accepted" }
fn trg_rejected()       -> Str { "Rejected" }
fn trg_not_implemented() -> Str { "NotImplemented" }

fn all_trigger_message_status() -> List[Str] {
  [trg_accepted(), trg_rejected(), trg_not_implemented()]
}

# ---- MessageTrigger (TriggerMessage.requestedMessage) ------------

fn mt_boot_notification()             -> Str { "BootNotification" }
fn mt_diagnostics_status_notification() -> Str { "DiagnosticsStatusNotification" }
fn mt_firmware_status_notification()  -> Str { "FirmwareStatusNotification" }
fn mt_heartbeat()                     -> Str { "Heartbeat" }
fn mt_meter_values()                  -> Str { "MeterValues" }
fn mt_status_notification()           -> Str { "StatusNotification" }

fn all_message_trigger() -> List[Str] {
  [mt_boot_notification(), mt_diagnostics_status_notification(),
   mt_firmware_status_notification(), mt_heartbeat(),
   mt_meter_values(), mt_status_notification()]
}

# ---- Reason (StopTransaction.reason) -----------------------------

fn reason_de_authorized()    -> Str { "DeAuthorized" }
fn reason_emergency_stop()   -> Str { "EmergencyStop" }
fn reason_ev_disconnected()  -> Str { "EVDisconnected" }
fn reason_hard_reset()       -> Str { "HardReset" }
fn reason_local()            -> Str { "Local" }
fn reason_other()            -> Str { "Other" }
fn reason_power_loss()       -> Str { "PowerLoss" }
fn reason_reboot()           -> Str { "Reboot" }
fn reason_remote()           -> Str { "Remote" }
fn reason_soft_reset()       -> Str { "SoftReset" }
fn reason_unlock_command()   -> Str { "UnlockCommand" }

fn all_stop_reason() -> List[Str] {
  [reason_de_authorized(), reason_emergency_stop(), reason_ev_disconnected(),
   reason_hard_reset(), reason_local(), reason_other(),
   reason_power_loss(), reason_reboot(), reason_remote(),
   reason_soft_reset(), reason_unlock_command()]
}

# ---- ReadingContext (MeterValues.SampledValue.context) -----------

fn rc_interruption_begin()  -> Str { "Interruption.Begin" }
fn rc_interruption_end()    -> Str { "Interruption.End" }
fn rc_other()               -> Str { "Other" }
fn rc_sample_clock()        -> Str { "Sample.Clock" }
fn rc_sample_periodic()     -> Str { "Sample.Periodic" }
fn rc_transaction_begin()   -> Str { "Transaction.Begin" }
fn rc_transaction_end()     -> Str { "Transaction.End" }
fn rc_trigger()             -> Str { "Trigger" }

fn all_reading_context() -> List[Str] {
  [rc_interruption_begin(), rc_interruption_end(), rc_other(),
   rc_sample_clock(), rc_sample_periodic(),
   rc_transaction_begin(), rc_transaction_end(), rc_trigger()]
}

# ---- ValueFormat ------------------------------------------------

fn vf_raw()         -> Str { "Raw" }
fn vf_signed_data() -> Str { "SignedData" }

fn all_value_format() -> List[Str] { [vf_raw(), vf_signed_data()] }

# ---- Measurand --------------------------------------------------

fn ms_current_export()                  -> Str { "Current.Export" }
fn ms_current_import()                  -> Str { "Current.Import" }
fn ms_current_offered()                 -> Str { "Current.Offered" }
fn ms_energy_active_export_register()   -> Str { "Energy.Active.Export.Register" }
fn ms_energy_active_import_register()   -> Str { "Energy.Active.Import.Register" }
fn ms_energy_reactive_export_register() -> Str { "Energy.Reactive.Export.Register" }
fn ms_energy_reactive_import_register() -> Str { "Energy.Reactive.Import.Register" }
fn ms_energy_active_export_interval()   -> Str { "Energy.Active.Export.Interval" }
fn ms_energy_active_import_interval()   -> Str { "Energy.Active.Import.Interval" }
fn ms_energy_reactive_export_interval() -> Str { "Energy.Reactive.Export.Interval" }
fn ms_energy_reactive_import_interval() -> Str { "Energy.Reactive.Import.Interval" }
fn ms_frequency()                       -> Str { "Frequency" }
fn ms_power_active_export()             -> Str { "Power.Active.Export" }
fn ms_power_active_import()             -> Str { "Power.Active.Import" }
fn ms_power_factor()                    -> Str { "Power.Factor" }
fn ms_power_offered()                   -> Str { "Power.Offered" }
fn ms_power_reactive_export()           -> Str { "Power.Reactive.Export" }
fn ms_power_reactive_import()           -> Str { "Power.Reactive.Import" }
fn ms_rpm()                             -> Str { "RPM" }
fn ms_soc()                             -> Str { "SoC" }
fn ms_temperature()                     -> Str { "Temperature" }
fn ms_voltage()                         -> Str { "Voltage" }

fn all_measurand() -> List[Str] {
  [ms_current_export(), ms_current_import(), ms_current_offered(),
   ms_energy_active_export_register(), ms_energy_active_import_register(),
   ms_energy_reactive_export_register(), ms_energy_reactive_import_register(),
   ms_energy_active_export_interval(), ms_energy_active_import_interval(),
   ms_energy_reactive_export_interval(), ms_energy_reactive_import_interval(),
   ms_frequency(), ms_power_active_export(), ms_power_active_import(),
   ms_power_factor(), ms_power_offered(), ms_power_reactive_export(),
   ms_power_reactive_import(), ms_rpm(), ms_soc(),
   ms_temperature(), ms_voltage()]
}

# ---- Phase ------------------------------------------------------

fn phase_l1()    -> Str { "L1" }
fn phase_l2()    -> Str { "L2" }
fn phase_l3()    -> Str { "L3" }
fn phase_n()     -> Str { "N" }
fn phase_l1_n()  -> Str { "L1-N" }
fn phase_l2_n()  -> Str { "L2-N" }
fn phase_l3_n()  -> Str { "L3-N" }
fn phase_l1_l2() -> Str { "L1-L2" }
fn phase_l2_l3() -> Str { "L2-L3" }
fn phase_l3_l1() -> Str { "L3-L1" }

fn all_phase() -> List[Str] {
  [phase_l1(), phase_l2(), phase_l3(), phase_n(),
   phase_l1_n(), phase_l2_n(), phase_l3_n(),
   phase_l1_l2(), phase_l2_l3(), phase_l3_l1()]
}

# ---- Location ---------------------------------------------------

fn loc_body()   -> Str { "Body" }
fn loc_cable()  -> Str { "Cable" }
fn loc_ev()     -> Str { "EV" }
fn loc_inlet()  -> Str { "Inlet" }
fn loc_outlet() -> Str { "Outlet" }

fn all_location() -> List[Str] {
  [loc_body(), loc_cable(), loc_ev(), loc_inlet(), loc_outlet()]
}

# ---- UnitOfMeasure ----------------------------------------------

fn uom_wh()         -> Str { "Wh" }
fn uom_kwh()        -> Str { "kWh" }
fn uom_varh()       -> Str { "varh" }
fn uom_kvarh()      -> Str { "kvarh" }
fn uom_w()          -> Str { "W" }
fn uom_kw()         -> Str { "kW" }
fn uom_va()         -> Str { "VA" }
fn uom_kva()        -> Str { "kVA" }
fn uom_var()        -> Str { "var" }
fn uom_kvar()       -> Str { "kvar" }
fn uom_a()          -> Str { "A" }
fn uom_v()          -> Str { "V" }
fn uom_kelvin()     -> Str { "K" }
fn uom_celsius()    -> Str { "Celsius" }
fn uom_fahrenheit() -> Str { "Fahrenheit" }
fn uom_percent()    -> Str { "Percent" }

fn all_unit_of_measure() -> List[Str] {
  [uom_wh(), uom_kwh(), uom_varh(), uom_kvarh(),
   uom_w(), uom_kw(), uom_va(), uom_kva(),
   uom_var(), uom_kvar(), uom_a(), uom_v(),
   uom_kelvin(), uom_celsius(), uom_fahrenheit(), uom_percent()]
}

# ---- FirmwareStatus (FirmwareStatusNotification) ----------------

fn fw_downloaded()            -> Str { "Downloaded" }
fn fw_download_failed()       -> Str { "DownloadFailed" }
fn fw_downloading()           -> Str { "Downloading" }
fn fw_idle()                  -> Str { "Idle" }
fn fw_installation_failed()   -> Str { "InstallationFailed" }
fn fw_installing()            -> Str { "Installing" }
fn fw_installed()             -> Str { "Installed" }

fn all_firmware_status() -> List[Str] {
  [fw_downloaded(), fw_download_failed(), fw_downloading(),
   fw_idle(), fw_installation_failed(), fw_installing(), fw_installed()]
}

# ---- DiagnosticsStatus -------------------------------------------

fn diag_idle()         -> Str { "Idle" }
fn diag_uploaded()     -> Str { "Uploaded" }
fn diag_upload_failed() -> Str { "UploadFailed" }
fn diag_uploading()    -> Str { "Uploading" }

fn all_diagnostics_status() -> List[Str] {
  [diag_idle(), diag_uploaded(), diag_upload_failed(), diag_uploading()]
}

# ---- ChargingProfileKind / Purpose / RecurrencyKind --------------

fn cpk_absolute()  -> Str { "Absolute" }
fn cpk_recurring() -> Str { "Recurring" }
fn cpk_relative()  -> Str { "Relative" }

fn all_charging_profile_kind() -> List[Str] {
  [cpk_absolute(), cpk_recurring(), cpk_relative()]
}

fn cpp_charge_point_max_profile() -> Str { "ChargePointMaxProfile" }
fn cpp_tx_default_profile()       -> Str { "TxDefaultProfile" }
fn cpp_tx_profile()               -> Str { "TxProfile" }

fn all_charging_profile_purpose() -> List[Str] {
  [cpp_charge_point_max_profile(), cpp_tx_default_profile(), cpp_tx_profile()]
}

fn rck_daily()  -> Str { "Daily" }
fn rck_weekly() -> Str { "Weekly" }

fn all_recurrency_kind() -> List[Str] { [rck_daily(), rck_weekly()] }

# ---- ChargingRateUnit -------------------------------------------

fn cru_a() -> Str { "A" }
fn cru_w() -> Str { "W" }

fn all_charging_rate_unit() -> List[Str] { [cru_a(), cru_w()] }

# ---- UpdateStatus (SendLocalList) -------------------------------

fn upd_accepted()       -> Str { "Accepted" }
fn upd_failed()         -> Str { "Failed" }
fn upd_not_supported()  -> Str { "NotSupported" }
fn upd_version_mismatch() -> Str { "VersionMismatch" }

fn all_update_status() -> List[Str] {
  [upd_accepted(), upd_failed(), upd_not_supported(), upd_version_mismatch()]
}

# ---- UpdateType (SendLocalList.updateType) ----------------------

fn upd_t_differential() -> Str { "Differential" }
fn upd_t_full()         -> Str { "Full" }

fn all_update_type() -> List[Str] { [upd_t_differential(), upd_t_full()] }

# ---- CancelReservationStatus ------------------------------------

fn cancel_accepted() -> Str { "Accepted" }
fn cancel_rejected() -> Str { "Rejected" }

fn all_cancel_reservation_status() -> List[Str] {
  [cancel_accepted(), cancel_rejected()]
}

# ---- ReservationStatus ------------------------------------------

fn rsv_accepted()    -> Str { "Accepted" }
fn rsv_faulted()     -> Str { "Faulted" }
fn rsv_occupied()    -> Str { "Occupied" }
fn rsv_rejected()    -> Str { "Rejected" }
fn rsv_unavailable() -> Str { "Unavailable" }

fn all_reservation_status() -> List[Str] {
  [rsv_accepted(), rsv_faulted(), rsv_occupied(),
   rsv_rejected(), rsv_unavailable()]
}

# ---- ClearChargingProfileStatus ---------------------------------

fn ccp_accepted() -> Str { "Accepted" }
fn ccp_unknown()  -> Str { "Unknown" }

fn all_clear_charging_profile_status() -> List[Str] {
  [ccp_accepted(), ccp_unknown()]
}

# ---- ChargingProfileStatus (SetChargingProfile) -----------------

fn cps_accepted()      -> Str { "Accepted" }
fn cps_rejected()      -> Str { "Rejected" }
fn cps_not_supported() -> Str { "NotSupported" }

fn all_charging_profile_status() -> List[Str] {
  [cps_accepted(), cps_rejected(), cps_not_supported()]
}
