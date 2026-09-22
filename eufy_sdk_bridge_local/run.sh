#!/bin/sh
# Einstieg der App: App-Optionen (/data/options.json) → Umgebungsvariablen der Bridge, dann starten.
# Grundlage: run.sh aus mega-yfue/ha-eufy-sdk-addon (eufy_sdk_bridge_dev), MIT.
set -e

OPTS=/data/options.json
SUPERVISOR_API="${SUPERVISOR:-http://supervisor}"
opt() { jq -r "$1" "$OPTS"; }

# Sitzung, Push-Registrierung (.eufy-fcm.json) und Ereignisbilder legt die Bridge neben die
# Sitzungsdatei. /config ist der app_config-Ordner, auf dem Host /app_configs/<slug>/.
DATA_DIR=/config
mkdir -p "$DATA_DIR"

export EUFY_EMAIL="$(opt '.email // ""')"
export EUFY_PASSWORD="$(opt '.password // ""')"
export EUFY_COUNTRY="$(opt '.country // "DE"')"
export EUFY_SESSION="$DATA_DIR/.eufy-session.json"
export BRIDGE_HOST="0.0.0.0"

openudid="$(opt '.openudid // ""')"
[ -n "$openudid" ] && export BRIDGE_OPENUDID="$openudid"

export EUFY_POLL_MS="$(opt '.poll_ms // 600000')"
export STREAM_IDLE_MS="$(opt '.stream_idle_ms // 300000')"
export RTSP_IDLE_OFF_MS="$(opt '.rtsp_idle_off_ms // 300000')"
[ "$(opt '.prewarm // false')" = "true" ] && export BRIDGE_PREWARM=1
[ "$(opt '.event_log // true')" = "false" ] && export BRIDGE_EVENT_LOG=0
[ "$(opt '.debug // false')" = "true" ] && export BRIDGE_DEBUG=1
[ "$(opt '.debug_p2p // false')" = "true" ] && export BRIDGE_DEBUG_P2P=1

# Weitere Variablen als NAME=WERT (Schema prüft das Format). Überschreiben alles oben.
env_list="$(opt '.env_vars // [] | .[]')"
if [ -n "$env_list" ]; then
  echo "$env_list" | while IFS= read -r kv; do echo "[app] env ${kv%%=*}"; done
  # Eine Zeile pro Variable, ohne Shell-Auswertung des Werts.
  while IFS= read -r kv; do
    [ -n "$kv" ] && export "${kv%%=*}=${kv#*=}"
  done <<EOF
$env_list
EOF
fi

echo "[app] bridge commit $(cat /app/BRIDGE_COMMIT 2>/dev/null || echo ?), SDK $(jq -r .version /app/node_modules/@mega-yfue/eufy-sdk/package.json)"
[ -f "$EUFY_SESSION" ] && echo "[app] vorhandene Sitzung in $DATA_DIR wird benutzt" || echo "[app] keine Sitzung in $DATA_DIR, Bridge meldet sich neu an"

# Supervisor-Discovery. Anders als das Original: Ist ein Port nicht auf dem Host veröffentlicht,
# wird der interne Hostname gemeldet statt der Docker-Gateway-Adresse (die liefe dann ins Leere).
register_discovery() {
  [ -n "${SUPERVISOR_TOKEN:-}" ] || { echo "[app] kein SUPERVISOR_TOKEN, keine Discovery"; return; }
  auth="Authorization: Bearer ${SUPERVISOR_TOKEN}"
  info="$(curl -fsS -H "$auth" "${SUPERVISOR_API}/addons/self/info")" || { echo "[app] App-Info nicht lesbar, keine Discovery"; return; }
  net="$(curl -fsS -H "$auth" "${SUPERVISOR_API}/network/info")" || net='{"data":{}}'
  hostname="$(printf '%s' "$info" | jq -r '.data.hostname // empty')"
  gateway="$(printf '%s' "$net" | jq -r '.data.docker.gateway // empty')"
  bridge_mapped="$(printf '%s' "$info" | jq -r '.data.network["3000/tcp"] // empty')"
  rtsp_mapped="$(printf '%s' "$info" | jq -r '.data.network["8554/tcp"] // empty')"

  if [ -n "$bridge_mapped" ] && [ -n "$rtsp_mapped" ] && [ -n "$gateway" ]; then
    host="$gateway"; port="$bridge_mapped"; rtsp="$rtsp_mapped"
  else
    host="$hostname"; port=3000; rtsp=8554
  fi

  payload="$(jq -cn --arg host "$host" --argjson port "$port" --argjson rtsp "$rtsp" \
    '{service: "eufy_sdk", config: {host: $host, port: $port, go2rtc_rtsp_port: $rtsp}}')"
  if curl -fsS -X POST -H "$auth" -H "Content-Type: application/json" -d "$payload" \
      "${SUPERVISOR_API}/discovery" >/dev/null; then
    echo "[app] Discovery gemeldet: ${host}:${port}, RTSP ${host}:${rtsp}"
  else
    echo "[app] Discovery fehlgeschlagen"
  fi
}

wait_for_bridge() {
  i=0
  until curl -fsS "http://127.0.0.1:${BRIDGE_PORT:-3000}/healthz" >/dev/null 2>&1; do
    kill -0 "$bridge_pid" 2>/dev/null || { echo "[app] Bridge beendet, keine Discovery"; return 1; }
    i=$((i + 1)); [ "$i" -ge 30 ] && { echo "[app] Bridge nach 30 s nicht bereit, keine Discovery"; return 1; }
    sleep 1
  done
}

/usr/local/bin/eufy-sdk-bridge &
bridge_pid="$!"

stop_bridge() {
  kill -TERM "$bridge_pid" 2>/dev/null || true
  wait "$bridge_pid"
}
trap stop_bridge TERM INT

( wait_for_bridge && register_discovery ) &

wait "$bridge_pid"
