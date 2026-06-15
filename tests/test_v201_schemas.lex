# lex-ocpp — OCPP 2.0.1 schema validation tests (smoke)

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/v201/schemas" as sch

import "../src/v201/enums" as en

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

# ---- BootNotification.req (nested record) ----------------------
fn test_boot_v201_ok() -> Result[Unit, Str] {
  let cs := JObj([("model", JStr("Model-X")), ("vendorName", JStr("ACME Corp"))])
  let payload := JObj([("chargingStation", cs), ("reason", JStr(en.br_power_up()))])
  assert_ok_validation(sch.validate_boot_notification_req(payload), "boot v201 ok")
}

fn test_boot_v201_missing_nested() -> Result[Unit, Str] {
  let payload := JObj([("reason", JStr(en.br_power_up()))])
  assert_err_validation(sch.validate_boot_notification_req(payload), "boot v201 missing")
}

fn test_boot_v201_bad_reason() -> Result[Unit, Str] {
  let cs := JObj([("model", JStr("Model-X")), ("vendorName", JStr("ACME Corp"))])
  let payload := JObj([("chargingStation", cs), ("reason", JStr("WindOfChange"))])
  assert_err_validation(sch.validate_boot_notification_req(payload), "boot v201 bad reason")
}

# ---- Heartbeat (empty payload) ----------------------------------
fn test_heartbeat_v201() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_heartbeat_req(JObj([])), "heartbeat v201")
}

# ---- Authorize (nested IdToken) ---------------------------------
fn test_authorize_v201_ok() -> Result[Unit, Str] {
  let token := JObj([("idToken", JStr("ABC123")), ("type", JStr(en.id_iso14443()))])
  let payload := JObj([("idToken", token)])
  assert_ok_validation(sch.validate_authorize_req(payload), "authorize v201 ok")
}

fn test_authorize_v201_bad_token_type() -> Result[Unit, Str] {
  let token := JObj([("idToken", JStr("ABC123")), ("type", JStr("PaperFortune"))])
  let payload := JObj([("idToken", token)])
  assert_err_validation(sch.validate_authorize_req(payload), "authorize v201 bad type")
}

# ---- TransactionEvent -------------------------------------------
fn test_transaction_event_ok() -> Result[Unit, Str] {
  let tx := JObj([("transactionId", JStr("tx-001"))])
  let payload := JObj([("eventType", JStr(en.te_started())), ("timestamp", JStr("2026-05-13T12:00:00Z")), ("triggerReason", JStr(en.tr_authorized())), ("seqNo", JInt(0)), ("transactionInfo", tx)])
  assert_ok_validation(sch.validate_transaction_event_req(payload), "tx event ok")
}

fn test_transaction_event_missing_seq() -> Result[Unit, Str] {
  let tx := JObj([("transactionId", JStr("tx-001"))])
  let payload := JObj([("eventType", JStr(en.te_started())), ("timestamp", JStr("2026-05-13T12:00:00Z")), ("triggerReason", JStr(en.tr_authorized())), ("transactionInfo", tx)])
  assert_err_validation(sch.validate_transaction_event_req(payload), "tx event missing seq")
}

# ---- StatusNotification (v2.0.1 has different fields) -----------
fn test_status_notification_v201_ok() -> Result[Unit, Str] {
  let payload := JObj([("timestamp", JStr("2026-05-13T12:00:00Z")), ("connectorStatus", JStr(en.cs_available())), ("evseId", JInt(1)), ("connectorId", JInt(1))])
  assert_ok_validation(sch.validate_status_notification_req(payload), "status v201 ok")
}

# ---- Reset ------------------------------------------------------
fn test_reset_v201_immediate() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_reset_req(JObj([("type", JStr(en.reset_immediate()))])), "reset immediate")
}

# ---- Extended surface (expanded in v0.2) ------------------------
fn test_clear_cache_ok() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_clear_cache_req(JObj([])), "clear_cache")
}

fn test_cancel_reservation_ok() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_cancel_reservation_req(JObj([("reservationId", JInt(7))])), "cancel_reservation")
}

