# lex-ocpp — error code constants + OcppError helpers

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/error" as oe

# ---- Test scaffolding --------------------------------------------
fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_eq_str(want :: Str, got :: Str, label :: Str) -> Result[Unit, Str] {
  if want == got {
    pass()
  } else {
    fail(str.concat(label, str.concat(": want=", str.concat(want, str.concat(" got=", got)))))
  }
}

fn assert_eq_int(want :: Int, got :: Int, label :: Str) -> Result[Unit, Str] {
  if want == got {
    pass()
  } else {
    fail(label)
  }
}

fn assert_true(b :: Bool, label :: Str) -> Result[Unit, Str] {
  if b {
    pass()
  } else {
    fail(label)
  }
}

fn list_contains(xs :: List[Str], target :: Str) -> Bool {
  list.fold(xs, false, fn (acc :: Bool, x :: Str) -> Bool {
    if acc {
      true
    } else {
      x == target
    }
  })
}

# ---- Catalog sizes match the spec -------------------------------
fn test_all_v16_count() -> Result[Unit, Str] {
  assert_eq_int(10, list.len(oe.all_v16()), "v16 codes count")
}

fn test_all_v201_count() -> Result[Unit, Str] {
  assert_eq_int(12, list.len(oe.all_v201()), "v201 codes count")
}

# ---- v1.6 uses the spec's typo'd spelling -----------------------
fn test_v16_uses_occurence() -> Result[Unit, Str] {
  assert_true(list_contains(oe.all_v16(), "OccurenceConstraintViolation"), "v1.6 should expose OccurenceConstraintViolation (the spec's typo)")
}

fn test_v201_uses_occurrence() -> Result[Unit, Str] {
  assert_true(list_contains(oe.all_v201(), "OccurrenceConstraintViolation"), "v2.0.1 should expose OccurrenceConstraintViolation (the corrected spelling)")
}

fn test_v201_uses_format_violation() -> Result[Unit, Str] {
  assert_true(list_contains(oe.all_v201(), "FormatViolation"), "v2.0.1 should expose FormatViolation (replaces FormationViolation)")
}

# ---- Error code constants ---------------------------------------
fn test_not_implemented_constant() -> Result[Unit, Str] {
  assert_eq_str("NotImplemented", oe.not_implemented(), "not_implemented")
}

fn test_protocol_error_constant() -> Result[Unit, Str] {
  assert_eq_str("ProtocolError", oe.protocol_error(), "protocol_error")
}

# ---- OcppError builders -----------------------------------------
fn test_not_implemented_err() -> Result[Unit, Str] {
  let e := oe.not_implemented_err("MysteryAction")
  if e.code == "NotImplemented" {
    assert_eq_str("action not implemented: MysteryAction", e.description, "description")
  } else {
    fail(str.concat("wrong code: ", e.code))
  }
}

fn test_from_schema_errors_empty() -> Result[Unit, Str] {
  let oerr := oe.from_schema_errors([])
  assert_eq_str("PropertyConstraintViolation", oerr.code, "code")
}

fn test_from_schema_errors_carries_details() -> Result[Unit, Str] {
  let oerr := oe.from_schema_errors([{ path: "idTag", code: "min_len", message: "must be at least 1 characters" }])
  match jv.get_field(oerr.details, "violations") {
    None => fail("missing violations"),
    Some(_) => pass(),
  }
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_all_v16_count(), test_all_v201_count(), test_v16_uses_occurence(), test_v201_uses_occurrence(), test_v201_uses_format_violation(), test_not_implemented_constant(), test_protocol_error_constant(), test_not_implemented_err(), test_from_schema_errors_empty(), test_from_schema_errors_carries_details()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

