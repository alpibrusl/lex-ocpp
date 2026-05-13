# tools/fixtures/

Canonical JSON Schema documents exercising the codegen surface in
`tools/gen.lex`. Used as inputs to the codegen-on-real-input smoke
test (see `tests/test_gen.lex`).

| File | Demonstrates |
|---|---|
| `AuthorizeRequest.json` | `$ref` against a `$defs` entry (IdTokenType), enum constraints, min/max length, optional fields |
| `WebhookEvent.json`     | `oneOf` discriminated union with two `const`-tagged branches; `format: "email"` mapping |

Run the codegen against any fixture via:

```bash
lex run tools/gen.lex demo
# or programmatically:
lex run tools/gen.lex generate "$(cat tools/fixtures/AuthorizeRequest.json | jq -R -s .)"
```

The output is a Lex source fragment you can paste into
`src/v201/schemas.lex` (or its v1.6 / v2.1 sibling); inspect it
before committing.

Adding a fixture: drop the JSON Schema file in this directory and
add a test case in `tests/test_gen.lex` that runs the generator
over it and asserts the produced source contains the expected
function names / constraints. Keep fixtures small (one
demonstrated construct per file) so failure modes localize.
