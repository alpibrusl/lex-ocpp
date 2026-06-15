# lex-ocpp — handler registry + dispatch (effectful variant)
#
# Sibling to `route.lex`. Same shape, but handlers carry an effect
# upper bound of `[io, time, sql]` so they can:
#   - log via `io.print(...)`,
#   - timestamp responses via `time.now(...)`,
#   - persist via lex-orm's `[sql]`-flavored `q.run_*`.
#
# Pure handlers fit too — `[io, time, sql]` is an upper bound, not
# a requirement. Use `route.dispatch` if you want a zero-effect
# guarantee (tests, deterministic replay); use `route_io.dispatch`
# when you need to wire OCPP into a real CSMS.
#
# Validators stay pure. They're folds over JSON and don't need
# effects — if a downstream needs an effectful pre-check (e.g.,
# look up an idTag in the DB before passing to the handler), wire
# that into the handler body, not the validator.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "./messages" as msg

import "./error" as oe

import "./route" as route

# ---- Handler types -----------------------------------------------
# Effectful handler upper bound. Covers logging ([io]), timestamps
# ([time]), and lex-orm persistence ([sql]). Handlers with strictly
# fewer effects (e.g., a pure handler or [io]-only) fit by
# subsumption — the type checker accepts any function whose
# declared effects ⊆ {io, time, sql}.
#
# Handlers needing additional effects (`[fs_read]`, `[net]`, …)
# can wrap their own dispatch on top of `route.dispatch`.
# ---- Registry datatype -------------------------------------------
#
# We re-use `route.HandlerResult` so handler bodies that switch
# between pure and IO registries share the same return type.
type IORouteEntry = { action :: Str, validator :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]], handler :: (jv.Json) -> [io, time, sql] route.HandlerResult }

type IORegistry = { routes :: List[IORouteEntry], on_unknown :: (Str, jv.Json) -> [io, time, sql] route.HandlerResult }

# ---- Registry construction ---------------------------------------
fn new() -> IORegistry {
  { routes: [], on_unknown: default_unknown }
}

# Default fallback — same NotImplemented response as the pure path.
# Declared with the IO upper bound so it fits the IORegistry shape.
fn default_unknown(action :: Str, _payload :: jv.Json) -> [io, time, sql] route.HandlerResult {
  HErr(oe.not_implemented_err(action))
}

fn with_unknown(reg :: IORegistry, fb :: (Str, jv.Json) -> [io, time, sql] route.HandlerResult) -> IORegistry {
  { routes: reg.routes, on_unknown: fb }
}

fn handler(reg :: IORegistry, action :: Str, h :: (jv.Json) -> [io, time, sql] route.HandlerResult) -> IORegistry {
  add_entry(reg, { action: action, validator: None, handler: h })
}

fn handler_with_schema(reg :: IORegistry, action :: Str, validator :: (jv.Json) -> Result[jv.Json, List[e.Error]], h :: (jv.Json) -> [io, time, sql] route.HandlerResult) -> IORegistry {
  add_entry(reg, { action: action, validator: Some(validator), handler: h })
}

fn add_entry(reg :: IORegistry, entry :: IORouteEntry) -> IORegistry {
  { routes: list.concat(reg.routes, [entry]), on_unknown: reg.on_unknown }
}

# ---- Lookup ------------------------------------------------------
fn find(reg :: IORegistry, action :: Str) -> Option[IORouteEntry] {
  list.fold(reg.routes, None, fn (acc :: Option[IORouteEntry], entry :: IORouteEntry) -> Option[IORouteEntry] {
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

fn actions(reg :: IORegistry) -> List[Str] {
  list.map(reg.routes, fn (entry :: IORouteEntry) -> Str {
    entry.action
  })
}

# ---- Dispatch ----------------------------------------------------
fn dispatch(reg :: IORegistry, frame :: msg.Frame) -> [io, time, sql] msg.Frame {
  match frame {
    FrameCall(c) => dispatch_call(reg, c),
    FrameCallResult(_) => frame,
    FrameCallError(_) => frame,
  }
}

fn dispatch_call(reg :: IORegistry, c :: { message_id :: Str, action :: Str, payload :: jv.Json }) -> [io, time, sql] msg.Frame {
  match find(reg, c.action) {
    None => result_from_handler(c.message_id, reg.on_unknown(c.action, c.payload)),
    Some(entry) => run_entry(c.message_id, entry, c.payload),
  }
}

fn run_entry(message_id :: Str, entry :: IORouteEntry, payload :: jv.Json) -> [io, time, sql] msg.Frame {
  match entry.validator {
    None => result_from_handler(message_id, entry.handler(payload)),
    Some(vf) => match vf(payload) {
      Err(es) => result_from_handler(message_id, HErr(oe.from_schema_errors(es))),
      Ok(normalized) => result_from_handler(message_id, entry.handler(normalized)),
    },
  }
}

fn result_from_handler(message_id :: Str, hr :: route.HandlerResult) -> msg.Frame {
  match hr {
    HOk(payload) => msg.new_call_result(message_id, payload),
    HErr(oerr) => msg.new_call_error(message_id, oerr.code, oerr.description, oerr.details),
  }
}

# ---- Raw-frame entry point ---------------------------------------
fn handle_raw(reg :: IORegistry, raw :: Str) -> [io, time, sql] Result[Str, msg.FrameError] {
  match msg.parse(raw) {
    Err(fe) => Err(fe),
    Ok(f) => Ok(msg.encode(dispatch(reg, f))),
  }
}

