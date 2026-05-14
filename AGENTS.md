# AGENTS.md — lex-ocpp

This file is for AI assistants (Claude Code, Cursor, Aider, Copilot, …)
working in this repo. Humans should read `README.md` first; agents
should read this **first**.

## 1. What this is

OCPP (Open Charge Point Protocol) library for the
[Lex language](https://github.com/alpibrusl/lex-lang), in the spirit of
[mobilityhouse/ocpp](https://github.com/mobilityhouse/ocpp). Wire framing
+ action catalogs + lex-schema-backed payload validators + pure +
effectful dispatch paths, for OCPP 1.6, 2.0.1, and 2.1.

Built on top of:

- [`alpibrusl/lex-lang`](https://github.com/alpibrusl/lex-lang) — the language + toolchain.
- [`alpibrusl/lex-schema`](https://github.com/alpibrusl/lex-schema) — runtime validation library.
- [`alpibrusl/lex-web`](https://github.com/alpibrusl/lex-web) — HTTP / WebSocket framework (used by examples).
- [`alpibrusl/lex-orm`](https://github.com/alpibrusl/lex-orm) — optional, only when handlers persist via `[sql]`.

## 2. Install the Lex toolchain

CI runs against **v0.9.2** pre-built binaries; use the same locally:

```sh
LEX_VERSION=v0.9.2
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)   TARGET=x86_64-unknown-linux-gnu  ;;
  Linux-aarch64)  TARGET=aarch64-unknown-linux-gnu ;;
  Darwin-x86_64)  TARGET=x86_64-apple-darwin       ;;
  Darwin-arm64)   TARGET=aarch64-apple-darwin      ;;
  *) echo "unsupported platform" >&2; exit 1 ;;
esac
curl -sSfL "https://github.com/alpibrusl/lex-lang/releases/download/${LEX_VERSION}/lex-${LEX_VERSION}-${TARGET}.tar.gz" | tar -xz
sudo install -m 0755 "lex-${LEX_VERSION}-${TARGET}/lex" /usr/local/bin/lex
lex --version
```

Fallback (build from source — needed if you want an off-`main` fix):

```sh
git clone --depth=1 https://github.com/alpibrusl/lex-lang /tmp/lex-lang
cd /tmp/lex-lang && cargo build --release --bin lex
export PATH="/tmp/lex-lang/target/release:$PATH"
```

## 3. Resolve dependencies

lex-ocpp pulls `lex-schema` and `lex-web` via `path = "../<sibling>"`
in `lex.toml`. Lay out siblings in a flat directory:

```
~/work/
  ├── lex-ocpp/    ← clone this
  ├── lex-schema/  ← clone alpibrusl/lex-schema
  └── lex-web/     ← clone alpibrusl/lex-web
```

Then:

```sh
cd ~/work/lex-ocpp
lex pkg install
```

## 4. Run the full pipeline

```sh
lex ci --no-fmt                # pkg install → check --strict → test
                               # (skip --fmt: source isn't fmt-clean yet)

# The IO-flavoured suite needs explicit effect grants because
# `lex test` runs under Policy::permissive() which doesn't yet
# include `sql` (alpibrusl/lex-lang#399). Until that lands, run
# it separately:
lex run --allow-effects io,sql,time \
  tests/effectful/test_route_io.lex run_all
# → 0   (zero failures)
```

If anything fails, fix it before opening a PR.

## 5. Conventions

### Layout

| Where | What |
|---|---|
| `src/messages.lex`      | Wire framing — Call / CallResult / CallError |
| `src/error.lex`         | OCPP error code constants + OcppError ADT |
| `src/route.lex`         | Pure handler registry + dispatch |
| `src/route_io.lex`      | Effectful registry + dispatch (`[io, time, sql]`) |
| `src/charge_point*.lex` | Façade values bundling identity + version + registry |
| `src/v16/*.lex`         | OCPP 1.6 surface (action / enums / datatypes / schemas) |
| `src/v201/*.lex`        | OCPP 2.0.1 surface |
| `src/v21/*.lex`         | OCPP 2.1 surface |
| `tools/gen.lex`         | JSON Schema → lex-schema codegen |
| `tools/fixtures/`       | JSON Schema inputs for the generator |
| `tests/test_*.lex`      | Pure + `[io, time]`-only suites; picked up by `lex test` |
| `tests/effectful/`      | `[sql]`-effectful suites; run via `lex run` |
| `examples/`             | Runnable CSMSes + frame-construction demos |

### Style

- **Pure core, effect edge.** Everything under `src/` is pure unless
  the file is explicitly an `_io` variant. Effects (`[io]`, `[net]`,
  `[time]`, `[sql]`) belong at the transport / handler boundary.
- **Function types in records — inline, no aliases.** Type aliases for
  function types don't unfold at call sites in 0.9.x; write
  `handler :: (jv.Json) -> [io] HandlerResult` directly in the record
  declaration, not via a `type Handler = ...` alias.
- **Variants as wire identifiers.** Action names + enum members are
  exposed as `fn name() -> Str` constants, validated via
  `lex-schema`'s `StrOneOf(all_xxx())`. Don't inline string literals
  at call sites — use the constant.
- **Tests return `Int`.** Each suite exports `run_all() -> Int`
  returning the count of failing cases. `lex test` accepts that;
  zero = pass.
- **No `assert`.** It's not a Lex builtin (lex-orm has it but currently
  doesn't compile against tip-of-tree — they're using a pattern
  that broke). Stick with the `Result[Unit, Str]` + counting approach
  that the test suites already use.

### Adding a validator

1. Define a `ModelSchema` value in the relevant `src/vXX/schemas.lex`.
2. Add a `validate_<action>_req(j)` wrapper that delegates to
   `s.validate(...)`.
3. Append an entry to `all_request_validators()`.
4. Add at least one Ok and one Err test case in
   `tests/test_vXX_schemas.lex`.

Bulk-filling from JSON Schema? Use `tools/gen.lex`:

```sh
lex run tools/gen.lex generate "$(cat path/to/schema.json | jq -R -s .)"
```

Output is a Lex source fragment — review, then paste into the
matching `schemas.lex`.

## 6. Filing upstream issues

Three upstream repos relate to this codebase. Bias toward filing
issues there rather than working around the gap in lex-ocpp source:

- **`alpibrusl/lex-lang`** — language / runtime / toolchain bugs.
  Open issues we hit during v0.1 — v0.3: #390 (WS client), #391
  (cross-package examples blocks — fixed in 0.9.2), #399
  (`Policy::permissive()` missing `sql`).
- **`alpibrusl/lex-schema`** — runtime validation library.
  Open: #5 (stopgap for #391 — obsolete once 0.9.2 is the floor).
- **`alpibrusl/lex-web`** — HTTP / WS framework.
  Open: #4 (outbound WS send for CSMS→CP Calls).

When filing, include a minimal reproducer + the affected
downstream surface (file + line) + version info from `lex version`.

## 7. PRs

- Open PR against `main`.
- Title: short and conventional (`feat:`, `fix:`, `ci:`, `docs:`,
  etc).
- Body: summary + test plan + any linked issues.
- The CI workflow at `.github/workflows/lex.yml` runs `lex ci
  --no-fmt` plus the effectful suite plus smoke tests of the
  examples + codegen demo. All steps must be green before merge.

## 8. Common pitfalls

- **`lex pkg install` fails with `unknown_identifier: required_str`.**
  Your lex toolchain is older than 0.9.2; the `examples { }`
  cross-package resolution bug (`alpibrusl/lex-lang#391`) is the
  cause. Upgrade.

- **`lex test` fails on `test_route_io.lex` with
  `effect 'sql' not in --allow-effects`.**
  Expected — that suite is under `tests/effectful/` and uses `lex
  run` with explicit `--allow-effects io,sql,time`. See section 4.

- **Constructor shadowing warning under `lex check --strict`.**
  Parameters can't be named the same as a top-level fn in the
  same file (the `SHADOW_FN` lint). Rename the param; record fields
  can keep the canonical name (the field-name → param-name → record
  initialization chain just needs to be unambiguous).

- **Effect propagation fails through the IO dispatcher.**
  Lex 0.9.x doesn't have effect polymorphism on function pointers.
  The IO registry has a closed upper bound of `[io, time, sql]`;
  handlers declaring more effects (`[fs_read]`, `[net]`, …) don't
  fit. Wrap your own dispatch on top of `route.dispatch` if you
  need a different effect set.
