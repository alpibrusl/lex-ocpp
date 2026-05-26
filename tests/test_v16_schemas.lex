# lex-ocpp — OCPP 1.6 schema validation tests

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/v16/schemas" as sch
import "../src/v16/enums"   as en

# ---- Test scaffolding --------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

fn assert_ok[T, E](r :: Result[T, E], label :: Str) -> Result[Unit, Str] {
  match r {
    Ok(_)  => pass(),
    Err(_) => fail(str.concat(label, ": expected Ok")),
  }
}

fn assert_err[T, E](r :: Result[T, E], label :: Str) -> Result[Unit, Str] {
  match r {
    Ok(_)  => fail(str.concat(label, ": expected Err")),
    Err(_) => pass(),
  }
}

# ---- BootNotification.req ---------------------------------------

fn test_boot_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("chargePointVendor", JStr("ACME")),
    ("chargePointModel",  JStr("Model-X")),
    ("firmwareVersion",   JStr("1.0.0")),
  ])
  assert_ok(sch.validate_boot_notification_req(payload), "boot_ok")
}

fn test_boot_missing_vendor() -> Result[Unit, Str] {
  let payload := JObj([
    ("chargePointModel", JStr("Model-X")),
  ])
  assert_err(sch.validate_boot_notification_req(payload), "boot_missing_vendor")
}

fn test_boot_vendor_too_long() -> Result[Unit, Str] {
  let payload := JObj([
    ("chargePointVendor", JStr("ThisVendorNameIsWayTooLongForOCPP")),
    ("chargePointModel",  JStr("Model-X")),
  ])
  assert_err(sch.validate_boot_notification_req(payload), "boot_vendor_too_long")
}

# ---- Authorize.req ----------------------------------------------

fn test_authorize_ok() -> Result[Unit, Str] {
  let payload := JObj([("idTag", JStr("ABC123"))])
  assert_ok(sch.validate_authorize_req(payload), "authorize_ok")
}

fn test_authorize_empty_id_tag() -> Result[Unit, Str] {
  let payload := JObj([("idTag", JStr(""))])
  assert_err(sch.validate_authorize_req(payload), "authorize_empty")
}

fn test_authorize_missing_id_tag() -> Result[Unit, Str] {
  let payload := JObj([])
  assert_err(sch.validate_authorize_req(payload), "authorize_missing")
}

# ---- Heartbeat.req ----------------------------------------------

fn test_heartbeat_ok() -> Result[Unit, Str] {
  assert_ok(sch.validate_heartbeat_req(JObj([])), "heartbeat_ok")
}

# ---- StatusNotification.req -------------------------------------

fn test_status_notification_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("connectorId", JInt(1)),
    ("errorCode",   JStr(en.ec_no_error())),
    ("status",      JStr(en.cp_available())),
  ])
  assert_ok(sch.validate_status_notification_req(payload), "status_ok")
}

fn test_status_notification_bad_enum() -> Result[Unit, Str] {
  let payload := JObj([
    ("connectorId", JInt(1)),
    ("errorCode",   JStr(en.ec_no_error())),
    ("status",      JStr("UnknownStatus")),
  ])
  assert_err(sch.validate_status_notification_req(payload), "status_bad_enum")
}

# ---- StartTransaction.req ---------------------------------------

fn test_start_transaction_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("connectorId", JInt(1)),
    ("idTag",       JStr("USER-001")),
    ("meterStart",  JInt(0)),
    ("timestamp",   JStr("2026-05-13T12:00:00Z")),
  ])
  assert_ok(sch.validate_start_transaction_req(payload), "start_tx_ok")
}

fn test_start_transaction_zero_connector() -> Result[Unit, Str] {
  let payload := JObj([
    ("connectorId", JInt(0)),
    ("idTag",       JStr("USER-001")),
    ("meterStart",  JInt(0)),
    ("timestamp",   JStr("2026-05-13T12:00:00Z")),
  ])
  assert_err(sch.validate_start_transaction_req(payload), "start_tx_zero_connector")
}

# ---- StopTransaction.req ----------------------------------------

fn test_stop_transaction_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("meterStop",     JInt(1500)),
    ("timestamp",     JStr("2026-05-13T13:00:00Z")),
    ("transactionId", JInt(12345)),
    ("reason",        JStr(en.reason_local())),
  ])
  assert_ok(sch.validate_stop_transaction_req(payload), "stop_tx_ok")
}

