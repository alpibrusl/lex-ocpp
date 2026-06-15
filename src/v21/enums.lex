# lex-ocpp — OCPP 2.1 enum string constants
#
# OCPP 2.1 inherits the v2.0.1 enum surface and adds new enums to
# cover the new features (DER control, periodic event streams,
# battery swap, tariffs, ISO 15118-20 bidirectional).
#
# For enums that are unchanged from 2.0.1, downstream code can
# either import this module (re-declared here for locality) or
# import `lex-ocpp/v201/enums` directly. We re-declare the most
# commonly used enums to keep `import "lex-ocpp/v21/enums"`
# self-sufficient.

import "std.list" as list

# ============================================================
# Re-used from 2.0.1 (re-declared locally for one-import use)
# ============================================================
# ---- RegistrationStatus -----------------------------------------
fn reg_accepted() -> Str {
  "Accepted"
}

fn reg_pending() -> Str {
  "Pending"
}

fn reg_rejected() -> Str {
  "Rejected"
}

fn all_registration_status() -> List[Str] {
  [reg_accepted(), reg_pending(), reg_rejected()]
}

# ---- BootReasonEnumType ------------------------------------------
fn br_application_reset() -> Str {
  "ApplicationReset"
}

fn br_firmware_update() -> Str {
  "FirmwareUpdate"
}

fn br_local_reset() -> Str {
  "LocalReset"
}

fn br_power_up() -> Str {
  "PowerUp"
}

fn br_remote_reset() -> Str {
  "RemoteReset"
}

fn br_scheduled_reset() -> Str {
  "ScheduledReset"
}

fn br_triggered() -> Str {
  "Triggered"
}

fn br_unknown() -> Str {
  "Unknown"
}

fn br_watchdog() -> Str {
  "Watchdog"
}

fn all_boot_reason() -> List[Str] {
  [br_application_reset(), br_firmware_update(), br_local_reset(), br_power_up(), br_remote_reset(), br_scheduled_reset(), br_triggered(), br_unknown(), br_watchdog()]
}

# ---- AuthorizationStatus ----------------------------------------
fn auth_accepted() -> Str {
  "Accepted"
}

fn auth_blocked() -> Str {
  "Blocked"
}

fn auth_concurrent_tx() -> Str {
  "ConcurrentTx"
}

fn auth_expired() -> Str {
  "Expired"
}

fn auth_invalid() -> Str {
  "Invalid"
}

fn auth_no_credit() -> Str {
  "NoCredit"
}

fn auth_not_allowed_type_evse() -> Str {
  "NotAllowedTypeEVSE"
}

fn auth_not_at_this_location() -> Str {
  "NotAtThisLocation"
}

fn auth_not_at_this_time() -> Str {
  "NotAtThisTime"
}

fn auth_unknown() -> Str {
  "Unknown"
}

fn all_authorization_status() -> List[Str] {
  [auth_accepted(), auth_blocked(), auth_concurrent_tx(), auth_expired(), auth_invalid(), auth_no_credit(), auth_not_allowed_type_evse(), auth_not_at_this_location(), auth_not_at_this_time(), auth_unknown()]
}

# ---- IdTokenEnumType (2.1 adds eMAID-PnC and VIN variants) ------
fn id_central() -> Str {
  "Central"
}

fn id_e_maid() -> Str {
  "eMAID"
}

fn id_iso14443() -> Str {
  "ISO14443"
}

fn id_iso15693() -> Str {
  "ISO15693"
}

fn id_key_code() -> Str {
  "KeyCode"
}

fn id_local() -> Str {
  "Local"
}

fn id_mac_address() -> Str {
  "MacAddress"
}

fn id_no_authorization() -> Str {
  "NoAuthorization"
}

# 2.1 additions
fn id_vin() -> Str {
  "VIN"
}

fn id_iso15118v20() -> Str {
  "ISO15118v20"
}

fn all_id_token_type() -> List[Str] {
  [id_central(), id_e_maid(), id_iso14443(), id_iso15693(), id_key_code(), id_local(), id_mac_address(), id_no_authorization(), id_vin(), id_iso15118v20()]
}

# ---- ConnectorStatus --------------------------------------------
fn cs_available() -> Str {
  "Available"
}

fn cs_occupied() -> Str {
  "Occupied"
}

