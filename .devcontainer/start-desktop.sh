#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NUM=":1"
VNC_PORT="5901"
WEB_PORT="6080"
LOG_DIR="$HOME/.vnc"
mkdir -p "$LOG_DIR"

echo "=========================================================="
echo " Iniciando KDE Plasma Lite Desktop"
echo "=========================================================="

# 1. Limpieza de archivo de lock si es huérfano
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

# 3. Desactivar bloqueo de pantalla de KDE
if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 0 2>/dev/null || true
fi

# 4. Limpieza de bloqueos huérfanos de X11 si no hay proceso corriendo
if [ -f "/tmp/.X11-unix/X1" ] || [ -f "/tmp/.X1-lock" ]; then
    if ! pgrep -f "Xvnc :1" > /dev/null 2>&1 && ! pgrep -f "Xtigervnc :1" > /dev/null 2>&1; then
        echo "Limpiando archivos de bloqueo antiguos..."
        rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
    fi
fi

# 5. Iniciar TigerVNC en pantalla :1
if pgrep -f "Xvnc :1" > /dev/null 2>&1 || pgrep -f "Xtigervnc :1" > /dev/null 2>&1; then
    echo "[!] El servidor VNC ya está activo en la pantalla ${DISPLAY_NUM} (puerto ${VNC_PORT})."
else
    echo "[+] Iniciando servidor TigerVNC en ${DISPLAY_NUM}..."
    vncserver ${DISPLAY_NUM} \
        -geometry 1366x768 \
        -depth 24 \
        -localhost yes \
        -SecurityTypes None \
        > "${LOG_DIR}/vncserver.log" 2>&1 || {
            echo "[-] Falló el inicio de vncserver. Ver log en: ${LOG_DIR}/vncserver.log"
            exit 1
        }
    echo "[+] Servidor VNC iniciado correctamente."
fi

# 6. Sincronización de portapapeles bidireccional
export DISPLAY="${DISPLAY_NUM}"
if command -v vncconfig >/dev/null 2>&1 && ! pgrep -f "vncconfig -nowin" >/dev/null 2>&1; then
    nohup vncconfig -nowin </dev/null >/dev/null 2>&1 &
fi
if command -v autocutsel >/dev/null 2>&1; then
    pgrep -f "autocutsel -fork" >/dev/null 2>&1 || autocutsel -fork
    pgrep -f "autocutsel -selection CLIPBOARD -fork" >/dev/null 2>&1 || autocutsel -selection CLIPBOARD -fork
fi

# 7. Iniciar websockify / noVNC en puertos 8080 y 6080
for PORT in 8080 6080; do
    if pgrep -f "websockify.*${PORT}" > /dev/null 2>&1; then
        echo "[!] websockify ya está corriendo en el puerto ${PORT}."
    else
        echo "[+] Iniciando puente web noVNC en el puerto ${PORT}..."
        websockify -D --web /usr/share/novnc "${PORT}" "localhost:${VNC_PORT}"
    fi
done

sleep 2

# 8. Asegurar visibilidad pública de los puertos en Codespaces
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
    gh codespace ports visibility 8080:public -c "$CODESPACE_NAME" 2>/dev/null || true
    gh codespace ports visibility 6080:public -c "$CODESPACE_NAME" 2>/dev/null || true
fi

echo "=========================================================="
echo " ¡Escritorio KDE Plasma Lite listo!"
echo "=========================================================="
echo " Acceso Web:"
echo " 1. En VS Code / Codespaces, abre la pestaña 'Ports' (Puertos)."
echo " 2. Busca el puerto 8080 (o 6080) y haz clic en el icono del globo terráqueo."
if [ -n "${CODESPACE_NAME:-}" ]; then
    echo " 3. URL directa en la nube:"
    echo "    https://${CODESPACE_NAME}-8080.app.github.dev/vnc.html?autoconnect=true&resize=remote"
fi
echo "=========================================================="
