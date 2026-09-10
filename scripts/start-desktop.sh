#!/usr/bin/env bash
set -euo pipefail

# 0. Bloqueo atómico anti-concurrencia: previene múltiples ejecuciones simultáneas
START_LOCK="/tmp/.start-desktop-mutex.lock"
exec 200>"$START_LOCK"
if ! flock -n 200; then
    echo "[!] start-desktop.sh ya se encuentra en ejecución en otro proceso. Omitiendo."
    exit 0
fi

DISPLAY_NUM=":1"
DISP_INDEX="1"
VNC_PORT="5901"
WEB_PORT="6080"
LOG_DIR="$HOME/.vnc"
mkdir -p "$LOG_DIR"

echo "=========================================================="
echo " Iniciando KDE Plasma Lite Desktop"
echo "=========================================================="

# 1. Limpieza de archivo de lock de instalación si es huérfano
LOCK_FILE="/tmp/.install-desktop.lock"
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "[!] Instalación en curso (PID: $PID). Esperando finalización..."
        while kill -0 "$PID" 2>/dev/null; do
            sleep 3
        done
        echo "[+] Instalación concluida."
    else
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
fi

# 2. Memoria compartida para Chrome y Electron
sudo mount -o remount,size=2G /dev/shm 2>/dev/null || true

# 3. Iniciar servicio D-Bus del sistema si no está corriendo
if ! sudo service dbus status >/dev/null 2>&1; then
    echo "[+] Iniciando servicio D-Bus del sistema..."
    sudo service dbus start >/dev/null 2>&1 || true
fi

# 4. Desactivar bloqueo de pantalla de KDE
if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 0 2>/dev/null || true
fi

# 5. Asegurar permisos de directorio socket X11 y runtime dir
export XDG_RUNTIME_DIR="/tmp/runtime-${USER:-codespace}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
sudo mkdir -p /tmp/.X11-unix
sudo chown root:root /tmp/.X11-unix 2>/dev/null || true
sudo chmod 1777 /tmp/.X11-unix 2>/dev/null || true

# 6. Comprobar si VNC está activo; si no, limpiar residuos y arrancar
if ss -tlpn 2>/dev/null | grep -E "(:${VNC_PORT}\s)" >/dev/null 2>&1 || pgrep -x Xtigervnc >/dev/null 2>&1 || pgrep -x Xvnc >/dev/null 2>&1; then
    echo "[!] El servidor VNC ya está activo en la pantalla ${DISPLAY_NUM} (puerto ${VNC_PORT})."