fn cs_reserved() -> Str {
  "Reserved"
}

fn cs_unavailable() -> Str {
  "Unavailable"
}

fn cs_faulted() -> Str {
  "Faulted"
}

fn all_connector_status() -> List[Str] {
  [cs_available(), cs_occupied(), cs_reserved(), cs_unavailable(), cs_faulted()]
}

# ---- TransactionEvent + ChargingState ---------------------------
fn te_ended() -> Str {
  "Ended"
}

fn te_started() -> Str {
  "Started"
}

fn te_updated() -> Str {
  "Updated"
}

fn all_transaction_event() -> List[Str] {
  [te_ended(), te_started(), te_updated()]
}

fn ch_charging() -> Str {
  "Charging"
}

fn ch_ev_connected() -> Str {
  "EVConnected"
}

fn ch_suspended_ev() -> Str {
  "SuspendedEV"
}

fn ch_suspended_evse() -> Str {
  "SuspendedEVSE"
}

fn ch_idle() -> Str {
  "Idle"
}

# 2.1 additions for bidirectional flow
fn ch_discharging() -> Str {
  "Discharging"
}

fn all_charging_state() -> List[Str] {
  [ch_charging(), ch_ev_connected(), ch_suspended_ev(), ch_suspended_evse(), ch_idle(), ch_discharging()]
}

# ---- Reset / ResetStatus ----------------------------------------
fn reset_immediate() -> Str {
  "Immediate"
}

fn reset_on_idle() -> Str {
  "OnIdle"
}

fn all_reset_type() -> List[Str] {
  [reset_immediate(), reset_on_idle()]
}

fn reset_status_accepted() -> Str {
  "Accepted"
}

fn reset_status_rejected() -> Str {
  "Rejected"
}

fn reset_status_scheduled() -> Str {
  "Scheduled"
}

fn all_reset_status() -> List[Str] {
  [reset_status_accepted(), reset_status_rejected(), reset_status_scheduled()]
}

# ---- GenericStatus ----------------------------------------------
fn gen_accepted() -> Str {
  "Accepted"
}

fn gen_rejected() -> Str {
  "Rejected"
}

fn all_generic_status() -> List[Str] {
  [gen_accepted(), gen_rejected()]
}

# ---- DataTransferStatus -----------------------------------------
fn dt_accepted() -> Str {
  "Accepted"
}

fn dt_rejected() -> Str {
  "Rejected"
}

fn dt_unknown_message_id() -> Str {
  "UnknownMessageId"
}

fn dt_unknown_vendor_id() -> Str {
  "UnknownVendorId"
}

fn all_data_transfer_status() -> List[Str] {
  [dt_accepted(), dt_rejected(), dt_unknown_message_id(), dt_unknown_vendor_id()]
}

# ============================================================
# 2.1-specific enums
# ============================================================
# ---- EnergyTransferModeEnumType (V2G / bidirectional) ----------
fn etm_ac_single_phase() -> Str {
  "AC_single_phase"
}

fn etm_ac_two_phase() -> Str {
  "AC_two_phase"
}

fn etm_ac_three_phase() -> Str {
  "AC_three_phase"
}

fn etm_dc() -> Str {
  "DC"
}

fn etm_ac_bpt() -> Str {
  "AC_BPT"
}

fn etm_ac_bpt_ds() -> Str {
  "AC_BPT_DS"
}

fn etm_ac_ds() -> Str {
  "AC_DS"
}

fn etm_dc_bpt() -> Str {
  "DC_BPT"
}

fn etm_dc_acdp() -> Str {
  "DC_ACDP"
}

fn etm_dc_acdp_bpt() -> Str {
  "DC_ACDP_BPT"
}

fn etm_wpt() -> Str {
  "WPT"
}

fn all_energy_transfer_mode() -> List[Str] {
  [etm_ac_single_phase(), etm_ac_two_phase(), etm_ac_three_phase(), etm_dc(), etm_ac_bpt(), etm_ac_bpt_ds(), etm_ac_ds(), etm_dc_bpt(), etm_dc_acdp(), etm_dc_acdp_bpt(), etm_wpt()]
}

# ---- BatterySwapEventEnumType -----------------------------------
fn bs_battery_in() -> Str {
  "BatteryIn"
}

fn bs_battery_out() -> Str {
  "BatteryOut"
}

