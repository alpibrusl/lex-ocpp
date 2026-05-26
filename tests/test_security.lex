# Tests for src/security.lex (pure subset)
#
# argon2id hash+verify are pure (no crypto effect on verify_argon2id).
# JWT round-trips that call verify_hs256 have [time] effect and
# belong in an effectful suite; this file covers sign→decode.

import "std.bytes" as bytes
import "std.list"  as list

import "lex-crypto/jwt"      as jwt
import "lex-crypto/password" as pw

import "../src/security" as sec

# ---- Test scaffolding -------------------------------------------

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }

# ---- Password (SP2) tests ---------------------------------------

fn test_password_verify_known_hash() -> Result[Unit, Str] {
  let salt   := bytes.from_str("fixed-16-byte-sa")
  let stored := pw.hash_argon2id("correct-horse", salt)
  match stored {
    Err(e) => fail(e),
    Ok(h)  => match pw.verify_argon2id(h, "correct-horse") {
      Err(e) => fail(e),
      Ok(v)  => if v { pass() } else { fail("expected verify to return true") },
    },
  }
}

fn test_wrong_password_does_not_verify() -> Result[Unit, Str] {
  let salt   := bytes.from_str("fixed-16-byte-sa")
  let stored := pw.hash_argon2id("correct-horse", salt)
  match stored {
    Err(e) => fail(e),
    Ok(h)  => match pw.verify_argon2id(h, "wrong-password") {
      Err(e) => fail(e),
      Ok(v)  => if v { fail("wrong password should not verify") } else { pass() },
    },
  }
}

fn test_authenticate_ok() -> Result[Unit, Str] {
  let salt   := bytes.from_str("fixed-16-byte-sb")
  let stored := pw.hash_argon2id("pass", salt)
  match stored {
    Err(e) => fail(e),
    Ok(h)  => match sec.authenticate(h, "pass") {
      Ok(_)  => pass(),
      Err(e) => fail(e),
    },
  }
}

fn test_authenticate_wrong_pass() -> Result[Unit, Str] {
  let salt   := bytes.from_str("fixed-16-byte-sc")
  let stored := pw.hash_argon2id("pass", salt)
  match stored {
    Err(e) => fail(e),
    Ok(h)  => match sec.authenticate(h, "wrong") {
      Ok(_)  => fail("wrong password should not authenticate"),
      Err(_) => pass(),
    },
  }
}

# ---- JWT (SP3) pure tests ---------------------------------------

fn make_cp_claims() -> jwt.Claims {
  { sub: "CP-001", iss: "csms", aud: "cp", jti: "", exp: 0, nbf: 0, iat: 0 }
}

fn test_issue_and_decode_cp_token() -> Result[Unit, Str] {
  let secret := bytes.from_str("csms-shared-secret-key")
  let token  := jwt.sign_hs256(secret, make_cp_claims())
  match jwt.decode_unverified(token) {
    Err(_) => fail("jwt decode_unverified failed"),
    Ok(c)  => if c.sub == "CP-001" and c.iss == "csms" {
      pass()
    } else {
      fail("claims mismatch")
    },
  }
}

# ---- Suite + runner ---------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_password_verify_known_hash(),
    test_wrong_password_does_not_verify(),
    test_authenticate_ok(),
    test_authenticate_wrong_pass(),
    test_issue_and_decode_cp_token(),
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0,
    fn (n :: Int, r :: Result[Unit, Str]) -> Int {
      match r { Ok(_) => n, Err(_) => n + 1 }
    })
}
