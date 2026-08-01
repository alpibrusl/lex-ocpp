# lex-ocpp — OCPP 2.1 schema validation tests

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/v21/schemas" as sch

import "../src/v21/enums" as en

# ---- Test scaffolding --------------------------------------------
fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_ok_validation(r :: Result[jv.Json, List[{ path :: Str, code :: Str, message :: Str }]], label :: Str) -> Result[Unit, Str] {
  match r {
    Ok(_) => pass(),
    Err(_) => fail(str.concat(label, ": expected Ok")),
  }
}

fn assert_err_validation(r :: Result[jv.Json, List[{ path :: Str, code :: Str, message :: Str }]], label :: Str) -> Result[Unit, Str] {
  match r {
    Ok(_) => fail(str.concat(label, ": expected Err")),
    Err(_) => pass(),
  }
}

# ============================================================
# Carry-overs (with v2.1 enum surface)
# ============================================================
fn test_boot_v21_ok() -> Result[Unit, Str] {
  let cs := JObj([("model", JStr("Model-Y")), ("vendorName", JStr("ACME Bidirectional Inc."))])
  let payload := JObj([("chargingStation", cs), ("reason", JStr(en.br_power_up()))])
  assert_ok_validation(sch.validate_boot_notification_req(payload), "boot v21")
}

fn test_authorize_v21_iso15118v20() -> Result[Unit, Str] {
  let token := JObj([("idToken", JStr("ABC123")), ("type", JStr(en.id_iso15118v20()))])
  let payload := JObj([("idToken", token)])
  assert_ok_validation(sch.validate_authorize_req(payload), "authorize iso15118v20")
}

fn test_authorize_v21_vin() -> Result[Unit, Str] {
  let token := JObj([("idToken", JStr("WAUZZZ8K7BA000001")), ("type", JStr(en.id_vin()))])
  assert_ok_validation(sch.validate_authorize_req(JObj([("idToken", token)])), "authorize VIN")
}

fn test_transaction_event_discharging() -> Result[Unit, Str] {
  let tx := JObj([("transactionId", JStr("tx-bpt-001")), ("chargingState", JStr(en.ch_discharging()))])
  let payload := JObj([("eventType", JStr(en.te_updated())), ("timestamp", JStr("2026-05-13T12:00:00Z")), ("seqNo", JInt(7)), ("transactionInfo", tx)])
  assert_ok_validation(sch.validate_transaction_event_req(payload), "tx event discharging")
}

# ============================================================
# 2.1 additions
# ============================================================
fn test_battery_swap_ok() -> Result[Unit, Str] {
  let battery := JObj([("evseId", JInt(1)), ("serialNumber", JStr("BAT-001-A")), ("soC", JFloat(85.0)), ("soH", JFloat(96.0))])
  let token := JObj([("idToken", JStr("STATION-OP-1")), ("type", JStr(en.id_central()))])
  let payload := JObj([("eventType", JStr(en.bs_battery_in())), ("idToken", token), ("requestId", JInt(1)), ("batteryData", JList([battery]))])
  assert_ok_validation(sch.validate_battery_swap_req(payload), "battery swap")
}

fn test_battery_swap_bad_soc() -> Result[Unit, Str] {
  let battery := JObj([("evseId", JInt(1)), ("serialNumber", JStr("BAT-001-A")), ("soC", JFloat(150.0)), ("soH", JFloat(96.0))])
  let token := JObj([("idToken", JStr("STATION-OP-1")), ("type", JStr(en.id_central()))])
  let payload := JObj([("eventType", JStr(en.bs_battery_in())), ("idToken", token), ("requestId", JInt(1)), ("batteryData", JList([battery]))])
  assert_err_validation(sch.validate_battery_swap_req(payload), "battery swap bad SoC")
}

fn test_notify_allowed_energy_transfer_ok() -> Result[Unit, Str] {
  let payload := JObj([("transactionId", JInt(42)), ("allowedEnergyTransfer", JList([JStr(en.etm_dc_bpt()), JStr(en.etm_ac_bpt())]))])
  assert_ok_validation(sch.validate_notify_allowed_energy_transfer_req(payload), "notify allowed energy transfer")
}

