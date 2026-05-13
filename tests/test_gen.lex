# lex-ocpp — tests for the JSON Schema → Lex codegen
#
# These tests pin the generator's output for a handful of canonical
# input shapes (primitive fields, required/optional, enum, array,
# integer range). Tightening one of these tests after a generator
# change is the signal to update both the generator and any
# downstream callers.

import "std.str"  as str
import "std.list" as list

import "../tools/gen" as gen

# ---- Test scaffolding --------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

fn assert_contains(haystack :: Str, needle :: Str, label :: Str) -> Result[Unit, Str] {
  if str.contains(haystack, needle) { pass() }
  else { fail(str.concat(label,
    str.concat(": output missing `", str.concat(needle, "`")))) }
}

fn assert_ok_str(r :: Result[Str, Str], label :: Str) -> Result[Str, Str] {
  match r {
    Ok(s)  => Ok(s),
    Err(e) => Err(str.concat(label, str.concat(": ", e))),
  }
}

# ---- Tests ------------------------------------------------------

fn test_minimal_object() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Empty\",\"type\":\"object\","
             + "\"required\":[],\"properties\":{}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => {
      match assert_contains(src, "fn empty_schema()", "schema fn name") {
        Err(why) => Err(why),
        Ok(_)    => match assert_contains(src, "fn validate_empty",
                                          "validator fn name") {
          Err(why) => Err(why),
          Ok(_)    => assert_contains(src, "title: \"Empty\"", "title"),
        },
      }
    },
  }
}

fn test_required_and_optional() -> Result[Unit, Str] {
  let schema := "{\"title\":\"User\",\"type\":\"object\","
             + "\"required\":[\"email\"],"
             + "\"properties\":{"
             +   "\"email\":{\"type\":\"string\"},"
             +   "\"nickname\":{\"type\":\"string\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) =>
      match assert_contains(src, "s.required_str(\"email\"", "required field") {
        Err(why) => Err(why),
        Ok(_)    => assert_contains(src,
          "s.optional(s.required_str(\"nickname\"", "optional field"),
      },
  }
}

fn test_enum_constraint() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Status\",\"type\":\"object\","
             + "\"required\":[\"value\"],"
             + "\"properties\":{"
             +   "\"value\":{\"type\":\"string\","
             +   "\"enum\":[\"Accepted\",\"Pending\",\"Rejected\"]}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src,
      "StrOneOf([\"Accepted\", \"Pending\", \"Rejected\"])", "enum"),
  }
}

fn test_string_min_max_len() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Tag\",\"type\":\"object\","
             + "\"required\":[\"v\"],"
             + "\"properties\":{"
             +   "\"v\":{\"type\":\"string\","
             +   "\"minLength\":1,\"maxLength\":20}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) =>
      match assert_contains(src, "StrMinLen(1)", "min_len") {
        Err(why) => Err(why),
        Ok(_)    => assert_contains(src, "StrMaxLen(20)", "max_len"),
      },
  }
}

fn test_int_range() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Age\",\"type\":\"object\","
             + "\"required\":[\"a\"],"
             + "\"properties\":{"
             +   "\"a\":{\"type\":\"integer\","
             +   "\"minimum\":13,\"maximum\":130}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "IntInRange(13, 130)", "int range"),
  }
}

fn test_int_non_negative() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Count\",\"type\":\"object\","
             + "\"required\":[\"n\"],"
             + "\"properties\":{"
             +   "\"n\":{\"type\":\"integer\",\"minimum\":0}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "IntNonNegative", "non-negative int"),
  }
}

fn test_primitive_array() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Tags\",\"type\":\"object\","
             + "\"required\":[\"items\"],"
             + "\"properties\":{"
             +   "\"items\":{\"type\":\"array\","
             +   "\"items\":{\"type\":\"string\",\"maxLength\":40},"
             +   "\"minItems\":1}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) =>
      match assert_contains(src, "KStr([StrMaxLen(40)])", "array element kind") {
        Err(why) => Err(why),
        Ok(_)    => assert_contains(src, "ListNonEmpty", "minItems → ListNonEmpty"),
      },
  }
}

fn test_invalid_json() -> Result[Unit, Str] {
  match gen.generate("not json") {
    Ok(_)  => fail("invalid JSON should have errored"),
    Err(_) => pass(),
  }
}

# ============================================================
# Extensions in v0.3 (#1) — $ref, oneOf, pattern, format hints
# ============================================================

fn test_pattern_constraint() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Phone\",\"type\":\"object\","
             + "\"required\":[\"v\"],"
             + "\"properties\":{"
             +   "\"v\":{\"type\":\"string\","
             +   "\"pattern\":\"^\\\\+[1-9][0-9]+$\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "StrPattern(", "pattern check"),
  }
}

fn test_format_email() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Contact\",\"type\":\"object\","
             + "\"required\":[\"email\"],"
             + "\"properties\":{"
             +   "\"email\":{\"type\":\"string\",\"format\":\"email\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "StrEmail", "email format"),
  }
}