fn test_stop_transaction_bad_reason() -> Result[Unit, Str] {
  let payload := JObj([
    ("meterStop",     JInt(1500)),
    ("timestamp",     JStr("2026-05-13T13:00:00Z")),
    ("transactionId", JInt(12345)),
    ("reason",        JStr("AlienAbduction")),
  ])
  assert_err(sch.validate_stop_transaction_req(payload), "stop_tx_bad_reason")
}

# ---- MeterValues.req --------------------------------------------

fn test_meter_values_ok() -> Result[Unit, Str] {
  let sv := JObj([
    ("value",    JStr("3500")),
    ("measurand", JStr(en.ms_energy_active_import_register())),
    ("unit",      JStr(en.uom_wh())),
  ])
  let mv := JObj([
    ("timestamp",    JStr("2026-05-13T12:30:00Z")),
    ("sampledValue", JList([sv])),
  ])
  let payload := JObj([
    ("connectorId", JInt(1)),
    ("meterValue",  JList([mv])),
  ])
  assert_ok(sch.validate_meter_values_req(payload), "meter_values_ok")
}

fn test_meter_values_empty_list() -> Result[Unit, Str] {
  let payload := JObj([
    ("connectorId", JInt(1)),
    ("meterValue",  JList([])),
  ])
  assert_err(sch.validate_meter_values_req(payload), "meter_values_empty")
}

# ---- DataTransfer.req -------------------------------------------

fn test_data_transfer_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("vendorId",  JStr("com.example.vendor")),
    ("messageId", JStr("foo.bar")),
    ("data",      JStr("payload")),
  ])
  assert_ok(sch.validate_data_transfer_req(payload), "data_xfer_ok")
}

fn test_data_transfer_missing_vendor() -> Result[Unit, Str] {
  let payload := JObj([("messageId", JStr("foo.bar"))])
  assert_err(sch.validate_data_transfer_req(payload), "data_xfer_missing_vendor")
}

# ---- FirmwareStatusNotification.req -----------------------------

fn test_firmware_status_ok() -> Result[Unit, Str] {
  let payload := JObj([("status", JStr(en.fw_downloading()))])
  assert_ok(sch.validate_firmware_status_notification_req(payload), "fw_ok")
}

fn test_firmware_status_bad_enum() -> Result[Unit, Str] {
  let payload := JObj([("status", JStr("HumanReadable"))])
  assert_err(sch.validate_firmware_status_notification_req(payload), "fw_bad")
}

# ---- Reset.req (CS → CP) ----------------------------------------

fn test_reset_ok() -> Result[Unit, Str] {
  assert_ok(sch.validate_reset_req(JObj([("type", JStr(en.reset_hard()))])),
    "reset_ok")
}

fn test_reset_bad_type() -> Result[Unit, Str] {
  assert_err(sch.validate_reset_req(JObj([("type", JStr("Nuclear"))])),
    "reset_bad")
}

# ---- find_validator ---------------------------------------------

fn test_find_validator_known() -> Result[Unit, Str] {
  match sch.find_validator("Heartbeat") {
    Some(_) => pass(),
    None    => fail("expected Heartbeat validator"),
  }
}

fn test_find_validator_unknown() -> Result[Unit, Str] {
  match sch.find_validator("NoSuchAction") {
    None    => pass(),
    Some(_) => fail("did not expect a validator"),
  }
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_boot_ok(),
    test_boot_missing_vendor(),
    test_boot_vendor_too_long(),
    test_authorize_ok(),
    test_authorize_empty_id_tag(),
    test_authorize_missing_id_tag(),
    test_heartbeat_ok(),
    test_status_notification_ok(),
    test_status_notification_bad_enum(),
    test_start_transaction_ok(),
    test_start_transaction_zero_connector(),
    test_stop_transaction_ok(),
    test_stop_transaction_bad_reason(),
    test_meter_values_ok(),
    test_meter_values_empty_list(),
    test_data_transfer_ok(),
    test_data_transfer_missing_vendor(),
    test_firmware_status_ok(),
    test_firmware_status_bad_enum(),
    test_reset_ok(),
    test_reset_bad_type(),
    test_find_validator_known(),
    test_find_validator_unknown(),
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    })
}
