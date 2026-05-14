# lex-ocpp — ChargePoint façade (effectful variant)
#
# Sibling to `charge_point.lex`. Same shape, but wraps `route_io.IORegistry`
# instead of `route.Registry` so handlers can declare `[io, time, sql]`
# effects (logging, timestamps, lex-orm persistence).
#
# Use this when your handler bodies need to log, generate timestamps,
# or read/write a SQL store. For a fully pure CSMS (tests, deterministic
# replay), keep using `charge_point.lex`.

import "std.str" as str

import "lex-schema/json_value" as jv

import "./messages"      as msg
import "./route"         as route
import "./route_io"      as route_io
import "./charge_point"  as cp

# ---- IOChargePoint datatype --------------------------------------

type IOChargePoint = {
  id       :: Str,
  version  :: Str,
  registry :: route_io.IORegistry,
}

# ---- Constructors -----------------------------------------------

fn new(id :: Str, version :: Str) -> IOChargePoint {
  { id: id, version: version, registry: route_io.new() }
}

fn new_v16(id :: Str)  -> IOChargePoint { new(id, cp.version_v16()) }
fn new_v201(id :: Str) -> IOChargePoint { new(id, cp.version_v201()) }
fn new_v21(id :: Str)  -> IOChargePoint { new(id, cp.version_v21()) }

# ---- Handler registration ---------------------------------------

fn handler(
  c      :: IOChargePoint,
  action :: Str,
  h      :: (jv.Json) -> [io, time, sql] route.HandlerResult
) -> IOChargePoint {
  with_registry(c, route_io.handler(c.registry, action, h))
}

fn handler_with_schema(
  c         :: IOChargePoint,
  action    :: Str,
  validator :: (jv.Json) -> Result[jv.Json, List[{path :: Str, code :: Str, message :: Str}]],
  h         :: (jv.Json) -> [io, time, sql] route.HandlerResult
) -> IOChargePoint {
  with_registry(c, route_io.handler_with_schema(c.registry, action, validator, h))
}

fn with_unknown(
  c  :: IOChargePoint,
  fb :: (Str, jv.Json) -> [io, time, sql] route.HandlerResult
) -> IOChargePoint {
  with_registry(c, route_io.with_unknown(c.registry, fb))
}

fn with_registry(c :: IOChargePoint, reg :: route_io.IORegistry) -> IOChargePoint {
  { id: c.id, version: c.version, registry: reg }
}

# ---- Dispatch entry points ---------------------------------------

fn dispatch(c :: IOChargePoint, frame :: msg.Frame) -> [io, time, sql] msg.Frame {
  route_io.dispatch(c.registry, frame)
}

fn handle_raw(
  c   :: IOChargePoint,
  raw :: Str
) -> [io, time, sql] Result[Str, msg.FrameError] {
  route_io.handle_raw(c.registry, raw)
}

# ---- Introspection ----------------------------------------------

fn actions(c :: IOChargePoint) -> List[Str] {
  route_io.actions(c.registry)
}

fn describe(c :: IOChargePoint) -> Str {
  str.concat("IOChargePoint{id=",
    str.concat(c.id,
      str.concat(", version=", str.concat(c.version, "}"))))
}

# ---- Outbound connection (charge-point → CSMS) -------------------

# Connect this charge point outbound to a CSMS over WebSocket.
# `url` is the CSMS endpoint, e.g. "wss://csms.example.com/ocpp/CP001".
# `on_open` fires once after the handshake — return a WsAction to send
# the BootNotification frame immediately, or WsNoOp to defer.
# `on_message` is called for every inbound frame from the CSMS; return
# a WsAction reply. Use `handle_raw` to route through the registry:
#
#   fn on_msg(msg :: WsMessage) -> [io, time, sql] WsAction {
#     match msg {
#       WsText(frame) =>
#         match cp_io.handle_raw(cp, frame) {
#           Ok(reply) => WsSend(reply),
#           Err(_)    => WsNoOp,
#         },
#       WsClose => WsNoOp,
#       _       => WsNoOp,
#     }
#   }
#
# Returns Err(Str) if the connection or TLS handshake fails.
fn dial[E](
  c           :: IOChargePoint,
  url         :: Str,
  on_open     :: () -> [E] WsAction,
  on_message  :: (WsMessage) -> [E] WsAction
) -> [net, E] Result[Unit, Str] {
  net.dial_ws(url, c.version, on_open, on_message)
}
