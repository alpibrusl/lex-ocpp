# lex-ocpp

OCPP (Open Charge Point Protocol) library for the
[Lex language](https://github.com/alpibrusl/lex-lang), in the spirit of
[mobilityhouse/ocpp](https://github.com/mobilityhouse/ocpp): the same
shape — Call / CallResult / CallError framing, separate action catalogs
for OCPP 1.6 and 2.0.1, handler-registry dispatch — reworked for Lex's
effect system, variant ADTs, and pure-core / effect-edge split.

Built on top of [lex-schema](https://github.com/alpibrusl/lex-schema) for
payload validation, and designed to pair cleanly with
[lex-web](https://github.com/alpibrusl/lex-web)'s `ws.serve` for the WebSocket
transport. Requires **lex-lang 0.9.1+** for native WebSocket support
(`net.serve_ws_fn`).

## Build status

Every file under `src/`, `tests/`, `examples/`, and `tools/` passes
`lex check`, and every test suite returns 0 failures, against a
tip-of-tree `lex` binary built from this repo's stable lex-lang
sibling:

```
src/messages.lex          ok
src/error.lex             ok
src/route.lex             ok
src/route_io.lex          ok
src/charge_point.lex      ok
src/charge_point_io.lex   ok
src/v16/*.lex             ok
src/v201/*.lex            ok
tools/gen.lex             ok
tests/*.lex               ok  → 0 failures across 7 suites (~91 cases)
examples/*.lex            ok
```

**One upstream blocker for downstream consumers:**
[`lex-lang#391`](https://github.com/alpibrusl/lex-lang/issues/391) — a name
resolution bug in `examples { }` blocks fires when `lex-schema/src/schema.lex`
is imported across package boundaries. Three of lex-schema's `examples`
blocks reference local top-level fns that fail to resolve at import time;
all three transitively break any downstream that does
`import "lex-schema/schema" as s`. Verified by running the lex-ocpp test
suite against a locally-patched lex-schema (examples block on line 99
commented out). Both lex-orm's `tests/test_query.lex` and lex-ocpp hit
the same root cause.

Once that lands (either upstream fix in lex-lang, or stopgap in lex-schema),
lex-ocpp compiles cleanly against vanilla `lex 0.9.1` + the published
lex-schema with **zero workarounds in source.**

## What it ships

- **Wire framing** (`src/messages.lex`). Parse and encode OCPP-J
  frames `[2, MessageId, Action, Payload]` / `[3, …]` / `[4, …]` with
  total error handling — every malformed input surfaces as a
  `FrameError`, never a VM panic.
- **OCPP error codes** (`src/error.lex`). Wire-exact constants for both
  the v1.6 (`OccurenceConstraintViolation`, `FormationViolation`) and
  v2.0.1 spellings (`OccurrenceConstraintViolation`, `FormatViolation`,
  plus the v2.0.1 additions `RpcFrameworkError`, `MessageTypeNotSupported`).
- **Handler registry + dispatch** (`src/route.lex`). Register pure
  handlers by action name; an optional per-action validator runs *before*
  the handler and surfaces every failing field at once as a
  `PropertyConstraintViolation`.
- **`ChargePoint` façade** (`src/charge_point.lex`). Mobilityhouse-style
  bundle of identity + version + registry, with `handle_raw(cp, frame_str)`
  for end-to-end wire→wire dispatch.
- **OCPP 1.6 surface** (`src/v16/`). Full action catalog (`action.lex`),
  20+ enums (`enums.lex`), shared datatypes (`datatypes.lex` —
  IdTagInfo, MeterValue, ChargingProfile, …), and `lex-schema` validators
  for all 10 CP→CS request payloads plus 9 of the most-implemented
  CS→CP request payloads.
- **OCPP 2.0.1 surface** (`src/v201/`). Full action catalog (~64 actions
  across both directions), the most-referenced enums, and validators for
  the 10 highest-traffic Calls (BootNotification, Heartbeat, Authorize,
  StatusNotification, TransactionEvent, MeterValues, DataTransfer,
  FirmwareStatusNotification, SecurityEventNotification, Reset,
  RequestStartTransaction, RequestStopTransaction, TriggerMessage,
  ChangeAvailability).
- **Four runnable examples**: a complete v1.6 CSMS, a v2.0.1 CSMS,
  an in-process stateful CSMS with effectful handlers, and a
  frame-construction demo for the charger side.
- **JSON Schema → Lex codegen** (`tools/gen.lex`). Reads a JSON
  Schema document and emits a matching `ModelSchema` + validator
  wrapper. Demonstrates the pattern for bulk-generating the
  remaining v2.0.1 surface from the OCA's published schemas.
- **Two dispatch paths**: a pure `route.dispatch` for tests and
  deterministic replay, and an effectful `route_io.dispatch` with
  upper bound `[io, time, sql]` so handlers can log, timestamp,
  and persist via lex-orm.

## Quickstart

```lex
import "lex-ocpp/messages"      as msg
import "lex-ocpp/charge_point"  as cp
import "lex-ocpp/route"         as route
import "lex-ocpp/v16/action"    as a
import "lex-ocpp/v16/enums"     as en
import "lex-ocpp/v16/schemas"   as sch

import "lex-schema/json_value"  as jv

# Handlers are pure — payload in, response payload out.
fn on_boot(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([
    ("currentTime", JStr("2026-05-13T12:00:00Z")),
    ("interval",    JInt(300)),
    ("status",      JStr(en.reg_accepted())),
  ]))
}

fn on_heartbeat(_payload :: jv.Json) -> route.HandlerResult {
  route.ok(JObj([("currentTime", JStr("2026-05-13T12:00:00Z"))]))
}

# Build a ChargePoint (mobilityhouse's namesake class equivalent).
# Schema validation runs *before* the handler — malformed payloads
# never reach handler bodies.
fn central_system() -> cp.ChargePoint {
  cp.new_v16("csms-example")
    |> fn (c) { cp.handler_with_schema(c, a.boot_notification(),
                  sch.validate_boot_notification_req, on_boot) }
    |> fn (c) { cp.handler_with_schema(c, a.heartbeat(),
                  sch.validate_heartbeat_req, on_heartbeat) }
}

# Wire→wire dispatch — feed a raw inbound frame, get back the
# encoded response (CallResult or CallError).
fn reply(raw :: Str) -> Result[Str, msg.FrameError] {
  cp.handle_raw(central_system(), raw)
}
```

Run it over a real WebSocket with lex-web (full source in
`examples/csms_v16.lex`):

```bash
lex run --allow-effects net,io,time examples/csms_v16.lex main
# CSMS v1.6  ws://localhost:9000/ocpp/<charger-id>
# registered actions: BootNotification, Heartbeat, ...
```

## Repository layout

```
lex.toml                  package manifest (lex 0.9.1+)
src/
  messages.lex            Call / CallResult / CallError framing
  error.lex               OCPP error codes + OcppError ADT
  route.lex               Pure handler registry + dispatch
  route_io.lex            Effectful registry + dispatch ([io, time, sql])
  charge_point.lex        mobilityhouse-style ChargePoint façade (pure)
  charge_point_io.lex     Effectful ChargePoint façade
  v16/
    action.lex            All 29 OCPP 1.6 action names
    enums.lex             AuthorizationStatus, ChargePointStatus, …
    datatypes.lex         IdTagInfo, MeterValue, ChargingProfile, …
    schemas.lex           lex-schema validators per action (19)
  v201/
    action.lex            All 64 OCPP 2.0.1 action names
    enums.lex             BootReason, IdTokenType, TransactionEvent, …
    schemas.lex           lex-schema validators (22 actions)
tools/
  gen.lex                 JSON Schema → lex-schema codegen
tests/
  test_messages.lex
  test_error.lex
  test_route.lex
  test_route_io.lex       (v0.2) effectful dispatch
  test_v16_schemas.lex
  test_v201_schemas.lex
  test_gen.lex            (v0.2) codegen tool
examples/
  csms_v16.lex            Full v1.6 CSMS over WebSocket (pure handlers)
  csms_v16_stateful.lex   (v0.2) in-process CSMS with [io] handlers
  csms_v201.lex           v2.0.1 CSMS over WebSocket
  charger_frames.lex      Frame construction demo (no transport)
```

## Design

### Pure-core, effect-edge

The dispatcher is pure. Frame parsing, validation, handler lookup,
and response construction never touch `[io]`, `[net]`, or `[time]`.
Effects live at the transport boundary: the WS-server adapter in your
`main()` function declares `[net, io, time]` and calls into the pure
core.

This is the same pattern lex-web uses (`dispatch_pure` vs `dispatch`)
and lex-schema uses (validators are pure folds). It makes the library
fully testable without a transport, and lets users compose the core
with whatever transport / persistence layer they prefer:

```lex
fn on_message(_conn :: WsConn, m :: WsMessage) -> WsAction {
  match m {
    WsText(raw) => match cp.handle_raw(central_system(), raw) {
      Ok(out) => WsSend(out),
      Err(fe) => WsSend(msg.encode(msg.new_call_error(
                   "", fe.code, fe.message, JObj([])))),
    },
    _ => WsNoOp,
  }
}
```

### Constraints as variants, not closures

OCPP enums (AuthorizationStatus, ChargePointStatus, RegistrationStatus,
…) are exposed as `fn name() -> Str` constants and reflected at the
validation boundary via lex-schema's `StrOneOf(all_xxx())`. Three
concrete payoffs over closure-based validation:

1. **Inspectable by `lex audit`.** `lex audit --calls StrOneOf` lists
   every enum-bounded field in your codebase. Closures vanish.
2. **Codegen-friendly.** Pass any of these schemas to
   `lex-schema/sdk` and get TypeScript / Python / Rust / SQL DDL
   for free — the OCPP datatypes round-trip through the same pipeline
   as any other validated payload.
3. **Cheaper.** A variant is a tagged record; a closure carries
   captures plus an indirect call.

Extension is open: add a `StrOneOf(["MyCustomStatus"])` constraint to
your validator without forking lex-ocpp. The wire format already lets
vendors extend the enum surface (OCPP 1.6 §3.4), so a closed Lex sum
would be the wrong shape.

### Validators accumulate, not short-circuit

A malformed BootNotification payload returns *every* failing field at
once — not the first one. This matches FastAPI / pydantic's
`ValidationError` shape: a UI rendering the response can highlight
every failing field in a single pass, not require N round-trips.

```
PropertyConstraintViolation {
  violations: [
    { path: "chargePointVendor", code: "min_len",
      message: "must be at least 1 characters" },
    { path: "chargePointModel",  code: "max_len",
      message: "must be at most 20 characters" },
  ]
}
```

### One framework, two spec versions

OCPP 1.6 and 2.0.1 share the same wire-level RPC framework (Call /
CallResult / CallError) but use different action catalogs, different
spellings of a couple of error codes, and (for some actions) different
payload shapes. lex-ocpp:

- shares `src/messages.lex` and `src/route.lex` between versions,
- exposes both `src/v16/` and `src/v201/` action / enum / schema
  catalogs,
- exposes both `OccurenceConstraintViolation` (1.6) and
  `OccurrenceConstraintViolation` + `FormatViolation` (2.0.1) in
  `src/error.lex` so handler code reads naturally on either side.

To run both versions side-by-side, declare two `ChargePoint` values
(`cp.new_v16(...)` and `cp.new_v201(...)`) and serve them on different
ports / subprotocols.

## What's not in v0.1

- **Outbound calls from the CSMS side.** lex-web's `ws.serve` is
  callback-driven; the handler is pure and can't initiate a
  CSMS→CP Call mid-session without a connection registry that
  the lex-web layer doesn't yet expose. The framing layer
  supports outbound calls (`messages.new_call`), so the missing
  piece is purely transport. Tracked at:
  - [lex-web: outbound WebSocket send](https://github.com/alpibrusl/lex-web/issues)
    (an issue we filed against lex-web)

- **WebSocket client.** lex-lang ships `net.serve_ws_fn` (server) but
  not a client. A charger-simulator running entirely inside Lex would
  need either a `net.dial_ws` builtin or a thin Rust shim. Tracked at:
  - [lex-lang: WebSocket client (`net.dial_ws`)](https://github.com/alpibrusl/lex-lang/issues)
    (an issue we filed against lex-lang)

- ~~**Stateful handlers.**~~ ✅ shipped in v0.2 — see
  `src/route_io.lex` and `src/charge_point_io.lex`. Effectful
  handlers carry an upper bound of `[io, time, sql]` so they can
  log via `io.print`, stamp responses with timestamps, and persist
  via lex-orm's `[sql]`-flavored `q.run_*`. Pure handlers fit too —
  `[io, time, sql]` is an upper bound, not a requirement.
  `examples/csms_v16_stateful.lex` walks the pattern end-to-end.

- ~~**Code generation from official JSON Schemas.**~~ ✅ scaffolded
  in v0.2 — see `tools/gen.lex`. Reads a JSON Schema (top-level
  `type: object` with `properties` / `required` / `enum` /
  `minLength` / `maxLength` / `minimum` / `maximum` / `minItems`) and
  emits a matching `s.ModelSchema` value + `validate_<action>`
  wrapper. Coverage of more advanced JSON Schema constructs
  (`$ref`, `oneOf` / `anyOf`, `pattern`, format hints) is open
  follow-up. Eight tests pin the generator's output in
  `tests/test_gen.lex`.

- **Security profiles 1-3.** TLS + Basic Auth, TLS + Mutual Auth,
  certificate provisioning. The frame-level work is in place
  (SecurityEventNotification, SignCertificate validators); the
  transport-side TLS and cert plumbing live outside lex-ocpp.

## Effect system

The pure path is fully effect-free; the effectful path declares a
fixed upper bound:

| Function                            | Effects |
|-------------------------------------|---------|
| `messages.parse` / `encode`         | none |
| `route.dispatch` / `handle_raw`     | none |
| `charge_point.handle_raw`           | none |
| `route_io.dispatch` / `handle_raw`  | `[io, time, sql]` |
| `charge_point_io.handle_raw`        | `[io, time, sql]` |
| `tools/gen.generate`                | none |
| `examples/csms_v16.main`            | `[net, io, time]` |
| `examples/csms_v16_stateful.main`   | `[io, time, sql]` |
| handler bodies (pure registry)      | none |
| handler bodies (IO registry)        | ⊆ `[io, time, sql]` (upper bound) |

The pure `src/` modules + pure tests run without any
`--allow-effects` flag. The effectful test suite (`test_route_io.lex`)
runs with `--allow-effects io,sql,time`.

## Tests

```bash
for f in tests/test_*.lex; do
  echo -n "$(basename $f): "
  if [[ "$f" == *"_io"* ]]; then
    lex run --allow-effects io,sql,time "$f" run_all
  else
    lex run "$f" run_all
  fi
done
# test_error.lex:         0
# test_gen.lex:           0
# test_messages.lex:      0
# test_route.lex:         0
# test_route_io.lex:      0
# test_v16_schemas.lex:   0
# test_v201_schemas.lex:  0
```

(Reference output: every line ends in `0`, meaning no failing cases —
seven suites, ~91 cases.)

Each suite exports `run_all() -> Int` returning the count of failing
cases. Pure suites need no effect grants; the effectful suite
(`test_route_io.lex`) runs handlers under `[io, time, sql]`.

## Running the examples

```bash
# Full v1.6 CSMS (point any OCPP 1.6J charger at ws://localhost:9000/ocpp/<id>)
lex run --allow-effects net,io,time examples/csms_v16.lex main

# v2.0.1 CSMS on port 9001
lex run --allow-effects net,io,time examples/csms_v201.lex main

# Charger-side frame construction demo (no network)
lex run --allow-effects io examples/charger_frames.lex main
```

Pair the CSMS with [mobilityhouse/ocpp's charge-point
example](https://github.com/mobilityhouse/ocpp/tree/master/examples)
to drive a real session end-to-end.

## Issues filed against the ecosystem

While building lex-ocpp, the following gaps came up in the surrounding
projects. Each is tracked at the corresponding upstream repo:

| Upstream | Topic |
|---|---|
| lex-web   | Outbound WebSocket send on an open connection (CSMS→CP Calls) |
| lex-lang  | WebSocket client (`net.dial_ws` / closure-driven `Iter[Frame]`) |

The library compiles and runs against vanilla `lex 0.9.1` + lex-schema
+ lex-web today — neither item blocks v0.1.

## Pairing with lex-orm

OCPP CSMS implementations almost always persist transactions, meter
values, and authorization caches. [lex-orm](https://github.com/alpibrusl/lex-orm)
fits naturally on top of lex-ocpp: write your handlers as pure
`(jv.Json) -> HandlerResult`, then wrap them in an effectful adapter
that calls `lex-orm`'s `[sql]`-flavored helpers. Because the OCPP
payload schemas are `lex-schema` `ModelSchema` values, you can also
drive lex-orm's `Repo[T]` off the same schema:

```lex
fn boot_notification_repo() -> q.Repo[BootRecord] {
  q.for_schema(sch.boot_notification_req_schema(), decode_boot_record)
}
```

One `ModelSchema` → request validation + table DDL + INSERT statements.
A worked example with the same shape lives in lex-web's
`examples/with_lex_orm.lex` — adapt the pattern for OCPP handlers
that need persistence.

## License

[EUPL-1.2](LICENSE) — to match the parent lex-lang ecosystem.
