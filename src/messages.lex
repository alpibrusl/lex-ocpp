# lex-ocpp — frame messaging (Call / CallResult / CallError)
#
# Encodes and decodes the OCPP-J wire format. Every OCPP frame is a
# JSON array whose first element is a numeric MessageType:
#
#   [2, "<MessageId>", "<Action>",     <Payload>]                   Call
#   [3, "<MessageId>",                 <Payload>]                   CallResult
#   [4, "<MessageId>", "<ErrorCode>",  "<Description>", <Details>]  CallError
#
# The same shape applies to every OCPP-J version (1.5 / 1.6 / 2.0.x
# / 2.1). This module is transport- and version-agnostic; callers
# layer action catalogues and per-action schemas on top.
#
# Effects: none. Parse / encode are pure folds over strings.

import "std.str"  as str
import "std.int"  as int
import "std.list" as list

import "lex-schema/json_value" as jv

# ---- Wire-level constants -----------------------------------------

fn type_call() -> Int        { 2 }
fn type_call_result() -> Int { 3 }
fn type_call_error() -> Int  { 4 }

# ---- Frame ADT ----------------------------------------------------
#
# A parsed frame is one of three variants. The payload / details are
# kept as a `jv.Json` so callers can lazily validate against the
# action's schema (see src/route.lex + src/v16/schemas.lex).

type Frame =
    FrameCall({
      message_id :: Str,
      action     :: Str,
      payload    :: jv.Json,
    })
  | FrameCallResult({
      message_id :: Str,
      payload    :: jv.Json,
    })
  | FrameCallError({
      message_id  :: Str,
      error_code  :: Str,
      description :: Str,
      details     :: jv.Json,
    })

# ---- Frame-level parse failure -----------------------------------
#
# Frame-level failures are *protocol* failures (bad JSON, wrong
# arity, wrong types in fixed positions). These map cleanly to the
# OCPP `ProtocolError` / `FormationViolation` error codes — the
# caller decides which one to surface to the peer.

type FrameError = {
  code    :: Str,
  message :: Str,
}

fn frame_err(code :: Str, message :: Str) -> FrameError {
  { code: code, message: message }
}

# ---- Constructors ------------------------------------------------

fn new_call(message_id :: Str, action :: Str, payload :: jv.Json) -> Frame {
  FrameCall({ message_id: message_id, action: action, payload: payload })
}

fn new_call_result(message_id :: Str, payload :: jv.Json) -> Frame {
  FrameCallResult({ message_id: message_id, payload: payload })
}

fn new_call_error(
  message_id  :: Str,
  error_code  :: Str,
  description :: Str,
  details     :: jv.Json
) -> Frame {
  FrameCallError({
    message_id:  message_id,
    error_code:  error_code,
    description: description,
    details:     details,
  })
}

# ---- Encoding -----------------------------------------------------

fn encode(frame :: Frame) -> Str {
  match frame {
    FrameCall(c)        => encode_call(c.message_id, c.action, c.payload),
    FrameCallResult(r)  => encode_call_result(r.message_id, r.payload),
    FrameCallError(err) => encode_call_error(
                             err.message_id, err.error_code,
                             err.description, err.details),
  }
}

fn encode_call(message_id :: Str, action :: Str, payload :: jv.Json) -> Str {
  jv.stringify(JList([
    JInt(type_call()),
    JStr(message_id),
    JStr(action),
    payload,
  ]))
}

fn encode_call_result(message_id :: Str, payload :: jv.Json) -> Str {
  jv.stringify(JList([
    JInt(type_call_result()),
    JStr(message_id),
    payload,
  ]))
}

fn encode_call_error(
  message_id  :: Str,
  error_code  :: Str,
  description :: Str,
  details     :: jv.Json
) -> Str {
  jv.stringify(JList([
    JInt(type_call_error()),
    JStr(message_id),
    JStr(error_code),
    JStr(description),
    details,
  ]))
}

# ---- Parsing ------------------------------------------------------

fn parse(raw :: Str) -> Result[Frame, FrameError] {
  match jv.parse(raw) {
    Err(p) => Err(frame_err("ProtocolError",
      str.concat("invalid JSON: ", p.message))),
    Ok(j)  => parse_frame_json(j),
  }
}

fn parse_frame_json(j :: jv.Json) -> Result[Frame, FrameError] {
  match jv.as_list(j) {
    None     => Err(frame_err("ProtocolError",
      "frame must be a JSON array")),
    Some(xs) => match list.head(xs) {
      None        => Err(frame_err("ProtocolError",
        "frame array is empty")),
      Some(first) => match jv.as_int(first) {
        None    => Err(frame_err("ProtocolError",
          "frame[0] (MessageType) must be a number")),
        Some(t) => dispatch_by_type(t, list.tail(xs)),
      },
    },
  }
}