else
    echo "[+] Limpiando bloqueos, sockets y PIDs antiguos de X11..."
    rm -f "/tmp/.X${DISP_INDEX}-lock" "/tmp/.X11-unix/X${DISP_INDEX}" "${LOG_DIR}"/*"${DISPLAY_NUM}.pid" 2>/dev/null || true
    sudo rm -f "/tmp/.X${DISP_INDEX}-lock" "/tmp/.X11-unix/X${DISP_INDEX}" 2>/dev/null || true

    echo "[+] Iniciando servidor TigerVNC en ${DISPLAY_NUM}..."
    setsid nohup vncserver "${DISPLAY_NUM}" \
        -geometry 1366x768 \
        -depth 24 \
        -localhost yes \
        -SecurityTypes None \
        -cleanstale \
        -noreset \
        </dev/null >> "${LOG_DIR}/vncserver.log" 2>&1 || {
            echo "[-] Falló el inicio de vncserver. Ver log en: ${LOG_DIR}/vncserver.log"
            exit 1
        }
    echo "[+] Servidor VNC iniciado correctamente."
fi

# Esperar a que el puerto VNC responda
for i in {1..10}; do
    if ss -tlpn 2>/dev/null | grep -E "(:${VNC_PORT}\s)" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# 7. Sincronización de portapapeles bidireccional
export DISPLAY="${DISPLAY_NUM}"
if command -v vncconfig >/dev/null 2>&1 && ! pgrep -x vncconfig >/dev/null 2>&1; then
    nohup vncconfig -nowin </dev/null >/dev/null 2>&1 &
fi
if command -v autocutsel >/dev/null 2>&1; then
    pgrep -x autocutsel >/dev/null 2>&1 || autocutsel -fork
    pgrep -x autocutsel >/dev/null 2>&1 || autocutsel -selection CLIPBOARD -fork
fi

# 8. Iniciar websockify / noVNC en puertos 8080 y 6080
for PORT in 8080 6080; do
    if ss -tlpn 2>/dev/null | grep -E "(:${PORT}\s)" >/dev/null 2>&1; then
        echo "[!] websockify ya está corriendo en el puerto ${PORT}."
    else
        echo "[+] Iniciando puente web noVNC en el puerto ${PORT}..."
        websockify -D --web /usr/share/novnc "${PORT}" "localhost:${VNC_PORT}"
    fi
done

sleep 1

# 9. Iniciar Antigravity Web Hub en puerto 3000
AGY_BIN="/usr/local/bin/agy"
if [ ! -f "$AGY_BIN" ] && [ -f "/home/codespace/.gemini/bin/agy" ]; then
    AGY_BIN="/home/codespace/.gemini/bin/agy"
fi
if [ ! -f "$AGY_BIN" ] && command -v agy >/dev/null 2>&1; then
    AGY_BIN="$(command -v agy)"
fi

# Auto-descarga de fallback si agy no existe aún
if [ ! -f "$AGY_BIN" ] && ! command -v "$AGY_BIN" >/dev/null 2>&1; then
    echo "[+] Descargando Antigravity CLI oficial (agy)..."
    TMP_DIR=$(mktemp -d)
    if curl -sL "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.2.0-5210873191596032/linux-x64/cli_linux_x64.tar.gz" | tar -xz -C "$TMP_DIR" 2>/dev/null; then
        sudo mv "$TMP_DIR/antigravity" /usr/local/bin/agy 2>/dev/null || mv "$TMP_DIR/antigravity" /home/codespace/.gemini/bin/agy 2>/dev/null || true
        sudo chmod +x /usr/local/bin/agy 2>/dev/null || chmod +x /home/codespace/.gemini/bin/agy 2>/dev/null || true
        mkdir -p /home/codespace/.gemini/bin 2>/dev/null || true
        ln -sf /usr/local/bin/agy /home/codespace/.gemini/bin/agy 2>/dev/null || true
        [ -f "/usr/local/bin/agy" ] && AGY_BIN="/usr/local/bin/agy"
        [ -f "/home/codespace/.gemini/bin/agy" ] && AGY_BIN="/home/codespace/.gemini/bin/agy"
    fi
    rm -rf "$TMP_DIR" 2>/dev/null || true
fi

if [ -f "$AGY_BIN" ] || command -v "$AGY_BIN" >/dev/null 2>&1; then
    if ! ss -tlpn 2>/dev/null | grep -E "(:3000\s)" >/dev/null 2>&1; then
        echo "[+] Iniciando Antigravity 2.0 Web Hub en el puerto 3000..."
        export DISPLAY="${DISPLAY_NUM:-:1}"
        unset BROWSER
        nohup "$AGY_BIN" --hub --hub-port=3000 --app_data_dir=antigravity --add-dir=/workspaces/linux-kde-lite </dev/null >"${LOG_DIR}/antigravity-hub.log" 2>&1 &
    fi
fi

# 10. Asegurar visibilidad pública de los puertos en Codespaces con reintentos
ensure_port_public() {
    local port="$1"
    if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
        for attempt in {1..8}; do
            if gh codespace ports visibility "${port}:public" -c "$CODESPACE_NAME" >/dev/null 2>&1; then
                echo "[+] Puerto ${port} confirmado como público."
                return 0
            fi
            sleep 2
        done
        echo "[!] Advertencia: No se pudo verificar visibilidad pública para puerto ${port}."
    fi
}

if [ -n "${CODESPACE_NAME:-}" ]; then
    echo "[+] Verificando visibilidad pública de puertos en GitHub Codespaces..."
    ensure_port_public 8080
    ensure_port_public 6080
    ensure_port_public 3000
fi

echo "=========================================================="
echo " ¡Escritorio KDE Plasma Lite y Antigravity Web listos!"
echo "=========================================================="
echo " Acceso Web:"
echo " 1. Escritorio KDE (noVNC): https://${CODESPACE_NAME:-codespace}-8080.app.github.dev/vnc.html"
echo " 2. Escritorio KDE Alt:     https://${CODESPACE_NAME:-codespace}-6080.app.github.dev/vnc.html"
echo " 3. Antigravity 2.0 Hub:    https://${CODESPACE_NAME:-codespace}-3000.app.github.dev/"
echo "=========================================================="
