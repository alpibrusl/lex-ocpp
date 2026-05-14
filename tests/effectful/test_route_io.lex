# lex-ocpp — effectful handler registry + dispatch tests
#
# These tests exercise the effectful path with handler bodies that
# *could* use [io, time, sql] but in fact don't — pure code satisfies
# the upper bound. Tests stay reproducible without a DB or wallclock.
#
# A real handler that does use [sql] persistence would test against
# an in-memory SQLite instance; that's covered separately by the
# stateful CSMS example, not here.

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv
import "lex-schema/error"      as e

import "../../src/messages" as msg
import "../../src/route"    as route
import "../../src/route_io" as rio
import "../../src/error"    as oe

# ---- Test scaffolding --------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

fn assert_eq_str(want :: Str, got :: Str, label :: Str) -> Result[Unit, Str] {
  if want == got { pass() }
  else { fail(str.concat(label,
    str.concat(": want=", str.concat(want, str.concat(" got=", got))))) }
}

# ---- Test handlers (declared effectful even though they don't use it) ----

fn pong_handler(_p :: jv.Json) -> [io, time, sql] route.HandlerResult {
  HOk(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

fn echo_handler(p :: jv.Json) -> [io, time, sql] route.HandlerResult {
  HOk(p)
}

fn fail_handler(_p :: jv.Json) -> [io, time, sql] route.HandlerResult {
  HErr(oe.internal_err("synthetic IO failure"))
}

fn require_id_tag(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  match jv.j_str("", j, "idTag", []) {
    Ok(_)   => Ok(j),
    Err(es) => Err(es),
  }
}

# ---- Tests ------------------------------------------------------

fn test_dispatch_known() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler(rio.new(), "Heartbeat", pong_handler)
  let resp := rio.dispatch(reg,
    msg.new_call("42", "Heartbeat", JObj([])))
  match resp {
    FrameCallResult(r) => assert_eq_str("42", r.message_id, "id"),
    _ => fail("expected CallResult"),
  }
}

fn test_dispatch_unknown() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.new()
  let resp := rio.dispatch(reg,
    msg.new_call("42", "Mystery", JObj([])))
  match resp {
    FrameCallError(err) => assert_eq_str("NotImplemented", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_handler_returns_error() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler(rio.new(), "Heartbeat", fail_handler)
  let resp := rio.dispatch(reg,
    msg.new_call("42", "Heartbeat", JObj([])))
  match resp {
    FrameCallError(err) => assert_eq_str("InternalError", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_schema_gate_rejects() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler_with_schema(rio.new(),
    "Authorize", require_id_tag, echo_handler)
  let resp := rio.dispatch(reg,
    msg.new_call("42", "Authorize", JObj([])))
  match resp {
    FrameCallError(err) => assert_eq_str(
      "PropertyConstraintViolation", err.error_code, "code"),
    _ => fail("expected CallError"),
  }
}

fn test_schema_gate_accepts() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler_with_schema(rio.new(),
    "Authorize", require_id_tag, echo_handler)
  let resp := rio.dispatch(reg,
    msg.new_call("42", "Authorize", JObj([("idTag", JStr("ABC"))])))
  match resp {
    FrameCallResult(_) => pass(),
    _ => fail("expected CallResult"),
  }
}

fn test_handle_raw_round_trip() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler(rio.new(), "Heartbeat", pong_handler)
  match rio.handle_raw(reg, "[2,\"42\",\"Heartbeat\",{}]") {
    Err(_) => fail("handle_raw errored"),
    Ok(s)  => assert_eq_str(
      "[3,\"42\",{\"currentTime\":\"2026-05-13T12:00:00Z\"}]",
      s, "wire output"),
  }
}

fn test_actions_list() -> [io, time, sql] Result[Unit, Str] {
  let reg := rio.handler(
    rio.handler(rio.new(), "Heartbeat", pong_handler),
    "Authorize", echo_handler)
  if list.len(rio.actions(reg)) == 2 { pass() }
  else { fail("expected 2 actions") }
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> [io, time, sql] List[Result[Unit, Str]] {
  [
    test_dispatch_known(),
    test_dispatch_unknown(),
    test_handler_returns_error(),
    test_schema_gate_rejects(),
    test_schema_gate_accepts(),
    test_handle_raw_round_trip(),
    test_actions_list(),
  ]
}

fn run_all() -> [io, time, sql] () {
  assert list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    }) == 0
}