fn dispatch_by_type(t :: Int, rest :: List[jv.Json]) -> Result[Frame, FrameError] {
  if t == type_call() {
    parse_call_rest(rest)
  } else { if t == type_call_result() {
    parse_call_result_rest(rest)
  } else { if t == type_call_error() {
    parse_call_error_rest(rest)
  } else {
    Err(frame_err("ProtocolError",
      str.concat("unknown MessageType ", int.to_str(t))))
  } } }
}

# ---- Type-2 (Call) — [message_id, action, payload] ---------------

fn parse_call_rest(rest :: List[jv.Json]) -> Result[Frame, FrameError] {
  if list.len(rest) != 3 {
    Err(frame_err("ProtocolError",
      "Call frame must have 4 elements (type, id, action, payload)"))
  } else {
    let mid_o     := list.head(rest)
    let action_o  := list.head(list.tail(rest))
    let payload_o := list.head(list.tail(list.tail(rest)))
    match (mid_o, action_o) {
      (Some(mid_j), Some(action_j)) => match payload_o {
        None       => Err(frame_err("ProtocolError",
          "Call: missing payload")),
        Some(payload) => parse_call_typed(mid_j, action_j, payload),
      },
      _ => Err(frame_err("ProtocolError", "Call: missing field")),
    }
  }
}

fn parse_call_typed(
  mid_j     :: jv.Json,
  action_j  :: jv.Json,
  payload   :: jv.Json
) -> Result[Frame, FrameError] {
  match jv.as_str(mid_j) {
    None      => Err(frame_err("ProtocolError",
      "Call: message_id must be a string")),
    Some(mid) => match jv.as_str(action_j) {
      None         => Err(frame_err("ProtocolError",
        "Call: action must be a string")),
      Some(action) => match jv.as_obj(payload) {
        None    => Err(frame_err("ProtocolError",
          "Call: payload must be an object")),
        Some(_) => Ok(new_call(mid, action, payload)),
      },
    },
  }
}

# ---- Type-3 (CallResult) — [message_id, payload] -----------------

fn parse_call_result_rest(rest :: List[jv.Json]) -> Result[Frame, FrameError] {
  if list.len(rest) != 2 {
    Err(frame_err("ProtocolError",
      "CallResult frame must have 3 elements (type, id, payload)"))
  } else {
    let mid_o     := list.head(rest)
    let payload_o := list.head(list.tail(rest))
    match (mid_o, payload_o) {
      (Some(mid_j), Some(payload)) => match jv.as_str(mid_j) {
        None      => Err(frame_err("ProtocolError",
          "CallResult: message_id must be a string")),
        Some(mid) => match jv.as_obj(payload) {
          None    => Err(frame_err("ProtocolError",
            "CallResult: payload must be an object")),
          Some(_) => Ok(new_call_result(mid, payload)),
        },
      },
      _ => Err(frame_err("ProtocolError", "CallResult: missing field")),
    }
  }
}

# ---- Type-4 (CallError) — [message_id, code, description, details] ----

fn parse_call_error_rest(rest :: List[jv.Json]) -> Result[Frame, FrameError] {
  if list.len(rest) != 4 {
    Err(frame_err("ProtocolError",
      "CallError frame must have 5 elements"))
  } else {
    let mid_o     := list.head(rest)
    let code_o    := list.head(list.tail(rest))
    let desc_o    := list.head(list.tail(list.tail(rest)))
    let details_o := list.head(list.tail(list.tail(list.tail(rest))))
    match (mid_o, code_o) {
      (Some(mid_j), Some(code_j)) => match (desc_o, details_o) {
        (Some(desc_j), Some(details)) => parse_call_error_typed(
                                            mid_j, code_j, desc_j, details),
        _ => Err(frame_err("ProtocolError", "CallError: missing field")),
      },
      _ => Err(frame_err("ProtocolError", "CallError: missing field")),
    }
  }
}

fn parse_call_error_typed(
  mid_j     :: jv.Json,
  code_j    :: jv.Json,
  desc_j    :: jv.Json,
  details   :: jv.Json
) -> Result[Frame, FrameError] {
  match jv.as_str(mid_j) {
    None      => Err(frame_err("ProtocolError",
      "CallError: message_id must be a string")),
    Some(mid) => match jv.as_str(code_j) {
      None       => Err(frame_err("ProtocolError",
        "CallError: error_code must be a string")),
      Some(code) => match jv.as_str(desc_j) {
        None       => Err(frame_err("ProtocolError",
          "CallError: description must be a string")),
        Some(desc) => Ok(new_call_error(mid, code, desc, details)),
      },
    },
  }
}

# ---- Convenience extractors --------------------------------------

fn message_id_of(frame :: Frame) -> Str {
  match frame {
    FrameCall(c)        => c.message_id,
    FrameCallResult(r)  => r.message_id,
    FrameCallError(err) => err.message_id,
  }
}

fn is_call(frame :: Frame) -> Bool {
  match frame { FrameCall(_) => true, _ => false }
}

fn is_call_result(frame :: Frame) -> Bool {
  match frame { FrameCallResult(_) => true, _ => false }
}

fn is_call_error(frame :: Frame) -> Bool {
  match frame { FrameCallError(_) => true, _ => false }
}
