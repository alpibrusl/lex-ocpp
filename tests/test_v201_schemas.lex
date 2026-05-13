# lex-ocpp — OCPP 2.0.1 schema validation tests (smoke)
#
# OCPP 2.0.1 covers many more actions than 1.6; the test surface
# here exercises the framing patterns (nested records, required-vs-
# optional, enum constraints). Add more cases by following the
# pattern in tests/test_v16_schemas.lex.

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/v201/schemas" as sch
import "../src/v201/enums"   as en

# ---- Test scaffolding --------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

fn assert_ok_validation(
  r :: Result[jv.Json, List[{ path :: Str, code :: Str, message :: Str }]],
  label :: Str
) -> Result[Unit, Str] {
  match r {
    Ok(_)  => pass(),
    Err(_) => fail(str.concat(label, ": expected Ok")),
  }
}

fn assert_err_validation(
  r :: Result[jv.Json, List[{ path :: Str, code :: Str, message :: Str }]],
  label :: Str
) -> Result[Unit, Str] {
  match r {
    Ok(_)  => fail(str.concat(label, ": expected Err")),
    Err(_) => pass(),
  }
}

# ---- BootNotification.req (nested record) ----------------------

fn test_boot_v201_ok() -> Result[Unit, Str] {
  let cs := JObj([
    ("model",      JStr("Model-X")),
    ("vendorName", JStr("ACME Corp")),
  ])
  let payload := JObj([
    ("chargingStation", cs),
    ("reason",          JStr(en.br_power_up())),
  ])
  assert_ok_validation(sch.validate_boot_notification_req(payload), "boot v201 ok")
}

fn test_boot_v201_missing_nested() -> Result[Unit, Str] {
  let payload := JObj([("reason", JStr(en.br_power_up()))])
  assert_err_validation(
    sch.validate_boot_notification_req(payload), "boot v201 missing")
}

fn test_boot_v201_bad_reason() -> Result[Unit, Str] {
  let cs := JObj([
    ("model",      JStr("Model-X")),
    ("vendorName", JStr("ACME Corp")),
  ])
  let payload := JObj([
    ("chargingStation", cs),
    ("reason",          JStr("WindOfChange")),
  ])
  assert_err_validation(
    sch.validate_boot_notification_req(payload), "boot v201 bad reason")
}

# ---- Heartbeat (empty payload) ----------------------------------

fn test_heartbeat_v201() -> Result[Unit, Str] {
  assert_ok_validation(sch.validate_heartbeat_req(JObj([])), "heartbeat v201")
}

# ---- Authorize (nested IdToken) ---------------------------------

fn test_authorize_v201_ok() -> Result[Unit, Str] {
  let token := JObj([
    ("idToken", JStr("ABC123")),
    ("type",    JStr(en.id_iso14443())),
  ])
  let payload := JObj([("idToken", token)])
  assert_ok_validation(sch.validate_authorize_req(payload), "authorize v201 ok")
}

fn test_authorize_v201_bad_token_type() -> Result[Unit, Str] {
  let token := JObj([
    ("idToken", JStr("ABC123")),
    ("type",    JStr("PaperFortune")),
  ])
  let payload := JObj([("idToken", token)])
  assert_err_validation(
    sch.validate_authorize_req(payload), "authorize v201 bad type")
}

# ---- TransactionEvent -------------------------------------------

fn test_transaction_event_ok() -> Result[Unit, Str] {
  let tx := JObj([("transactionId", JStr("tx-001"))])
  let payload := JObj([
    ("eventType",       JStr(en.te_started())),
    ("timestamp",       JStr("2026-05-13T12:00:00Z")),
    ("triggerReason",   JStr(en.tr_authorized())),
    ("seqNo",           JInt(0)),
    ("transactionInfo", tx),
  ])
  assert_ok_validation(
    sch.validate_transaction_event_req(payload), "tx event ok")
}

fn test_transaction_event_missing_seq() -> Result[Unit, Str] {
  let tx := JObj([("transactionId", JStr("tx-001"))])
  let payload := JObj([
    ("eventType",       JStr(en.te_started())),
    ("timestamp",       JStr("2026-05-13T12:00:00Z")),
    ("triggerReason",   JStr(en.tr_authorized())),
    ("transactionInfo", tx),
  ])
  assert_err_validation(
    sch.validate_transaction_event_req(payload), "tx event missing seq")
}

# ---- StatusNotification (v2.0.1 has different fields) -----------

fn test_status_notification_v201_ok() -> Result[Unit, Str] {
  let payload := JObj([
    ("timestamp",        JStr("2026-05-13T12:00:00Z")),
    ("connectorStatus",  JStr(en.cs_available())),
    ("evseId",           JInt(1)),
    ("connectorId",      JInt(1)),
  ])
  assert_ok_validation(
    sch.validate_status_notification_req(payload), "status v201 ok")
}

# ---- Reset ------------------------------------------------------

fn test_reset_v201_immediate() -> Result[Unit, Str] {
  assert_ok_validation(
    sch.validate_reset_req(JObj([("type", JStr(en.reset_immediate()))])),
    "reset immediate")
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_boot_v201_ok(),
    test_boot_v201_missing_nested(),
    test_boot_v201_bad_reason(),
    test_heartbeat_v201(),
    test_authorize_v201_ok(),
    test_authorize_v201_bad_token_type(),
    test_transaction_event_ok(),
    test_transaction_event_missing_seq(),
    test_status_notification_v201_ok(),
    test_reset_v201_immediate(),
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    })
}
