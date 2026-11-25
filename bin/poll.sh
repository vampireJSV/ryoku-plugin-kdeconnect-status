#!/usr/bin/env bash
# Polls kdeconnectd over the user D-Bus for every paired device (reachable or
# not) and prints one line of JSON the service can parse directly:
#   {"devices":[{"id":str,"name":str,"reachable":bool,"charge":int,"charging":bool,"notifCount":int},...]}
# Read-only: every busctl call here is a Get/call on kdeconnectd's own
# read-only properties and methods, nothing is ever set or sent.
# Actions (messages, share, ping...) live in service/Main.qml, not here.
set -euo pipefail

fail_json() {
    printf '{"devices":[]}\n'
    exit 0
}

command -v busctl >/dev/null 2>&1 || fail_json
command -v jq >/dev/null 2>&1 || fail_json

DEST=org.kde.kdeconnect

# All paired device ids (onlyReachable=false, onlyPaired=true).
IDS=$(busctl --user --json=short call "$DEST" /modules/kdeconnect \
    org.kde.kdeconnect.daemon devices bb false true 2>/dev/null \
    | jq -r '.data[0][]? // empty') || fail_json

[ -n "$IDS" ] || fail_json

get_prop() {
    # $1 = object path, $2 = interface, $3 = property
    busctl --user --json=short get-property "$DEST" "$1" "$2" "$3" 2>/dev/null \
        | jq -r '.data' 2>/dev/null || true
}

while IFS= read -r DEVID; do
    [ -n "$DEVID" ] || continue
    BASE="/modules/kdeconnect/devices/$DEVID"

    NAME=$(get_prop "$BASE" org.kde.kdeconnect.device name)
    REACHABLE=$(get_prop "$BASE" org.kde.kdeconnect.device isReachable)
    CHARGE=$(get_prop "$BASE/battery" org.kde.kdeconnect.device.battery charge)
    CHARGING=$(get_prop "$BASE/battery" org.kde.kdeconnect.device.battery isCharging)
    NOTIF_COUNT=$(busctl --user --json=short call "$DEST" "$BASE/notifications" \
        org.kde.kdeconnect.device.notifications activeNotifications 2>/dev/null \
        | jq -r '.data[0] | length' 2>/dev/null || true)

    jq -nc \
        --arg id "$DEVID" \
        --arg name "${NAME:-}" \
        --argjson reachable "${REACHABLE:-false}" \
        --argjson charge "${CHARGE:--1}" \
        --argjson charging "${CHARGING:-false}" \
        --argjson notifCount "${NOTIF_COUNT:-0}" \
        '{id:$id,name:$name,reachable:$reachable,charge:$charge,charging:$charging,notifCount:$notifCount}'
done <<< "$IDS" | jq -sc '{devices:.}'
