# lex-ocpp — handler registry + dispatch
#
# Mobilityhouse's `ocpp` library registers handlers by decorating
# methods with `@on('ActionName')`. Lex has no decorators, so we
# build the same surface with a value: a `Registry` is a list of
# `(action, validator, handler)` entries plus a fallback for
# unknown actions.
#
# Pure-core design:
#   handler :: (jv.Json) -> HandlerResult
#   dispatch :: (Registry, Frame) -> Frame
#
# The dispatcher takes an inbound Call frame, looks up the action,
# validates the payload (if a validator is registered), invokes the
# handler, and packages the result as a CallResult or CallError
# frame ready for the transport to ship. Inbound CallResult /
# CallError frames are returned to the caller for correlation
# tracking — the dispatcher itself is stateless.
#
# Effects: none. Sit this module behind any transport-flavoured
# adapter ([net], [io], etc.); the adapter declares the effects.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "./messages" as msg

import "./error" as oe

# ---- Handler types -----------------------------------------------
type HandlerResult = HOk(jv.Json) | HErr(oe.OcppError)

type Handler = (jv.Json) -> HandlerResult

# A validator takes a payload and either passes it through (possibly
# normalized) or returns a list of structured errors. Same shape as
# `lex-schema/validator.validate`; any function with this signature
# can be registered.
type Validator = (jv.Json) -> Result[jv.Json, List[e.Error]]

# An unknown-action fallback: called when no entry matches the
# inbound Call.action. Default returns a NotImplemented error.
type Fallback = (Str, jv.Json) -> HandlerResult

# ---- Registry datatype -------------------------------------------
type RouteEntry = { action :: Str, validator :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]], handler :: (jv.Json) -> HandlerResult }

type Registry = { routes :: List[RouteEntry], on_unknown :: (Str, jv.Json) -> HandlerResult }

# ---- Registry construction ---------------------------------------
fn new() -> Registry {
  { routes: [], on_unknown: default_unknown }
}

# Default: every unknown Action is answered with NotImplemented.
# Override via `with_unknown` to plug in vendor extensions.
fn default_unknown(action :: Str, _payload :: jv.Json) -> HandlerResult {
  HErr(oe.not_implemented_err(action))
}

fn with_unknown(reg :: Registry, fb :: Fallback) -> Registry {
  { routes: reg.routes, on_unknown: fb }
}

# Register a handler without a payload schema. The handler sees the
# raw payload Json; validation is the handler's responsibility.
fn handler(reg :: Registry, action :: Str, h :: Handler) -> Registry {
  add_entry(reg, { action: action, validator: None, handler: h })
}

# Register a handler with a payload validator. The dispatcher will
# call the validator first; a schema failure surfaces as a
# `PropertyConstraintViolation` CallError before the handler runs.
fn handler_with_schema(reg :: Registry, action :: Str, validator :: Validator, h :: Handler) -> Registry {
  add_entry(reg, { action: action, validator: Some(validator), handler: h })
}

fn add_entry(reg :: Registry, entry :: RouteEntry) -> Registry {
  { routes: list.concat(reg.routes, [entry]), on_unknown: reg.on_unknown }
}

# ---- Lookup ------------------------------------------------------
fn find(reg :: Registry, action :: Str) -> Option[RouteEntry] {
  list.fold(reg.routes, None, fn (acc :: Option[RouteEntry], entry :: RouteEntry) -> Option[RouteEntry] {
    match acc {
      Some(_) => acc,
      None => if entry.action == action {
        Some(entry)
      } else {
        None
      },
    }
  })
}

fn actions(reg :: Registry) -> List[Str] {
  list.map(reg.routes, fn (entry :: RouteEntry) -> Str {
    entry.action
  })
}

# ---- Dispatch ----------------------------------------------------
#
# `dispatch` turns an inbound Call frame into the outbound response
# frame (CallResult or CallError). Non-Call frames are returned
# unchanged — they're not the dispatcher's responsibility, but
# carrying them through keeps the call site uniform.
fn dispatch(reg :: Registry, frame :: msg.Frame) -> msg.Frame {
  match frame {
    FrameCall(c) => dispatch_call(reg, c),
    FrameCallResult(_) => frame,
    FrameCallError(_) => frame,
  }
}

fn dispatch_call(reg :: Registry, c :: { message_id :: Str, action :: Str, payload :: jv.Json }) -> msg.Frame {
  match find(reg, c.action) {
    None => result_from_handler(c.message_id, reg.on_unknown(c.action, c.payload)),
    Some(entry) => run_entry(c.message_id, entry, c.payload),
  }
}

fn run_entry(message_id :: Str, entry :: RouteEntry, payload :: jv.Json) -> msg.Frame {
  match entry.validator {
    None => result_from_handler(message_id, entry.handler(payload)),
    Some(vf) => match vf(payload) {
      Err(es) => result_from_handler(message_id, HErr(oe.from_schema_errors(es))),
      Ok(normalized) => result_from_handler(message_id, entry.handler(normalized)),
    },
  }
}

fn result_from_handler(message_id :: Str, hr :: HandlerResult) -> msg.Frame {
  match hr {
    HOk(payload) => msg.new_call_result(message_id, payload),
    HErr(oerr) => msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details),
  }
}

# ---- Convenience builders for HandlerResult ----------------------
fn ok(payload :: jv.Json) -> HandlerResult {
  HOk(payload)
}

fn fail(oerr :: oe.OcppError) -> HandlerResult {
  HErr(oerr)
}

fn fail_with(code :: Str, description :: Str) -> HandlerResult {
  HErr(oe.err(code, description))
}

# ---- Raw-frame entry point ---------------------------------------
#
# Given a raw wire string, parse + dispatch + serialize in one shot.
# Errors at every stage (parse, dispatch) are surfaced as CallError
# frames on a *best-effort* basis: if the parse failed so badly we
# can't recover a message_id, we return Err and let the transport
# decide whether to drop or close the connection.
fn handle_raw(reg :: Registry, raw :: Str) -> Result[Str, msg.FrameError] {
  match msg.parse(raw) {
    Err(fe) => Err(fe),
    Ok(f) => Ok(msg.encode(dispatch(reg, f))),
  }
}

