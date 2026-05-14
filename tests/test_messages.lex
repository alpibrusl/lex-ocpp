# lex-ocpp — frame parse / encode tests

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/messages" as msg

# ---- Test scaffolding --------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

fn assert_eq_str(want :: Str, got :: Str, label :: Str) -> Result[Unit, Str] {
  if want == got { pass() }
  else { fail(str.concat(label,
    str.concat(": want=", str.concat(want, str.concat(" got=", got))))) }
}

fn assert_true(b :: Bool, label :: Str) -> Result[Unit, Str] {
  if b { pass() } else { fail(label) }
}

# ---- Encode / decode round-trips --------------------------------

fn test_encode_call() -> Result[Unit, Str] {
  let f := msg.new_call("19223201", "BootNotification", JObj([]))
  assert_eq_str(
    "[2,\"19223201\",\"BootNotification\",{}]",
    msg.encode(f),
    "encode_call")
}

fn test_encode_call_result() -> Result[Unit, Str] {
  let f := msg.new_call_result("19223201", JObj([("status", JStr("Accepted"))]))
  assert_eq_str(
    "[3,\"19223201\",{\"status\":\"Accepted\"}]",
    msg.encode(f),
    "encode_call_result")
}

fn test_encode_call_error() -> Result[Unit, Str] {
  let f := msg.new_call_error("19223201", "NotImplemented",
    "Unknown action", JObj([]))
  assert_eq_str(
    "[4,\"19223201\",\"NotImplemented\",\"Unknown action\",{}]",
    msg.encode(f),
    "encode_call_error")
}

fn test_parse_call() -> Result[Unit, Str] {
  let raw := "[2,\"42\",\"Heartbeat\",{}]"
  match msg.parse(raw) {
    Err(e) => fail(str.concat("parse_call: ", e.message)),
    Ok(f)  => match f {
      FrameCall(c) => assert_eq_str("Heartbeat", c.action, "action"),
      _ => fail("parse_call: wrong variant"),
    },
  }
}

fn test_parse_call_result() -> Result[Unit, Str] {
  let raw := "[3,\"42\",{\"currentTime\":\"2026-01-01T00:00:00Z\"}]"
  match msg.parse(raw) {
    Err(e) => fail(str.concat("parse_call_result: ", e.message)),
    Ok(f)  => match f {
      FrameCallResult(r) => assert_eq_str("42", r.message_id, "id"),
      _ => fail("parse_call_result: wrong variant"),
    },
  }
}

fn test_parse_call_error() -> Result[Unit, Str] {
  let raw := "[4,\"42\",\"InternalError\",\"oops\",{}]"
  match msg.parse(raw) {
    Err(e) => fail(str.concat("parse_call_error: ", e.message)),
    Ok(f)  => match f {
      FrameCallError(err) => assert_eq_str("InternalError", err.error_code, "code"),
      _ => fail("parse_call_error: wrong variant"),
    },
  }
}

# ---- Negative cases — bad input never panics --------------------

fn test_parse_invalid_json() -> Result[Unit, Str] {
  match msg.parse("not json") {
    Err(_) => pass(),
    Ok(_)  => fail("invalid JSON should have errored"),
  }
}

fn test_parse_wrong_type() -> Result[Unit, Str] {
  match msg.parse("{\"not\":\"an array\"}") {
    Err(_) => pass(),
    Ok(_)  => fail("non-array should have errored"),
  }
}

fn test_parse_unknown_message_type() -> Result[Unit, Str] {
  match msg.parse("[9,\"id\",\"X\",{}]") {
    Err(e) => assert_true(
      str.contains(e.message, "unknown MessageType"),
      "expected 'unknown MessageType' error"),
    Ok(_) => fail("MessageType 9 should have errored"),
  }
}

fn test_parse_call_wrong_arity() -> Result[Unit, Str] {
  match msg.parse("[2,\"id\",\"Action\"]") {
    Err(_) => pass(),
    Ok(_)  => fail("Call missing payload should error"),
  }
}

fn test_parse_call_non_string_id() -> Result[Unit, Str] {
  match msg.parse("[2,42,\"Action\",{}]") {
    Err(_) => pass(),
    Ok(_)  => fail("non-string message_id should error"),
  }
}

fn test_round_trip_call() -> Result[Unit, Str] {
  let original := msg.new_call("abc", "Heartbeat", JObj([]))
  match msg.parse(msg.encode(original)) {
    Err(e) => fail(str.concat("round-trip: ", e.message)),
    Ok(f)  => match f {
      FrameCall(c) => assert_eq_str("abc", c.message_id, "round-trip id"),
      _ => fail("round-trip: wrong variant"),
    },
  }
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_encode_call(),
    test_encode_call_result(),
    test_encode_call_error(),
    test_parse_call(),
    test_parse_call_result(),
    test_parse_call_error(),
    test_parse_invalid_json(),
    test_parse_wrong_type(),
    test_parse_unknown_message_type(),
    test_parse_call_wrong_arity(),
    test_parse_call_non_string_id(),
    test_round_trip_call(),
  ]
}

fn run_all() -> () {
  assert list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r {
        Ok(_)  => n,
        Err(_) => n + 1,
      }
    }) == 0
}
