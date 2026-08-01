# lex-ocpp — OCPP 2.0.1 enum string constants
#
# Same pattern as v16/enums.lex: each enum has one `fn name() -> Str`
# per member plus a single `all_<enum>()` catalog. OCPP 2.0.1 expands
# the enum surface significantly (Part 2 §3) — this module covers
# the enums actually referenced by the schemas in `v201/schemas.lex`.
# Add more enums by following the same shape.

import "std.list" as list

# ---- RegistrationStatusEnumType ---------------------------------
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

# ---- AuthorizationStatusEnumType --------------------------------
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

# ---- IdTokenEnumType ---------------------------------------------
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

fn all_id_token_type() -> List[Str] {
  [id_central(), id_e_maid(), id_iso14443(), id_iso15693(), id_key_code(), id_local(), id_mac_address(), id_no_authorization()]
}

# ---- ConnectorStatusEnumType (StatusNotification.status) --------
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

# ---- TransactionEventEnumType -----------------------------------
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

# ---- TriggerReasonEnumType --------------------------------------
fn tr_authorized() -> Str {
  "Authorized"
}

fn tr_cable_plugged_in() -> Str {
  "CablePluggedIn"
}

fn tr_charging_rate_changed() -> Str {
  "ChargingRateChanged"
}

fn tr_charging_state_changed() -> Str {
  "ChargingStateChanged"
}

fn tr_deauthorized() -> Str {
  "Deauthorized"
}

fn tr_energy_limit_reached() -> Str {
  "EnergyLimitReached"
}

fn tr_ev_communication_lost() -> Str {
  "EVCommunicationLost"
}

fn tr_ev_connect_timeout() -> Str {
  "EVConnectTimeout"
}

fn tr_meter_value_clock() -> Str {
  "MeterValueClock"
}

fn tr_meter_value_periodic() -> Str {
  "MeterValuePeriodic"
}

fn tr_time_limit_reached() -> Str {
  "TimeLimitReached"
}

fn tr_trigger() -> Str {
  "Trigger"
}

fn tr_unlock_command() -> Str {
  "UnlockCommand"
}

fn tr_stop_authorized() -> Str {
  "StopAuthorized"
}

fn tr_ev_departed() -> Str {
  "EVDeparted"
}

fn tr_ev_detected() -> Str {
  "EVDetected"
}

fn tr_remote_stop() -> Str {
  "RemoteStop"
}

fn tr_remote_start() -> Str {
  "RemoteStart"
}

fn tr_abnormal_condition() -> Str {
  "AbnormalCondition"
}

fn tr_signed_data_received() -> Str {
  "SignedDataReceived"
}

fn tr_reset_command() -> Str {
  "ResetCommand"
}

fn all_trigger_reason() -> List[Str] {
  [tr_authorized(), tr_cable_plugged_in(), tr_charging_rate_changed(), tr_charging_state_changed(), tr_deauthorized(), tr_energy_limit_reached(), tr_ev_communication_lost(), tr_ev_connect_timeout(), tr_meter_value_clock(), tr_meter_value_periodic(), tr_time_limit_reached(), tr_trigger(), tr_unlock_command(), tr_stop_authorized(), tr_ev_departed(), tr_ev_detected(), tr_remote_stop(), tr_remote_start(), tr_abnormal_condition(), tr_signed_data_received(), tr_reset_command()]
}

# ---- ChargingStateEnumType --------------------------------------
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

fn all_charging_state() -> List[Str] {
  [ch_charging(), ch_ev_connected(), ch_suspended_ev(), ch_suspended_evse(), ch_idle()]
}

# ---- ResetEnumType ----------------------------------------------
fn reset_immediate() -> Str {
  "Immediate"
}

fn reset_on_idle() -> Str {
  "OnIdle"
}

fn all_reset_type() -> List[Str] {
  [reset_immediate(), reset_on_idle()]
}

# ---- ResetStatusEnumType ----------------------------------------
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

# ---- GenericStatusEnumType --------------------------------------
fn gen_accepted() -> Str {
  "Accepted"
}

fn gen_rejected() -> Str {
  "Rejected"
}

fn all_generic_status() -> List[Str] {
  [gen_accepted(), gen_rejected()]
}

# ---- DataTransferStatusEnumType ---------------------------------
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

# ---- MessageTriggerEnumType -------------------------------------
fn mt_boot_notification() -> Str {
  "BootNotification"
}

