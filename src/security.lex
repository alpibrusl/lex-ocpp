# lex-ocpp — OCPP security profiles (SP2 + SP3)
#
# OCPP-J defines three security profiles that layer on the base
# WebSocket transport. This module covers the two most common:
#
#   Security Profile 2 (OCPP 1.6 / 2.0.1)
#     HTTP Basic Auth at the WS handshake. The CSMS stores an
#     argon2id hash of each charge-point password. A CP connects
#     with its ID as the username and plaintext password (TLS
#     provides confidentiality). Use verify_password() to check.
#
#     Storage format: PHC string produced by lex-crypto/password
#       $argon2id$v=19$t=3,m=65536$<salt_b64>$<hash_b64>
#
#   Security Profile 3 (OCPP 2.0.1)
#     The CSMS issues a short-lived HS256 JWT to the CP after the
#     initial handshake. The CP presents it as Authorization: Bearer
#     on reconnect. Use issue_cp_token() + verify_cp_token().
#
# Effects:
#   hash_password    — pure  (caller supplies salt :: Bytes)
#   verify_password  — pure
#   authenticate     — pure
#   issue_cp_token   — [time]
#   verify_cp_token  — [time]

import "std.time" as time

import "lex-crypto/jwt"      as jwt
import "lex-crypto/password" as pw

# ---- Security Profile 2: argon2id password management -----------

# Hash a charge-point password for storage in the CSMS database.
# The caller must supply a cryptographically random salt (16 bytes
# is standard; use your platform's CSPRNG before calling this).
# Returns a PHC-format string suitable for database storage.
fn hash_password(password :: Str, salt :: Bytes) -> Result[Str, Str] {
  pw.hash_argon2id(password, salt)
}

# Verify a plaintext password against a stored argon2id hash.
# Returns Ok(true) on match, Ok(false) on mismatch, Err on corrupt hash.
fn verify_password(stored_hash :: Str, password :: Str) -> Result[Bool, Str] {
  pw.verify_argon2id(stored_hash, password)
}

# Authenticate a CP: Ok(()) on match, Err(message) on any failure.
# Convenience wrapper around verify_password for handler code:
#
#   match sec.authenticate(stored, presented) {
#     Err(e) => reject_connection(e),
#     Ok(()) => accept_connection(),
#   }
fn authenticate(stored_hash :: Str, password :: Str) -> Result[Unit, Str] {
  match pw.verify_argon2id(stored_hash, password) {
    Err(e)      => Err(e),
    Ok(false)   => Err("invalid password"),
    Ok(true)    => Ok(()),
  }
}

# ---- Security Profile 3: JWT for OCPP 2.0.1 ---------------------

# Issue a short-lived HS256 JWT identifying a charge point.
# `cp_id` becomes the `sub` claim; `ttl_secs` is typically 3600
# (initial auth) or 300 (re-auth / token refresh).
fn issue_cp_token(
  secret   :: Bytes,
  cp_id    :: Str,
  ttl_secs :: Int
) -> [time] Str {
  let now    := time.now()
  let claims := {
    sub: cp_id, iss: "csms", aud: "cp", jti: "",
    exp: now + ttl_secs, nbf: now, iat: now,
  }
  jwt.sign_hs256(secret, claims)
}

# Verify a CP-presented Bearer token. Returns Ok(claims) so the
# caller can read claims.sub (the CP id) for further authorization.
fn verify_cp_token(
  secret :: Bytes,
  token  :: Str
) -> [time] Result[jwt.Claims, Str] {
  match jwt.verify_hs256(secret, token) {
    Ok(claims)           => Ok(claims),
    Err(jwt.Expired)     => Err("token expired"),
    Err(jwt.NotYetValid) => Err("token not yet valid"),
    Err(_)               => Err("invalid token"),
  }
}
