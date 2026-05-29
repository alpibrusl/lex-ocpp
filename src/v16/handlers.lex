# lex-ocpp — OCPP 1.6 CP-side handlers for CS→CP commands
#
# Pure response builders for every CS→CP command. The charge point
# registers these (or overrides them) via route.register to handle
# CSMS-initiated requests.
#
# Each function:
#   - Takes the normalised payload (post-schema-validation)
#   - Returns route.HandlerResult (HOk or HErr)
#   - Has no effects — side-effecting overrides use route_io.register
#
# Default implementations return spec-compliant stub responses:
# "Accepted" where possible, "Rejected" or "NotSupported" otherwise.
# Override in your application when you need real behaviour.
#
# Effects: none.

import "lex-schema/json_value" as jv

import "../route"  as route
import "./enums"   as en
import "./commands" as cmd

# ---- CancelReservation ------------------------------------------

fn on_cancel_reservation(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.cancel_accepted()))]))
}

# ---- ChangeAvailability -----------------------------------------

fn on_change_availability(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.avail_status_accepted()))]))
}

# ---- ChangeConfiguration ----------------------------------------

fn on_change_configuration(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.cfg_accepted()))]))
}

# ---- ClearCache -------------------------------------------------

fn on_clear_cache(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.accepted()))]))
}

# ---- ClearChargingProfile ---------------------------------------

fn on_clear_charging_profile(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.ccp_accepted()))]))
}

# ---- GetCompositeSchedule ---------------------------------------
#
# Stub: returns Accepted with no schedule body. A real implementation
# would build a ChargingSchedule from active profiles.

fn on_get_composite_schedule(payload :: jv.Json) -> route.HandlerResult {
  let conn_id := match jv.get_field(payload, "connectorId") {
    Some(JInt(n)) => n,
    _             => 0,
  }
  HOk(JObj([
    ("status",      JStr(en.accepted())),
    ("connectorId", JInt(conn_id)),
  ]))
}

# ---- GetConfiguration -------------------------------------------
#
# Stub: returns empty lists. Override to expose your config keys.

fn on_get_configuration(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([
    ("configurationKey", JList([])),
    ("unknownKey",       JList([])),
  ]))
}

# ---- GetDiagnostics ---------------------------------------------

fn on_get_diagnostics(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([]))
}

# ---- GetLocalListVersion ----------------------------------------

fn on_get_local_list_version(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("listVersion", JInt(0))]))
}

# ---- RemoteStartTransaction -------------------------------------

fn on_remote_start_transaction(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.accepted()))]))
}

# ---- RemoteStopTransaction --------------------------------------

fn on_remote_stop_transaction(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.accepted()))]))
}

# ---- ReserveNow -------------------------------------------------

fn on_reserve_now(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.rsv_accepted()))]))
}

# ---- Reset ------------------------------------------------------
#
# Returns Accepted immediately; a real CP would schedule the reset.

fn on_reset(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.accepted()))]))
}

# ---- SendLocalList ----------------------------------------------

fn on_send_local_list(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.upd_accepted()))]))
}

# ---- SetChargingProfile -----------------------------------------

fn on_set_charging_profile(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.cps_accepted()))]))
}

# ---- TriggerMessage ---------------------------------------------

fn on_trigger_message(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.trg_accepted()))]))
}

# ---- UnlockConnector --------------------------------------------

fn on_unlock_connector(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.unlock_unlocked()))]))
}

# ---- UpdateFirmware ---------------------------------------------

fn on_update_firmware(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([]))
}

# ---- DataTransfer (bidirectional) --------------------------------

fn on_data_transfer(_payload :: jv.Json) -> route.HandlerResult {
  HOk(JObj([("status", JStr(en.dt_accepted()))]))
}

# ---- Registration helper ----------------------------------------
#
# Register all default CS→CP handlers onto a pure registry at once.
# Callers can override individual actions after calling this.

fn register_defaults(reg :: route.Registry) -> route.Registry {
  let r0  := route.handler(reg,  "CancelReservation",      on_cancel_reservation)
  let r1  := route.handler(r0,   "ChangeAvailability",     on_change_availability)
  let r2  := route.handler(r1,   "ChangeConfiguration",    on_change_configuration)
  let r3  := route.handler(r2,   "ClearCache",             on_clear_cache)
  let r4  := route.handler(r3,   "ClearChargingProfile",   on_clear_charging_profile)
  let r5  := route.handler(r4,   "GetCompositeSchedule",   on_get_composite_schedule)
  let r6  := route.handler(r5,   "GetConfiguration",       on_get_configuration)
  let r7  := route.handler(r6,   "GetDiagnostics",         on_get_diagnostics)
  let r8  := route.handler(r7,   "GetLocalListVersion",    on_get_local_list_version)
  let r9  := route.handler(r8,   "RemoteStartTransaction", on_remote_start_transaction)
  let r10 := route.handler(r9,   "RemoteStopTransaction",  on_remote_stop_transaction)
  let r11 := route.handler(r10,  "ReserveNow",             on_reserve_now)
  let r12 := route.handler(r11,  "Reset",                  on_reset)
  let r13 := route.handler(r12,  "SendLocalList",          on_send_local_list)
  let r14 := route.handler(r13,  "SetChargingProfile",     on_set_charging_profile)
  let r15 := route.handler(r14,  "TriggerMessage",         on_trigger_message)
  let r16 := route.handler(r15,  "UnlockConnector",        on_unlock_connector)
  let r17 := route.handler(r16,  "UpdateFirmware",         on_update_firmware)
  route.handler(r17, "DataTransfer", on_data_transfer)
}
