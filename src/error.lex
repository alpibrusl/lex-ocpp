# lex-ocpp — OCPP error codes + CallError builders
#
# OCPP-J defines a small fixed catalog of error codes a receiver
# returns to the sender when an inbound Call cannot be processed.
# This module exposes them as string constants and ships an
# `OcppError` ADT for ergonomic error construction inside handlers.
#
# Spec references:
#   OCPP 1.6: §4.2 (RPC framework — error codes)
#   OCPP 2.0.1: Part 4 §4.2.3 (subtle rename:
#               OccurenceConstraintViolation → OccurrenceConstraintViolation
#               FormationViolation         → FormatViolation)
#
# Both spellings are exposed; the v16 / v201 facades re-export the
# version-appropriate names so handler code reads naturally.
#
# Effects: none.

import "std.str"  as str
import "std.list" as list

import "lex-schema/json_value" as jv

# ---- Wire-level error code strings -------------------------------
#
# Constants are the *exact* strings the spec requires on the wire.
# We expose them as `fn () -> Str` so callers can refer to them
# with parens (preventing accidental typos at the call site).

fn not_implemented()                  -> Str { "NotImplemented" }
fn not_supported()                    -> Str { "NotSupported" }
fn internal_error()                   -> Str { "InternalError" }
fn protocol_error()                   -> Str { "ProtocolError" }
fn security_error()                   -> Str { "SecurityError" }
fn generic_error()                    -> Str { "GenericError" }

# OCPP 1.6 spelling.
fn formation_violation()              -> Str { "FormationViolation" }
fn occurence_constraint_violation()   -> Str { "OccurenceConstraintViolation" }
fn property_constraint_violation()    -> Str { "PropertyConstraintViolation" }
fn type_constraint_violation()        -> Str { "TypeConstraintViolation" }

# OCPP 2.0.1 spelling (the spec corrected the original typo).
fn format_violation()                 -> Str { "FormatViolation" }
fn occurrence_constraint_violation()  -> Str { "OccurrenceConstraintViolation" }

# OCPP 2.0.1 additions.
fn rpc_framework_error()              -> Str { "RpcFrameworkError" }
fn message_type_not_supported()       -> Str { "MessageTypeNotSupported" }

# ---- All v1.6 / v2.0.1 catalogs as lists -------------------------
#
# Useful for schema validation (StrOneOf), property tests, and
# documentation generators.

fn all_v16() -> List[Str] {
  [
    not_implemented(),
    not_supported(),
    internal_error(),
    protocol_error(),
    security_error(),
    formation_violation(),
    property_constraint_violation(),
    occurence_constraint_violation(),
    type_constraint_violation(),
    generic_error(),
  ]
}

fn all_v201() -> List[Str] {
  [
    not_implemented(),
    not_supported(),
    internal_error(),
    protocol_error(),
    security_error(),
    format_violation(),
    property_constraint_violation(),
    occurrence_constraint_violation(),
    type_constraint_violation(),
    generic_error(),
    rpc_framework_error(),
    message_type_not_supported(),
  ]
}

# ---- OcppError ADT -----------------------------------------------
#
# Handlers return `OcppError` values; the dispatcher converts them
# to wire-level CallError frames. Carrying the details as a `Json`
# means callers can attach arbitrary diagnostic context without
# committing to a particular shape.

type OcppError = {
  code        :: Str,
  description :: Str,
  details     :: jv.Json,
}

fn err(code :: Str, description :: Str) -> OcppError {
  { code: code, description: description, details: JObj([]) }
}

fn err_with(code :: Str, description :: Str, details :: jv.Json) -> OcppError {
  { code: code, description: description, details: details }
}

# ---- Common helpers ----------------------------------------------

fn not_implemented_err(action :: Str) -> OcppError {
  err(not_implemented(),
    str.concat("action not implemented: ", action))
}

fn not_supported_err(action :: Str) -> OcppError {
  err(not_supported(),
    str.concat("action not supported: ", action))
}

fn internal_err(description :: Str) -> OcppError {
  err(internal_error(), description)
}

fn protocol_err(description :: Str) -> OcppError {
  err(protocol_error(), description)
}

# Build a property-constraint error whose details list every field
# that violated its constraint. Reuses lex-schema's error shape:
# each entry is `{ path, code, message }`.
fn from_schema_errors(es :: List[{ path :: Str, code :: Str, message :: Str }]) -> OcppError {
  let entries := list.map(es, fn (e :: { path :: Str, code :: Str, message :: Str }) -> jv.Json {
    JObj([
      ("path",    JStr(e.path)),
      ("code",    JStr(e.code)),
      ("message", JStr(e.message)),
    ])
  })
  err_with(property_constraint_violation(),
    "request payload failed schema validation",
    JObj([("violations", JList(entries))]))
}