fn test_notify_allowed_energy_transfer_bad_mode() -> Result[Unit, Str] {
  let payload := JObj([("transactionId", JInt(42)), ("allowedEnergyTransfer", JList([JStr("WizardCharging")]))])
  assert_err_validation(sch.validate_notify_allowed_energy_transfer_req(payload), "bad transfer mode")
}

fn test_open_periodic_event_stream_ok() -> Result[Unit, Str] {
  let params := JObj([("interval", JInt(10)), ("values", JInt(50))])
  assert_ok_validation(sch.validate_open_periodic_event_stream_req(JObj([("constantStreamData", params)])), "open periodic stream")
}

fn test_open_periodic_event_stream_too_big_interval() -> Result[Unit, Str] {
  let params := JObj([("interval", JInt(86401)), ("values", JInt(50))])
  assert_err_validation(sch.validate_open_periodic_event_stream_req(JObj([("constantStreamData", params)])), "interval too big")
}

fn test_close_periodic_event_stream_ok() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_close_periodic_event_stream_req(JObj([("id", JInt(7))])), "close periodic stream")
}

fn test_notify_periodic_event_stream_ok() -> Result[Unit, Str] {
  let elem := JObj([("t", JFloat(0.5)), ("v", JStr("3500"))])
  let payload := JObj([("id", JInt(7)), ("pending", JStr("false")), ("basetime", JStr("2026-05-13T12:00:00Z")), ("seqNo", JInt(0)), ("data", JList([elem]))])
  assert_ok_validation(sch.validate_notify_periodic_event_stream_req(payload), "notify periodic stream")
}

fn test_get_der_control_minimal() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_get_der_control_req(JObj([("requestId", JInt(1))])), "get DER control")
}

fn test_set_der_control_ok() -> Result[Unit, Str] {
  let payload := JObj([("isDefault", JBool(false)), ("controlId", JStr("der-001")), ("controlType", JStr(en.der_volt_var()))])
  assert_ok_validation(sch.validate_set_der_control_req(payload), "set DER control")
}

fn test_set_der_control_bad_type() -> Result[Unit, Str] {
  let payload := JObj([("isDefault", JBool(false)), ("controlId", JStr("der-001")), ("controlType", JStr("FreeEnergyForever"))])
  assert_err_validation(sch.validate_set_der_control_req(payload), "bad DER control type")
}

fn test_clear_der_control_ok() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_clear_der_control_req(JObj([("isDefault", JBool(true))])), "clear DER control")
}

fn test_notify_der_alarm_ok() -> Result[Unit, Str] {
  let payload := JObj([("controlType", JStr(en.der_volt_watt())), ("timestamp", JStr("2026-05-13T12:00:00Z")), ("gridEventFault", JStr("OverVoltage"))])
  assert_ok_validation(sch.validate_notify_der_alarm_req(payload), "notify DER alarm")
}

fn test_notify_der_start_stop_ok() -> Result[Unit, Str] {
  let payload := JObj([("controlId", JStr("der-001")), ("started", JBool(true)), ("timestamp", JStr("2026-05-13T12:00:00Z"))])
  assert_ok_validation(sch.validate_notify_der_start_stop_req(payload), "notify DER start/stop")
}

fn test_change_transaction_tariff_ok() -> Result[Unit, Str] {
  let payload := JObj([("transactionId", JStr("tx-001")), ("tariffId", JStr("peak-2026"))])
  assert_ok_validation(sch.validate_change_transaction_tariff_req(payload), "change tx tariff")
}

fn test_notify_web_payment_started_ok() -> Result[Unit, Str] {
  let payload := JObj([("evseId", JInt(2)), ("timeout", JInt(300))])
  assert_ok_validation(sch.validate_notify_web_payment_started_req(payload), "notify web payment")
}

fn test_use_priority_charging_ok() -> Result[Unit, Str] {
  let payload := JObj([("transactionId", JStr("tx-001")), ("activate", JBool(true))])
  assert_ok_validation(sch.validate_use_priority_charging_req(payload), "use priority charging")
}

