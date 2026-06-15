# lex-ocpp — handler registry + dispatch tests

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "../src/messages" as msg

import "../src/route" as route

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

# ---- Test handlers ----------------------------------------------
fn pong_handler(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn echo_handler(payload :: jv.Json) -> route.HandlerResult {
  route.ok(payload)
}

fn fail_handler(_payload :: jv.Json) -> route.HandlerResult {
  route.fail(oe.internal_err("synthetic failure"))
}

# Validator that requires a top-level "idTag" string.
fn require_id_tag(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  match jv.j_str("", j, "idTag", []) {
    Ok(_) => Ok(j),
    Err(es) => Err(es),
  }
}

# ---- Tests ------------------------------------------------------
fn test_dispatch_known_action() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), "Heartbeat", pong_handler)
  let frame := msg.new_call("42", "Heartbeat", JObj([]))
  let resp := route.dispatch(reg, frame)
  match resp {
    FrameCallResult(r) => assert_eq_str("42", r.message_id, "id"),
    _ => fail("expected CallResult"),
  }
}

fn test_dispatch_unknown_action_returns_not_implemented() -> Result[Unit, Str] {
  let reg := route.new()
  let frame := msg.new_call("42", "MysteryAction", JObj([]))
  let resp := route.dispatch(reg, frame)
  match resp {
    FrameCallError(err) => assert_eq_str("NotImplemented", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_dispatch_handler_can_return_error() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), "Heartbeat", fail_handler)
  let resp := route.dispatch(reg, msg.new_call("42", "Heartbeat", JObj([])))
  match resp {
    FrameCallError(err) => assert_eq_str("InternalError", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_dispatch_with_schema_rejects_bad_payload() -> Result[Unit, Str] {
  let reg := route.handler_with_schema(route.new(), "Authorize", require_id_tag, echo_handler)
  let resp := route.dispatch(reg, msg.new_call("42", "Authorize", JObj([])))
  match resp {
    FrameCallError(err) => assert_eq_str("PropertyConstraintViolation", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_dispatch_with_schema_accepts_valid_payload() -> Result[Unit, Str] {
  let reg := route.handler_with_schema(route.new(), "Authorize", require_id_tag, echo_handler)
  let payload := JObj([("idTag", JStr("ABC"))])
  let resp := route.dispatch(reg, msg.new_call("42", "Authorize", payload))
  match resp {
    FrameCallResult(_) => pass(),
    _ => fail("expected CallResult"),
  }
}

fn test_passthrough_non_call() -> Result[Unit, Str] {
  let reg := route.new()
  let result_frame := msg.new_call_result("42", JObj([]))
  let resp := route.dispatch(reg, result_frame)
  if msg.is_call_result(resp) {
    pass()
  } else {
    fail("expected non-Call to pass through")
  }
}

fn test_handle_raw_round_trip() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), "Heartbeat", pong_handler)
  match route.handle_raw(reg, "[2,\"42\",\"Heartbeat\",{}]") {
    Err(_) => fail("handle_raw should not have errored"),
    Ok(s) => assert_eq_str("[3,\"42\",{\"currentTime\":\"2026-05-13T12:00:00Z\"}]", s, "wire output"),
  }
}

fn test_handle_raw_bad_input() -> Result[Unit, Str] {
  let reg := route.new()
  match route.handle_raw(reg, "not json") {
    Err(_) => pass(),
    Ok(_) => fail("handle_raw should have errored on bad input"),
  }
}

fn test_actions_list() -> Result[Unit, Str] {
  let reg := route.handler(route.handler(route.new(), "Heartbeat", pong_handler), "Authorize", echo_handler)
  let actions := route.actions(reg)
  if list.len(actions) == 2 {
    pass()
  } else {
    fail("expected 2 registered actions")
  }
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_dispatch_known_action(), test_dispatch_unknown_action_returns_not_implemented(), test_dispatch_handler_can_return_error(), test_dispatch_with_schema_rejects_bad_payload(), test_dispatch_with_schema_accepts_valid_payload(), test_passthrough_non_call(), test_handle_raw_round_trip(), test_handle_raw_bad_input(), test_actions_list()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