fn test_cancel_reservation_missing() -> Result[Unit, Str] {
  assert_err_validation(sch.validate_cancel_reservation_req(JObj([])), "cancel_reservation missing")
}

fn test_get_variables_ok() -> Result[Unit, Str] {
  let item := JObj([("component", JObj([("name", JStr("AlignedDataCtrlr"))])), ("variable", JObj([("name", JStr("Enabled"))]))])
  let payload := JObj([("getVariableData", JList([item]))])
  assert_ok_validation(sch.validate_get_variables_req(payload), "get_variables")
}

fn test_get_variables_empty_list() -> Result[Unit, Str] {
  let payload := JObj([("getVariableData", JList([]))])
  assert_err_validation(sch.validate_get_variables_req(payload), "get_variables empty")
}

fn test_set_variables_ok() -> Result[Unit, Str] {
  let item := JObj([("attributeValue", JStr("true")), ("component", JObj([("name", JStr("AlignedDataCtrlr"))])), ("variable", JObj([("name", JStr("Enabled"))]))])
  let payload := JObj([("setVariableData", JList([item]))])
  assert_ok_validation(sch.validate_set_variables_req(payload), "set_variables")
}

fn test_get_base_report_ok() -> Result[Unit, Str] {
  let payload := JObj([("requestId", JInt(1)), ("reportBase", JStr("FullInventory"))])
  assert_ok_validation(sch.validate_get_base_report_req(payload), "get_base_report")
}

fn test_get_base_report_bad_enum() -> Result[Unit, Str] {
  let payload := JObj([("requestId", JInt(1)), ("reportBase", JStr("WhateverInventory"))])
  assert_err_validation(sch.validate_get_base_report_req(payload), "get_base_report bad")
}

fn test_log_status_notification_ok() -> Result[Unit, Str] {
  let payload := JObj([("status", JStr("Idle"))])
  assert_ok_validation(sch.validate_log_status_notification_req(payload), "log_status")
}

fn test_sign_certificate_ok() -> Result[Unit, Str] {
  let payload := JObj([("csr", JStr("-----BEGIN CERTIFICATE REQUEST-----\nMIIB...")), ("certificateType", JStr("ChargingStationCertificate"))])
  assert_ok_validation(sch.validate_sign_certificate_req(payload), "sign_certificate")
}

fn test_update_firmware_ok() -> Result[Unit, Str] {
  let firmware := JObj([("location", JStr("https://updates.example.com/fw-1.2.3.bin")), ("retrieveDateTime", JStr("2026-05-13T12:00:00Z"))])
  let payload := JObj([("requestId", JInt(99)), ("firmware", firmware)])
  assert_ok_validation(sch.validate_update_firmware_req(payload), "update_firmware")
}

fn test_notify_event_ok() -> Result[Unit, Str] {
  let event := JObj([("eventId", JInt(1)), ("timestamp", JStr("2026-05-13T12:00:00Z")), ("trigger", JStr("Periodic")), ("actualValue", JStr("42")), ("eventNotificationType", JStr("HardWiredNotification")), ("component", JObj([("name", JStr("AlignedDataCtrlr"))])), ("variable", JObj([("name", JStr("Enabled"))]))])
  let payload := JObj([("generatedAt", JStr("2026-05-13T12:00:00Z")), ("seqNo", JInt(0)), ("eventData", JList([event]))])
  assert_ok_validation(sch.validate_notify_event_req(payload), "notify_event")
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_boot_v201_ok(), test_boot_v201_missing_nested(), test_boot_v201_bad_reason(), test_heartbeat_v201(), test_authorize_v201_ok(), test_authorize_v201_bad_token_type(), test_transaction_event_ok(), test_transaction_event_missing_seq(), test_status_notification_v201_ok(), test_reset_v201_immediate(), test_clear_cache_ok(), test_cancel_reservation_ok(), test_cancel_reservation_missing(), test_get_variables_ok(), test_get_variables_empty_list(), test_set_variables_ok(), test_get_base_report_ok(), test_get_base_report_bad_enum(), test_log_status_notification_ok(), test_sign_certificate_ok(), test_update_firmware_ok(), test_notify_event_ok()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

