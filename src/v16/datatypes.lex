# lex-ocpp — OCPP 1.6 shared datatypes
#
# Record types that recur across multiple OCPP 1.6 messages. Keep
# these as plain records: callers either build them at handler-write
# time and feed `to_json` to the wire, or decode the inbound Json
# through one of the `from_json` accessors when reading.
#
# Not every spec datatype is reified here — only the ones that
# benefit from a named type (cross-message reuse, deep nesting).
# Single-message payloads use the matching `schemas.<action>`
# validator directly without an intermediate record type.
#
# Effects: none.

import "std.str" as str

import "std.int" as int

import "std.list" as list

import "lex-schema/json_value" as jv

# ---- IdTagInfo ---------------------------------------------------
#
# Returned in Authorize, StartTransaction, and StopTransaction
# responses. `expiry_date` and `parent_id_tag` are optional —
# absent fields encode as JSON `null` or omission.
type IdTagInfo = { status :: Str, expiry_date :: Option[Str], parent_id_tag :: Option[Str] }

fn id_tag_info(status :: Str) -> IdTagInfo {
  { status: status, expiry_date: None, parent_id_tag: None }
}

fn id_tag_info_with(status :: Str, expiry_date :: Option[Str], parent_id_tag :: Option[Str]) -> IdTagInfo {
  { status: status, expiry_date: expiry_date, parent_id_tag: parent_id_tag }
}

fn id_tag_info_to_json(it :: IdTagInfo) -> jv.Json {
  let base := [("status", JStr(it.status))]
  let with_expiry := match it.expiry_date {
    Some(s) => list.concat(base, [("expiryDate", JStr(s))]),
    None => base,
  }
  let with_parent := match it.parent_id_tag {
    Some(s) => list.concat(with_expiry, [("parentIdTag", JStr(s))]),
    None => with_expiry,
  }
  JObj(with_parent)
}

# ---- SampledValue + MeterValue ----------------------------------
#
# OCPP 1.6 §6.31. A `MeterValue` aggregates one or more
# `SampledValue` readings taken at the same `timestamp`. Every
# `SampledValue` field except `value` is optional with a documented
# default ("Energy.Active.Import.Register", "Raw", "Outlet", "Wh").
type SampledValue = { value :: Str, context :: Option[Str], format :: Option[Str], measurand :: Option[Str], phase :: Option[Str], location :: Option[Str], unit :: Option[Str] }

fn sampled_value(value :: Str) -> SampledValue {
  { value: value, context: None, format: None, measurand: None, phase: None, location: None, unit: None }
}

fn sampled_value_to_json(sv :: SampledValue) -> jv.Json {
  let entries := [("value", JStr(sv.value))]
  let e1 := add_opt_str(entries, "context", sv.context)
  let e2 := add_opt_str(e1, "format", sv.format)
  let e3 := add_opt_str(e2, "measurand", sv.measurand)
  let e4 := add_opt_str(e3, "phase", sv.phase)
  let e5 := add_opt_str(e4, "location", sv.location)
  let e6 := add_opt_str(e5, "unit", sv.unit)
  JObj(e6)
}

type MeterValue = { timestamp :: Str, sampled_value :: List[SampledValue] }

fn meter_value(timestamp :: Str, sv :: List[SampledValue]) -> MeterValue {
  { timestamp: timestamp, sampled_value: sv }
}

fn meter_value_to_json(mv :: MeterValue) -> jv.Json {
  JObj([("timestamp", JStr(mv.timestamp)), ("sampledValue", JList(list.map(mv.sampled_value, sampled_value_to_json)))])
}

# ---- AuthorizationData (SendLocalList) --------------------------
type AuthorizationData = { id_tag :: Str, id_tag_info :: Option[IdTagInfo] }

fn authorization_data(id_tag :: Str) -> AuthorizationData {
  { id_tag: id_tag, id_tag_info: None }
}

fn authorization_data_with(id_tag :: Str, info :: IdTagInfo) -> AuthorizationData {
  { id_tag: id_tag, id_tag_info: Some(info) }
}

fn authorization_data_to_json(a :: AuthorizationData) -> jv.Json {
  let base := [("idTag", JStr(a.id_tag))]
  match a.id_tag_info {
    None => JObj(base),
    Some(i) => JObj(list.concat(base, [("idTagInfo", id_tag_info_to_json(i))])),
  }
}

# ---- KeyValue (GetConfiguration) --------------------------------
type KeyValue = { key :: Str, readonly :: Bool, value :: Option[Str] }

fn key_value(key :: Str, readonly :: Bool, value :: Option[Str]) -> KeyValue {
  { key: key, readonly: readonly, value: value }
}

