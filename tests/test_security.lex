# Tests for src/security.lex (pure subset)
#
# argon2id hash+verify are pure (no crypto effect on verify_argon2id).
# JWT round-trips that call verify_hs256 have [time] effect and
# belong in an effectful suite; this file covers sign→decode.

import "std.bytes" as bytes

import "lex-crypto/jwt"      as jwt
import "lex-crypto/password" as pw

import "../src/security" as sec

# ---- Password (SP2) tests ---------------------------------------

fn test_password_verify_known_hash() -> Bool {
  let salt    := bytes.from_str("fixed-16-byte-sa")
  let stored  := pw.hash_argon2id("correct-horse", salt)
  match stored {
    Err(_) => false,
    Ok(h)  => match pw.verify_argon2id(h, "correct-horse") {
      Err(_)  => false,
      Ok(ok)  => ok,
    },
  }
}

fn test_wrong_password_does_not_verify() -> Bool {
  let salt   := bytes.from_str("fixed-16-byte-sa")
  let stored := pw.hash_argon2id("correct-horse", salt)
  match stored {
    Err(_) => false,
    Ok(h)  => match pw.verify_argon2id(h, "wrong-password") {
      Err(_)    => false,
      Ok(false) => true,
      Ok(true)  => false,
    },
  }
}

fn test_authenticate_ok() -> Bool {
  let salt   := bytes.from_str("fixed-16-byte-sb")
  let stored := pw.hash_argon2id("pass", salt)
  match stored {
    Err(_) => false,
    Ok(h)  => match sec.authenticate(h, "pass") {
      Ok(_)  => true,
      Err(_) => false,
    },
  }
}

fn test_authenticate_wrong_pass() -> Bool {
  let salt   := bytes.from_str("fixed-16-byte-sc")
  let stored := pw.hash_argon2id("pass", salt)
  match stored {
    Err(_) => false,
    Ok(h)  => match sec.authenticate(h, "wrong") {
      Ok(_)  => false,
      Err(_) => true,
    },
  }
}

# ---- JWT (SP3) pure tests ---------------------------------------

fn test_issue_and_decode_cp_token() -> Bool {
  let secret := bytes.from_str("csms-shared-secret-key")
  let claims := {
    sub: "CP-001", iss: "csms", aud: "cp", jti: "",
    exp: 0, nbf: 0, iat: 0,
  }
  let token := jwt.sign_hs256(secret, claims)
  match jwt.decode_unverified(token) {
    Err(_)  => false,
    Ok(c)   => c.sub == "CP-001" and c.iss == "csms",
  }
}

fn run_all() -> Int {
  let f := 0
  let f := if test_password_verify_known_hash()     { f } else { f + 1 }
  let f := if test_wrong_password_does_not_verify()  { f } else { f + 1 }
  let f := if test_authenticate_ok()                 { f } else { f + 1 }
  let f := if test_authenticate_wrong_pass()         { f } else { f + 1 }
  let f := if test_issue_and_decode_cp_token()       { f } else { f + 1 }
  f
}