fn test_format_uri() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Link\",\"type\":\"object\","
             + "\"required\":[\"href\"],"
             + "\"properties\":{"
             +   "\"href\":{\"type\":\"string\",\"format\":\"uri\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "StrUrl", "uri format → StrUrl"),
  }
}

fn test_format_uuid() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Entity\",\"type\":\"object\","
             + "\"required\":[\"id\"],"
             + "\"properties\":{"
             +   "\"id\":{\"type\":\"string\",\"format\":\"uuid\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "StrUuid", "uuid format"),
  }
}

fn test_format_unknown_dropped() -> Result[Unit, Str] {
  # Unknown formats must be silently dropped per JSON Schema spec.
  let schema := "{\"title\":\"X\",\"type\":\"object\","
             + "\"required\":[\"v\"],"
             + "\"properties\":{"
             +   "\"v\":{\"type\":\"string\",\"format\":\"klingon-glyph\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => {
      # The check list should be empty (no constraint emitted for the
      # unknown format). Just verify we didn't error and didn't emit
      # a fake "StrKlingon" constraint.
      if str.contains(src, "Klingon") { fail("unknown format leaked") }
      else { pass() }
    },
  }
}

fn test_ref_resolution() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Auth\",\"type\":\"object\","
             + "\"$defs\":{"
             +   "\"IdToken\":{"
             +     "\"type\":\"object\","
             +     "\"required\":[\"idToken\"],"
             +     "\"properties\":{"
             +       "\"idToken\":{\"type\":\"string\"}"
             +     "}"
             +   "}"
             + "},"
             + "\"required\":[\"idToken\"],"
             + "\"properties\":{"
             +   "\"idToken\":{\"$ref\":\"#/$defs/IdToken\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) =>
      match assert_contains(src, "fn id_token_schema()", "helper for $defs entry") {
        Err(why) => Err(why),
        Ok(_)    => assert_contains(src,
          "s.required_object(\"idToken\", id_token_schema())", "$ref call site"),
      },
  }
}

fn test_ref_in_array_items() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Bag\",\"type\":\"object\","
             + "\"$defs\":{"
             +   "\"Item\":{"
             +     "\"type\":\"object\","
             +     "\"required\":[\"id\"],"
             +     "\"properties\":{\"id\":{\"type\":\"integer\"}}"
             +   "}"
             + "},"
             + "\"required\":[\"items\"],"
             + "\"properties\":{"
             +   "\"items\":{\"type\":\"array\","
             +   "\"items\":{\"$ref\":\"#/$defs/Item\"},"
             +   "\"minItems\":1}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "KObject(item_schema())", "array of $refs"),
  }
}

fn test_definitions_keyword() -> Result[Unit, Str] {
  # Older JSON Schema drafts use `definitions` instead of `$defs`.
  let schema := "{\"title\":\"OldDraft\",\"type\":\"object\","
             + "\"definitions\":{"
             +   "\"Legacy\":{"
             +     "\"type\":\"object\","
             +     "\"required\":[\"x\"],"
             +     "\"properties\":{\"x\":{\"type\":\"integer\"}}"
             +   "}"
             + "},"
             + "\"required\":[\"legacy\"],"
             + "\"properties\":{"
             +   "\"legacy\":{\"$ref\":\"#/definitions/Legacy\"}"
             + "}}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) => assert_contains(src, "fn legacy_schema()", "definitions keyword"),
  }
}

fn test_oneof_discriminated() -> Result[Unit, Str] {
  let schema := "{\"title\":\"Event\","
             + "\"oneOf\":[{"
             +   "\"type\":\"object\","
             +   "\"required\":[\"kind\",\"user_id\"],"
             +   "\"properties\":{"
             +     "\"kind\":{\"const\":\"signup\"},"
             +     "\"user_id\":{\"type\":\"string\"}"
             +   "}"
             + "},{"
             +   "\"type\":\"object\","
             +   "\"required\":[\"kind\",\"amount\"],"
             +   "\"properties\":{"
             +     "\"kind\":{\"const\":\"purchase\"},"
             +     "\"amount\":{\"type\":\"integer\"}"
             +   "}"
             + "}]}"
  match gen.generate(schema) {
    Err(e) => fail(str.concat("parse: ", e)),
    Ok(src) =>
      match assert_contains(src, "fn event_signup_schema()", "signup branch") {
        Err(why) => Err(why),
        Ok(_)    =>
          match assert_contains(src, "fn event_purchase_schema()", "purchase branch") {
            Err(why) => Err(why),
            Ok(_)    => assert_contains(src, "union.discriminate", "dispatcher"),
          },
      },
  }
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_minimal_object(),
    test_required_and_optional(),
    test_enum_constraint(),
    test_string_min_max_len(),
    test_int_range(),
    test_int_non_negative(),
    test_primitive_array(),
    test_invalid_json(),
    # v0.3 extensions (#1)
    test_pattern_constraint(),
    test_format_email(),
    test_format_uri(),
    test_format_uuid(),
    test_format_unknown_dropped(),
    test_ref_resolution(),
    test_ref_in_array_items(),
    test_definitions_keyword(),
    test_oneof_discriminated(),
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    })
}
