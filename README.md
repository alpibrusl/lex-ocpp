# lex-ocpp

[![CI](https://github.com/alpibrusl/lex-ocpp/actions/workflows/ci.yml/badge.svg)](https://github.com/alpibrusl/lex-ocpp/actions/workflows/ci.yml)

**Part of the [Lex](https://lexlang.org) project** — Energy · [Manifesto](https://lexlang.org/manifesto) · [All packages](https://lexlang.org)

[![CI](https://github.com/alpibrusl/lex-ocpp/actions/workflows/lex.yml/badge.svg?branch=main)](https://github.com/alpibrusl/lex-ocpp/actions/workflows/lex.yml)

## Role in EV Fleet

Pure Lex library providing the charge-point↔CSMS wire protocol for OCPP 1.6, 2.0.1, and 2.1. Within this fleet:

- **lex-csms** uses it as the CSMS (server) — parsing inbound `BootNotification`, `StartTransaction`, `MeterValues`, etc. and dispatching to typed handlers
- **lex-simulator** uses it as the charge-point (client) — building `BootNotification`, `Authorize`, `StartTransaction` frames and sending them over WebSocket
- **lex-charger** uses it for the full single-CP session state machine — framing every step of the charge cycle

Covers OCPP 1.6, 2.0.1, and 2.1 (including DER, battery swap, and TransactionEvent). Pure core — no effects; WebSocket transport wired in by lex-csms and lex-charger.

---

OCPP (Open Charge Point Protocol) library for the
[Lex language](https://github.com/alpibrusl/lex-lang), in the spirit of
[mobilityhouse/ocpp](https://github.com/mobilityhouse/ocpp): the same
shape — Call / CallResult / CallError framing, separate action catalogs
for OCPP 1.6, 2.0.1, and 2.1, handler-registry dispatch — reworked for
Lex's effect system, variant ADTs, and pure-core / effect-edge split.

Built on top of [lex-schema](https://github.com/alpibrusl/lex-schema) for
payload validation, and designed to pair cleanly with
[lex-web](https://github.com/alpibrusl/lex-web)'s `ws.serve` for the
WebSocket transport. Requires **lex-lang 0.9.2+** (cross-package
`examples { }` name resolution + pre-built CI binaries, both landed in
the 0.9.2 release).

## Build status

`lex ci --no-fmt` passes against vanilla `lex 0.10.7` + the published
`lex-schema` with **zero workarounds in source.** Every file under
`src/`, `tests/`, `examples/`, and `tools/` passes `lex check --strict`,
and every test suite returns 0 failures:

```
src/*.lex             ok    (lex check --strict)
src/v16/*.lex         ok
src/v201/*.lex        ok
src/v21/*.lex         ok
tools/gen.lex         ok
tests/test_*.lex      ok    (lex test, 7 suites)
tests/effectful/*.lex 0     (lex run --allow-effects io,sql,time)
examples/*.lex        ok
```

**One remaining upstream knob**:
[`lex-lang#399`](https://github.com/alpibrusl/lex-lang/issues/399) —
`Policy::permissive()` is missing `sql`, so `lex test` can't run the
effectful suite. Sitting in `tests/effectful/` keeps it skipped by the
non-recursive runner; CI runs it via `lex run --allow-effects
io,sql,time` as a separate step. Folds back into `lex ci` once #399
lands.

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
  the highest-traffic Calls (BootNotification, Heartbeat, Authorize,
  StatusNotification, TransactionEvent, MeterValues, DataTransfer,
  FirmwareStatusNotification, SecurityEventNotification, Reset,
  RequestStartTransaction, RequestStopTransaction, TriggerMessage,
  SetChargingProfile, ChangeAvailability, and more — see `schemas.lex`'s
  `all_request_validators` for the full, up-to-date list).
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
    schemas.lex           lex-schema validators (23 actions)
  v21/
    action.lex            All 85+ OCPP 2.1 action names
    enums.lex             v2.0.1 carry-overs + DER / BatterySwap /
                          EnergyTransferMode / TariffChange / PES
    schemas.lex           Validators for 8 carry-overs (incl.
                          SetChargingProfile, whose ChargingSchedulePeriod
                          gains dischargeLimit — the 2.1 Bidirectional
                          Power Transfer / V2G wire field 2.0.1 has no
                          equivalent for) + 14 v2.1 additions
tools/
  gen.lex                 JSON Schema → lex-schema codegen
tests/
  test_messages.lex
  test_error.lex
  test_route.lex
  test_route_io.lex       (v0.2) effectful dispatch
  test_v16_schemas.lex
  test_v201_schemas.lex
  test_v21_schemas.lex    (v0.3) OCPP 2.1 validators
  test_gen.lex            (v0.2) codegen tool
examples/
  csms_v16.lex            Full v1.6 CSMS over WebSocket (pure handlers)
  csms_v16_stateful.lex   (v0.2) in-process CSMS with [io] handlers
  csms_v201.lex           v2.0.1 CSMS over WebSocket
  csms_v21.lex            (v0.3) v2.1 CSMS — DER / battery swap / streams
  charger_frames.lex      Frame construction demo (no transport)
  cp_simulator_v16.lex    (v0.4) Charge-point simulator — dials a CSMS
                          over `ws://`, replays a full session;
                          CP_ID / ID_TAG come from env vars for multi-CP
  csms_v16_sqlite.lex     (v0.4) CSMS over `ws://` with SQLite
                          persistence — real `transactionId` from
                          AUTOINCREMENT, idTag allowlist, per-CP
                          audit trail
  cp_simulator_v21.lex    (v0.4) OCPP 2.1 charge-point simulator —
                          dials csms_v21.lex over `ws://`, walks the
                          v2.1 TransactionEvent state machine
                          (Started → Updated → Ended)
```

### Real-world simulator pair

For an end-to-end demo on a single host, run a CSMS in one terminal
and one or more charge-point simulators in others.

**Minimal** (pure handlers, no persistence — fast to read, no `[sql]`):

```sh
# Terminal A — Central System
lex run --allow-effects net,io,time examples/csms_v16.lex main

# Terminal B — Charge point connecting to the CSMS above
lex run --allow-effects net,io,env examples/cp_simulator_v16.lex main
```

**Stateful + multi-CP** (SQLite persistence; two simulators in parallel):

```sh
# Terminal A — CSMS, writes to /tmp/csms.db (override with $CSMS_DB)
lex run --allow-effects net,io,time,sql,fs_write,env \
  examples/csms_v16_sqlite.lex main

# Terminal B — Authorized charge point (USER-001 is pre-seeded in
# `allowed_tags`; the session completes end-to-end)
CP_ID=CP-001 ID_TAG=USER-001 \
  lex run --allow-effects net,io,env \
  examples/cp_simulator_v16.lex main

# Terminal C — Unauthorized charge point (CSMS rejects at Authorize;
# the simulator aborts before sending StartTransaction)
CP_ID=CP-002 ID_TAG=UNKNOWN-CARD \
  lex run --allow-effects net,io,env \
  examples/cp_simulator_v16.lex main
```

Inspect the run:

```sh
sqlite3 /tmp/csms.db <<SQL
.headers on
SELECT id, cp_id, id_tag, meter_start, meter_stop, reason FROM transactions;
SELECT cp_id, transaction_id, value_wh, ts FROM meter_values;
SELECT cp_id, status, ts FROM status_log ORDER BY id;
SQL
```

Both example simulators open a WebSocket to
`ws://localhost:9000/ocpp/<CP_ID>` and walk the canonical OCPP 1.6
session (BootNotification → StatusNotification → Authorize →
StartTransaction → MeterValues → Heartbeat → StopTransaction →
StatusNotification). The `on_open` / `on_message` callbacks are
stateless (Lex has no mutable globals), so the session state machine
lives in the OCPP message-id strings: the CSMS echoes each id back in
its CallResult, and `cp_simulator_v16.on_result` looks at the id to
choose the next Call. The `transactionId` returned by
StartTransaction is threaded through subsequent message-ids
(`meter:tx<N>`, `heartbeat:tx<N>`, `stop:tx<N>`) so StopTransaction
can recover it without shared state.

`csms_v16_sqlite.lex` bypasses the route_io registry pattern
deliberately: the registry dispatches purely on action name and can't
see `WsConn`, but the CSMS needs `WsConn.path` to derive `cp_id`. So
it builds dispatch directly on top of `msg.*`, `sch.validate_*`, and
`route.HandlerResult`, and captures the `Db` handle through a
closure passed to `net.serve_ws_fn`.

**OCPP 2.1**: a sibling `cp_simulator_v21.lex` pairs with
`examples/csms_v21.lex` (subprotocol `ocpp2.1`, port 9002) and
exercises the v2.1-specific message shapes:

```sh
# Terminal A — OCPP 2.1 CSMS
lex run --allow-effects net,io,time examples/csms_v21.lex main

# Terminal B — OCPP 2.1 charge point
CP_ID=CS-001 ID_TOKEN=USER-001 \
  lex run --allow-effects net,io,env examples/cp_simulator_v21.lex main
```

The v2.1 script walks `BootNotification(reason=PowerUp)` →
`StatusNotification(connectorStatus=Available, evseId, connectorId)` →
`Authorize(idToken={idToken, type=ISO14443})` →
**`TransactionEvent`** (which replaces v1.6's Start/Stop pair —
`eventType` in {Started, Updated, Ended}, monotonic `seqNo`, and the
CP picks the string `transactionId`) → `Heartbeat` → final
`TransactionEvent(Ended, stoppedReason=Local)` → another
`StatusNotification(Available)`. The schema differences from v1.6
that bit during development:

- `sampledValue.value` is a JSON number in 2.1 (was a string in 1.6).
- `Authorize` takes an `idToken` *record* (`{idToken, type}`), not a
  bare `idTag` string; response key is `idTokenInfo`, not `idTagInfo`.
- `BootNotification.chargingStation` carries `vendorName` / `model`
  (replacing `chargePointVendor` / `chargePointModel`).

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

### One framework, three spec versions

OCPP 1.6, 2.0.1, and 2.1 share the same wire-level RPC framework (Call
/ CallResult / CallError) but use different action catalogs, different
spellings of a couple of error codes, and (for some actions) different
payload shapes. OCPP 2.1 adds ISO 15118-20 bidirectional charging,
battery swap, periodic event streams, DER (Distributed Energy
Resources) control, and tariff/settlement flows on top of the 2.0.1
baseline. lex-ocpp:

- shares `src/messages.lex` and `src/route.lex` between all three versions,
- exposes `src/v16/`, `src/v201/`, and `src/v21/` action / enum / schema
  catalogs,
- exposes both `OccurenceConstraintViolation` (1.6) and
  `OccurrenceConstraintViolation` + `FormatViolation` (2.0.1 + 2.1) in
  `src/error.lex` so handler code reads naturally on every side.

To run all three side-by-side, declare three `ChargePoint` values
(`cp.new_v16(...)`, `cp.new_v201(...)`, `cp.new_v21(...)`) and serve them
on different ports / subprotocols (`"ocpp1.6"`, `"ocpp2.0.1"`,
`"ocpp2.1"`).

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

## Tests + CI

GitHub Actions runs the full pipeline on every push to `main` and
on every pull request — see `.github/workflows/lex.yml`. Locally:

```bash
lex ci --no-fmt
# ==> lex pkg install
# ==> lex check --strict src/    ok across all files
# ==> lex test                   7 passed, 0 failed
# CI passed — all steps green

# Plus the [sql]-flavoured suite (separately, until lex-lang#399 lands):
lex run --allow-effects io,sql,time \
  tests/effectful/test_route_io.lex run_all
# → 0
```

**8 suites, ~122 cases, zero failures.** Pure suites need no effect
grants; the effectful suite under `tests/effectful/` runs handlers
under `[io, time, sql]`.

The CI workflow checks out lex-ocpp + lex-schema + lex-web siblings
into a flat layout (so the `path = "../<sibling>"` deps in `lex.toml`
resolve cleanly), installs the **pre-built `lex 0.10.7` release binary**
(no Rust toolchain needed on the runner — 30s instead of 90s), runs
`lex ci --no-fmt`, then the effectful suite as a follow-up step.

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

---

Built under the principles of [Trust Without Comprehension](https://lexlang.org/manifesto).