fn bs_battery_out_timeout() -> Str {
  "BatteryOutTimeout"
}

fn all_battery_swap_event() -> List[Str] {
  [bs_battery_in(), bs_battery_out(), bs_battery_out_timeout()]
}

# ---- DERControlEnumType (smart-grid / DER) ---------------------
fn der_enter_service() -> Str {
  "EnterService"
}

fn der_freq_droop() -> Str {
  "FreqDroop"
}

fn der_freq_watt() -> Str {
  "FreqWatt"
}

fn der_fixed_pf_absorb() -> Str {
  "FixedPFAbsorb"
}

fn der_fixed_pf_inject() -> Str {
  "FixedPFInject"
}

fn der_fixed_var() -> Str {
  "FixedVar"
}

fn der_gradients() -> Str {
  "Gradients"
}

fn der_hf_must_trip() -> Str {
  "HFMustTrip"
}

fn der_hf_may_trip() -> Str {
  "HFMayTrip"
}

fn der_hv_must_trip() -> Str {
  "HVMustTrip"
}

fn der_hv_momentary_cessation() -> Str {
  "HVMomentaryCessation"
}

fn der_lf_must_trip() -> Str {
  "LFMustTrip"
}

fn der_lv_must_trip() -> Str {
  "LVMustTrip"
}

fn der_lv_momentary_cessation() -> Str {
  "LVMomentaryCessation"
}

fn der_power_monitoring_must_trip() -> Str {
  "PowerMonitoringMustTrip"
}

fn der_volt_var() -> Str {
  "VoltVar"
}

fn der_volt_watt() -> Str {
  "VoltWatt"
}

fn der_watt_pf() -> Str {
  "WattPF"
}

fn der_watt_var() -> Str {
  "WattVar"
}

fn all_der_control_type() -> List[Str] {
  [der_enter_service(), der_freq_droop(), der_freq_watt(), der_fixed_pf_absorb(), der_fixed_pf_inject(), der_fixed_var(), der_gradients(), der_hf_must_trip(), der_hf_may_trip(), der_hv_must_trip(), der_hv_momentary_cessation(), der_lf_must_trip(), der_lv_must_trip(), der_lv_momentary_cessation(), der_power_monitoring_must_trip(), der_volt_var(), der_volt_watt(), der_watt_pf(), der_watt_var()]
}

# ---- DERControlStatusEnumType -----------------------------------
fn der_status_accepted() -> Str {
  "Accepted"
}

fn der_status_rejected() -> Str {
  "Rejected"
}

fn der_status_not_supported() -> Str {
  "NotSupported"
}

fn der_status_not_found() -> Str {
  "NotFound"
}

fn all_der_control_status() -> List[Str] {
  [der_status_accepted(), der_status_rejected(), der_status_not_supported(), der_status_not_found()]
}

# ---- PeriodicEventStreamParams ----------------------------------
fn pes_status_accepted() -> Str {
  "Accepted"
}

fn pes_status_rejected() -> Str {
  "Rejected"
}

fn pes_status_invalid_stream_id() -> Str {
  "InvalidStreamId"
}

fn all_pes_status() -> List[Str] {
  [pes_status_accepted(), pes_status_rejected(), pes_status_invalid_stream_id()]
}

# ---- TariffChangeStatusEnumType ---------------------------------
fn tc_accepted() -> Str {
  "Accepted"
}

fn tc_rejected() -> Str {
  "Rejected"
}

fn tc_invalid_id() -> Str {
  "InvalidId"
}

fn tc_tx_not_found() -> Str {
  "TxNotFound"
}

fn tc_no_currency_change() -> Str {
  "NoCurrencyChange"
}

fn tc_too_many_elements() -> Str {
  "TooManyElements"
}

fn all_tariff_change_status() -> List[Str] {
  [tc_accepted(), tc_rejected(), tc_invalid_id(), tc_tx_not_found(), tc_no_currency_change(), tc_too_many_elements()]
}

# ---- PriorityChargingStatusEnumType -----------------------------
fn pc_accepted() -> Str {
  "Accepted"
}

fn pc_rejected() -> Str {
  "Rejected"
}

fn pc_no_profile() -> Str {
  "NoProfile"
}

fn all_priority_charging_status() -> List[Str] {
  [pc_accepted(), pc_rejected(), pc_no_profile()]
}