fn test_update_dynamic_schedule_ok() -> Result[Unit, Str] {
  let payload := JObj([("chargingProfileId", JInt(1)), ("scheduleUpdate", JObj([("limit", JFloat(11.0))]))])
  assert_ok_validation(sch.validate_update_dynamic_schedule_req(payload), "update dynamic schedule")
}

# ---- SetChargingProfile (Bidirectional Power Transfer / V2G) -----
fn charging_schedule_v21(period :: jv.Json) -> jv.Json {
  JObj([("id", JInt(1)), ("chargingRateUnit", JStr(en.cru_w())), ("chargingSchedulePeriod", JList([period]))])
}

fn test_set_charging_profile_v21_ok() -> Result[Unit, Str] {
  let period := JObj([("startPeriod", JInt(0)), ("limit", JFloat(22.0))])
  let profile := JObj([("id", JInt(1)), ("stackLevel", JInt(0)), ("chargingProfilePurpose", JStr(en.cpp_tx_default_profile())), ("chargingProfileKind", JStr(en.cpk_absolute())), ("chargingSchedule", JList([charging_schedule_v21(period)]))])
  let payload := JObj([("evseId", JInt(1)), ("chargingProfile", profile)])
  assert_ok_validation(sch.validate_set_charging_profile_req(payload), "set_charging_profile v21 ok")
}

# The actual V2G wire mechanism: a ChargingSchedulePeriod carrying
# dischargeLimit, under the LocalGeneration purpose 2.1 adds for
# exactly this — a real discharge instruction, not a made-up field.
fn test_set_charging_profile_v21_discharge_limit_ok() -> Result[Unit, Str] {
  let period := JObj([("startPeriod", JInt(0)), ("limit", JFloat(0.0)), ("dischargeLimit", JFloat(0.0 - 11.0))])
  let profile := JObj([("id", JInt(1)), ("stackLevel", JInt(0)), ("chargingProfilePurpose", JStr(en.cpp_local_generation())), ("chargingProfileKind", JStr(en.cpk_dynamic())), ("chargingSchedule", JList([charging_schedule_v21(period)]))])
  let payload := JObj([("evseId", JInt(1)), ("chargingProfile", profile)])
  assert_ok_validation(sch.validate_set_charging_profile_req(payload), "set_charging_profile v21 dischargeLimit + LocalGeneration + Dynamic")
}

fn test_set_charging_profile_v21_missing_charging_schedule() -> Result[Unit, Str] {
  let profile := JObj([("id", JInt(1)), ("stackLevel", JInt(0)), ("chargingProfilePurpose", JStr(en.cpp_tx_default_profile())), ("chargingProfileKind", JStr(en.cpk_absolute())), ("chargingSchedule", JList([]))])
  let payload := JObj([("evseId", JInt(1)), ("chargingProfile", profile)])
  assert_err_validation(sch.validate_set_charging_profile_req(payload), "set_charging_profile v21 empty chargingSchedule list")
}

# ============================================================
# Suite + runner
# ============================================================
fn suite() -> List[Result[Unit, Str]] {
  [test_boot_v21_ok(), test_authorize_v21_iso15118v20(), test_authorize_v21_vin(), test_transaction_event_discharging(), test_battery_swap_ok(), test_battery_swap_bad_soc(), test_notify_allowed_energy_transfer_ok(), test_notify_allowed_energy_transfer_bad_mode(), test_open_periodic_event_stream_ok(), test_open_periodic_event_stream_too_big_interval(), test_close_periodic_event_stream_ok(), test_notify_periodic_event_stream_ok(), test_get_der_control_minimal(), test_set_der_control_ok(), test_set_der_control_bad_type(), test_clear_der_control_ok(), test_notify_der_alarm_ok(), test_notify_der_start_stop_ok(), test_change_transaction_tariff_ok(), test_notify_web_payment_started_ok(), test_use_priority_charging_ok(), test_update_dynamic_schedule_ok(), test_set_charging_profile_v21_ok(), test_set_charging_profile_v21_discharge_limit_ok(), test_set_charging_profile_v21_missing_charging_schedule()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