fn mt_log_status_notification() -> Str {
  "LogStatusNotification"
}

fn mt_firmware_status_notification() -> Str {
  "FirmwareStatusNotification"
}

fn mt_heartbeat() -> Str {
  "Heartbeat"
}

fn mt_meter_values() -> Str {
  "MeterValues"
}

fn mt_sign_charging_station_certificate() -> Str {
  "SignChargingStationCertificate"
}

fn mt_sign_v2g_certificate() -> Str {
  "SignV2GCertificate"
}

fn mt_status_notification() -> Str {
  "StatusNotification"
}

fn mt_transaction_event() -> Str {
  "TransactionEvent"
}

fn mt_sign_combined_certificate() -> Str {
  "SignCombinedCertificate"
}

fn mt_publish_firmware_status_notification() -> Str {
  "PublishFirmwareStatusNotification"
}

fn all_message_trigger() -> List[Str] {
  [mt_boot_notification(), mt_log_status_notification(), mt_firmware_status_notification(), mt_heartbeat(), mt_meter_values(), mt_sign_charging_station_certificate(), mt_sign_v2g_certificate(), mt_status_notification(), mt_transaction_event(), mt_sign_combined_certificate(), mt_publish_firmware_status_notification()]
}

# ---- FirmwareStatusEnumType -------------------------------------
fn fw_downloaded() -> Str {
  "Downloaded"
}

fn fw_download_failed() -> Str {
  "DownloadFailed"
}

fn fw_downloading() -> Str {
  "Downloading"
}

fn fw_download_scheduled() -> Str {
  "DownloadScheduled"
}

fn fw_download_paused() -> Str {
  "DownloadPaused"
}

fn fw_idle() -> Str {
  "Idle"
}

fn fw_installation_failed() -> Str {
  "InstallationFailed"
}

fn fw_installing() -> Str {
  "Installing"
}

fn fw_installed() -> Str {
  "Installed"
}

fn fw_install_reboot() -> Str {
  "InstallRebooting"
}

fn fw_install_scheduled() -> Str {
  "InstallScheduled"
}

fn fw_install_verif_failed() -> Str {
  "InstallVerificationFailed"
}

fn fw_invalid_signature() -> Str {
  "InvalidSignature"
}

fn fw_signature_verified() -> Str {
  "SignatureVerified"
}

fn all_firmware_status() -> List[Str] {
  [fw_downloaded(), fw_download_failed(), fw_downloading(), fw_download_scheduled(), fw_download_paused(), fw_idle(), fw_installation_failed(), fw_installing(), fw_installed(), fw_install_reboot(), fw_install_scheduled(), fw_install_verif_failed(), fw_invalid_signature(), fw_signature_verified()]
}

# ---- ChargingProfileKindEnumType ---------------------------------
fn cpk_absolute() -> Str {
  "Absolute"
}

fn cpk_recurring() -> Str {
  "Recurring"
}

fn cpk_relative() -> Str {
  "Relative"
}

fn all_charging_profile_kind() -> List[Str] {
  [cpk_absolute(), cpk_recurring(), cpk_relative()]
}

# ---- ChargingProfilePurposeEnumType ------------------------------
fn cpp_charging_station_external_constraints() -> Str {
  "ChargingStationExternalConstraints"
}

fn cpp_charging_station_max_profile() -> Str {
  "ChargingStationMaxProfile"
}

fn cpp_tx_default_profile() -> Str {
  "TxDefaultProfile"
}

fn cpp_tx_profile() -> Str {
  "TxProfile"
}

fn all_charging_profile_purpose() -> List[Str] {
  [cpp_charging_station_external_constraints(), cpp_charging_station_max_profile(), cpp_tx_default_profile(), cpp_tx_profile()]
}

# ---- RecurrencyKindEnumType ---------------------------------------
fn rck_daily() -> Str {
  "Daily"
}

fn rck_weekly() -> Str {
  "Weekly"
}

fn all_recurrency_kind() -> List[Str] {
  [rck_daily(), rck_weekly()]
}

# ---- ChargingRateUnitEnumType --------------------------------------
fn cru_a() -> Str {
  "A"
}

fn cru_w() -> Str {
  "W"
}

fn all_charging_rate_unit() -> List[Str] {
  [cru_a(), cru_w()]
}

