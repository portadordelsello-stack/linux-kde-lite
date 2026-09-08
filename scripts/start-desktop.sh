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

# Ampliar memoria compartida para evitar fallos de Chrome / WebAssembly en contenedores
sudo mount -o remount,size=2G /dev/shm 2>/dev/null || true

# Desactivar bloqueo de pantalla de KDE
if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume false 2>/dev/null || true
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 0 2>/dev/null || true
fi

# 1. Limpieza de bloqueos huérfanos si no hay proceso corriendo
if [ -f "/tmp/.X11-unix/X1" ] || [ -f "/tmp/.X1-lock" ]; then
    if ! pgrep -f "Xvnc :1" > /dev/null 2>&1 && ! pgrep -f "Xtigervnc :1" > /dev/null 2>&1; then
        echo "Limpiando archivos de bloqueo antiguos..."
        rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
    fi
fi

# 2. Iniciar TigerVNC en pantalla :1
if pgrep -f "Xvnc :1" > /dev/null 2>&1 || pgrep -f "Xtigervnc :1" > /dev/null 2>&1; then
    echo "[!] El servidor VNC ya está activo en la pantalla ${DISPLAY_NUM} (puerto ${VNC_PORT})."
else
    echo "[+] Iniciando servidor TigerVNC en ${DISPLAY_NUM}..."
    # Usar vncserver / tigervncserver sin requerir contraseña obligatoria en localhost
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

# 3. Iniciar websockify / noVNC en puerto 8080 (puerto web primario) y 6080 (secundario)
for PORT in 8080 6080; do
    if pgrep -f "websockify.*${PORT}" > /dev/null 2>&1; then
        echo "[!] websockify ya está corriendo en el puerto ${PORT}."
    else
        echo "[+] Iniciando puente web noVNC en el puerto ${PORT}..."
        websockify -D --web /usr/share/novnc "${PORT}" "localhost:${VNC_PORT}"
    fi
done

sleep 2

# Asegurar visibilidad pública de los puertos para evitar errores 404 en el navegador
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

