#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Asegurar visibilidad pública de puertos en GitHub Codespaces
# =============================================================================
# Puertos esenciales definidos en el entorno:
# - 8080: KDE Desktop noVNC
# - 6080: KDE Desktop Alternate noVNC
# - 3000: Antigravity 2.0 Web Hub
TARGET_PORTS=(8080 6080 3000)

LOCK_FILE="/tmp/.ensure-ports-public.lock"
exec 201>"$LOCK_FILE"
if ! flock -n 201; then
    # Ya hay otra instancia verificando visibilidad de puertos
    exit 0
fi

if [ -z "${CODESPACE_NAME:-}" ]; then
    # No es un entorno GitHub Codespaces
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "[!] GitHub CLI (gh) no está disponible en este entorno."
    exit 0
fi

get_private_ports() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r '.[] | select(.visibility != "public") | .sourcePort' 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
try:
    data = json.loads(sys.argv[1])
    for item in data:
        if item.get("visibility") != "public":
            print(item.get("sourcePort", ""))
except Exception:
    pass
' "$json" 2>/dev/null || true
    fi
}

get_port_visibility() {
    local json="$1"
    local target="$2"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r ".[] | select(.sourcePort == $target) | .visibility" 2>/dev/null || echo ""
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c '
import sys, json
try:
    data = json.loads(sys.argv[1])
    for item in data:
        if item.get("sourcePort") == int(sys.argv[2]):
            print(item.get("visibility", ""))
            break
except Exception:
    pass
' "$json" "$target" 2>/dev/null || echo ""
    fi
}

check_and_update_ports() {
    local ports_json
    ports_json=$(gh codespace ports -c "$CODESPACE_NAME" --json sourcePort,visibility 2>/dev/null || echo "[]")

    if [ -z "$ports_json" ] || [ "$ports_json" = "[]" ] || [ "$ports_json" = "null" ]; then
        return 1
    fi

    local to_update=()
    local private_ports
    private_ports=$(get_private_ports "$ports_json")

    for p in $private_ports; do
        if [ -n "$p" ] && [ "$p" != "null" ]; then
            to_update+=("${p}:public")
        fi
    done

    if [ ${#to_update[@]} -gt 0 ]; then
        echo "[+] Cambiando visibilidad a pública para puertos: ${to_update[*]}"
        gh codespace ports visibility "${to_update[@]}" -c "$CODESPACE_NAME" >/dev/null 2>&1 || true
    fi

    # Comprobar si todos los puertos objetivo están presentes y públicos
    ports_json=$(gh codespace ports -c "$CODESPACE_NAME" --json sourcePort,visibility 2>/dev/null || echo "[]")
    local all_ready=true
    for tp in "${TARGET_PORTS[@]}"; do
        local vis
        vis=$(get_port_visibility "$ports_json" "$tp")
        if [ "$vis" != "public" ]; then
            all_ready=false
            break
        fi
    done

    if [ "$all_ready" = true ]; then
        return 0
    else
        return 2
    fi
}

# Monitoreo con reintentos para dar tiempo a que los túneles de Codespaces estén activos
MAX_ATTEMPTS=60 # 60 * 3s = hasta 180 segundos (3 minutos)
attempt=1

while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    set +e
    check_and_update_ports
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "[+] Confirmado: Todos los puertos del sistema (${TARGET_PORTS[*]}) están públicos."
        exit 0
    fi

    sleep 3
    attempt=$((attempt + 1))
done

echo "[!] Tiempo de espera agotado: se intentó actualizar los puertos pero algunos aún no están listos."
