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
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    })
}