fn key_value_to_json(k :: KeyValue) -> jv.Json {
  let base := [("key", JStr(k.key)), ("readonly", JBool(k.readonly))]
  match k.value {
    None => JObj(base),
    Some(v) => JObj(list.concat(base, [("value", JStr(v))])),
  }
}

# ---- ChargingSchedulePeriod -------------------------------------
type ChargingSchedulePeriod = { start_period :: Int, limit :: Float, number_phases :: Option[Int] }

fn charging_schedule_period(start_period :: Int, limit :: Float) -> ChargingSchedulePeriod {
  { start_period: start_period, limit: limit, number_phases: None }
}

fn charging_schedule_period_to_json(p :: ChargingSchedulePeriod) -> jv.Json {
  let base := [("startPeriod", JInt(p.start_period)), ("limit", JFloat(p.limit))]
  match p.number_phases {
    None => JObj(base),
    Some(n) => JObj(list.concat(base, [("numberPhases", JInt(n))])),
  }
}

# ---- ChargingSchedule -------------------------------------------
type ChargingSchedule = { duration :: Option[Int], start_schedule :: Option[Str], charging_rate_unit :: Str, charging_schedule_period :: List[ChargingSchedulePeriod], min_charging_rate :: Option[Float] }

fn charging_schedule(charging_rate_unit :: Str, periods :: List[ChargingSchedulePeriod]) -> ChargingSchedule {
  { duration: None, start_schedule: None, charging_rate_unit: charging_rate_unit, charging_schedule_period: periods, min_charging_rate: None }
}

fn charging_schedule_to_json(cs :: ChargingSchedule) -> jv.Json {
  let e0 := []
  let e1 := match cs.duration {
    None => e0,
    Some(d) => list.concat(e0, [("duration", JInt(d))]),
  }
  let e2 := match cs.start_schedule {
    None => e1,
    Some(s) => list.concat(e1, [("startSchedule", JStr(s))]),
  }
  let e3 := list.concat(e2, [("chargingRateUnit", JStr(cs.charging_rate_unit)), ("chargingSchedulePeriod", JList(list.map(cs.charging_schedule_period, charging_schedule_period_to_json)))])
  let e4 := match cs.min_charging_rate {
    None => e3,
    Some(r) => list.concat(e3, [("minChargingRate", JFloat(r))]),
  }
  JObj(e4)
}

# ---- ChargingProfile --------------------------------------------
type ChargingProfile = { charging_profile_id :: Int, transaction_id :: Option[Int], stack_level :: Int, charging_profile_purpose :: Str, charging_profile_kind :: Str, recurrency_kind :: Option[Str], valid_from :: Option[Str], valid_to :: Option[Str], charging_schedule :: ChargingSchedule }

fn charging_profile(charging_profile_id :: Int, stack_level :: Int, charging_profile_purpose :: Str, charging_profile_kind :: Str, schedule :: ChargingSchedule) -> ChargingProfile {
  { charging_profile_id: charging_profile_id, transaction_id: None, stack_level: stack_level, charging_profile_purpose: charging_profile_purpose, charging_profile_kind: charging_profile_kind, recurrency_kind: None, valid_from: None, valid_to: None, charging_schedule: schedule }
}

fn charging_profile_to_json(cp :: ChargingProfile) -> jv.Json {
  let e0 := [("chargingProfileId", JInt(cp.charging_profile_id))]
  let e1 := match cp.transaction_id {
    None => e0,
    Some(t) => list.concat(e0, [("transactionId", JInt(t))]),
  }
  let e2 := list.concat(e1, [("stackLevel", JInt(cp.stack_level)), ("chargingProfilePurpose", JStr(cp.charging_profile_purpose)), ("chargingProfileKind", JStr(cp.charging_profile_kind))])
  let e3 := match cp.recurrency_kind {
    None => e2,
    Some(k) => list.concat(e2, [("recurrencyKind", JStr(k))]),
  }
  let e4 := match cp.valid_from {
    None => e3,
    Some(s) => list.concat(e3, [("validFrom", JStr(s))]),
  }
  let e5 := match cp.valid_to {
    None => e4,
    Some(s) => list.concat(e4, [("validTo", JStr(s))]),
  }
  let e6 := list.concat(e5, [("chargingSchedule", charging_schedule_to_json(cp.charging_schedule))])
  JObj(e6)
}

# ---- Internal helpers -------------------------------------------
fn add_opt_str(entries :: List[(Str, jv.Json)], key :: Str, v :: Option[Str]) -> List[(Str, jv.Json)] {
  match v {
    None => entries,
    Some(s) => list.concat(entries, [(key, JStr(s))]),
  }
}

