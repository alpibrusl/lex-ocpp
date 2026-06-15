# lex-ocpp — ChargePoint façade
#
# Mobilityhouse's `ChargePoint` class bundles a charge-point identity,
# the chosen OCPP version, and a registry of message handlers. We
# match that shape with a value: callers build a `ChargePoint`,
# wire handlers into the embedded registry, and hand it to whatever
# transport adapter they like.
#
# This module is pure. The transport (WebSocket, HTTP, in-process
# loopback) supplies the effects.

import "std.str" as str

import "./messages" as msg

import "./route" as route

# ---- Identity + version ------------------------------------------
# Stable string tags for the supported OCPP versions. The strings
# match the WebSocket subprotocol identifiers exactly, so the same
# constant configures both the CP value and the WS handshake.
fn version_v16() -> Str {
  "ocpp1.6"
}

fn version_v201() -> Str {
  "ocpp2.0.1"
}

fn version_v21() -> Str {
  "ocpp2.1"
}

# ---- ChargePoint datatype ----------------------------------------
type ChargePoint = { id :: Str, version :: Str, registry :: route.Registry }

fn new(id :: Str, version :: Str) -> ChargePoint {
  { id: id, version: version, registry: route.new() }
}

# Convenience constructors that pre-pick the version.
fn new_v16(id :: Str) -> ChargePoint {
  new(id, version_v16())
}

fn new_v201(id :: Str) -> ChargePoint {
  new(id, version_v201())
}

fn new_v21(id :: Str) -> ChargePoint {
  new(id, version_v21())
}

# ---- Handler registration (delegates to route.Registry) ----------
fn handler(cp :: ChargePoint, action :: Str, h :: route.Handler) -> ChargePoint {
  with_registry(cp, route.handler(cp.registry, action, h))
}

fn handler_with_schema(cp :: ChargePoint, action :: Str, validator :: route.Validator, h :: route.Handler) -> ChargePoint {
  with_registry(cp, route.handler_with_schema(cp.registry, action, validator, h))
}

fn with_unknown(cp :: ChargePoint, fb :: route.Fallback) -> ChargePoint {
  with_registry(cp, route.with_unknown(cp.registry, fb))
}

fn with_registry(cp :: ChargePoint, reg :: route.Registry) -> ChargePoint {
  { id: cp.id, version: cp.version, registry: reg }
}

# ---- Dispatch entry points ---------------------------------------
# Pass a parsed frame through the registry. Same semantics as
# `route.dispatch`; the CP value is a thin wrapper that carries id
# and version for diagnostics / logging.
fn dispatch(cp :: ChargePoint, frame :: msg.Frame) -> msg.Frame {
  route.dispatch(cp.registry, frame)
}

# End-to-end: raw wire string → response wire string.
fn handle_raw(cp :: ChargePoint, raw :: Str) -> Result[Str, msg.FrameError] {
  route.handle_raw(cp.registry, raw)
}

# ---- Introspection ----------------------------------------------
fn actions(cp :: ChargePoint) -> List[Str] {
  route.actions(cp.registry)
}

fn describe(cp :: ChargePoint) -> Str {
  str.concat("ChargePoint{id=", str.concat(cp.id, str.concat(", version=", str.concat(cp.version, "}"))))
}

