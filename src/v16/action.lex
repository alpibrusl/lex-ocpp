# lex-ocpp — OCPP 1.6 action catalog
#
# Every action name OCPP 1.6J defines, as a wire-exact string
# constant. Use these constants when registering handlers or
# constructing outbound Calls; never hand-write the string at the
# call site (typos surface as `NotImplemented` errors at runtime
# rather than typecheck failures).
#
# Two halves:
#   CP→CS (Charge Point initiates, Central System responds)
#   CS→CP (Central System initiates, Charge Point responds)

# ---- Charge Point → Central System -------------------------------

fn authorize()                       -> Str { "Authorize" }
fn boot_notification()               -> Str { "BootNotification" }
fn data_transfer()                   -> Str { "DataTransfer" }
fn diagnostics_status_notification() -> Str { "DiagnosticsStatusNotification" }
fn firmware_status_notification()    -> Str { "FirmwareStatusNotification" }
fn heartbeat()                       -> Str { "Heartbeat" }
fn meter_values()                    -> Str { "MeterValues" }
fn start_transaction()               -> Str { "StartTransaction" }
fn status_notification()             -> Str { "StatusNotification" }
fn stop_transaction()                -> Str { "StopTransaction" }

# ---- Central System → Charge Point -------------------------------

fn cancel_reservation()              -> Str { "CancelReservation" }
fn change_availability()             -> Str { "ChangeAvailability" }
fn change_configuration()            -> Str { "ChangeConfiguration" }
fn clear_cache()                     -> Str { "ClearCache" }
fn clear_charging_profile()          -> Str { "ClearChargingProfile" }
fn get_composite_schedule()          -> Str { "GetCompositeSchedule" }
fn get_configuration()               -> Str { "GetConfiguration" }
fn get_diagnostics()                 -> Str { "GetDiagnostics" }
fn get_local_list_version()          -> Str { "GetLocalListVersion" }
fn remote_start_transaction()        -> Str { "RemoteStartTransaction" }
fn remote_stop_transaction()         -> Str { "RemoteStopTransaction" }
fn reserve_now()                     -> Str { "ReserveNow" }
fn reset()                           -> Str { "Reset" }
fn send_local_list()                 -> Str { "SendLocalList" }
fn set_charging_profile()            -> Str { "SetChargingProfile" }
fn trigger_message()                 -> Str { "TriggerMessage" }
fn unlock_connector()                -> Str { "UnlockConnector" }
fn update_firmware()                 -> Str { "UpdateFirmware" }

# ---- Bulk catalogs (useful for property tests / docs) ------------

fn cp_to_cs() -> List[Str] {
  [
    authorize(),
    boot_notification(),
    data_transfer(),
    diagnostics_status_notification(),
    firmware_status_notification(),
    heartbeat(),
    meter_values(),
    start_transaction(),
    status_notification(),
    stop_transaction(),
  ]
}

fn cs_to_cp() -> List[Str] {
  [
    cancel_reservation(),
    change_availability(),
    change_configuration(),
    clear_cache(),
    clear_charging_profile(),
    data_transfer(),
    get_composite_schedule(),
    get_configuration(),
    get_diagnostics(),
    get_local_list_version(),
    remote_start_transaction(),
    remote_stop_transaction(),
    reserve_now(),
    reset(),
    send_local_list(),
    set_charging_profile(),
    trigger_message(),
    unlock_connector(),
    update_firmware(),
  ]
}
