#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NUM=":1"
VNC_PORT="5901"
WEB_PORT="6080"

echo "=== Estado de KDE Plasma Desktop ==="

# Verificar VNC
if pgrep -f "Xvnc :1" > /dev/null 2>&1 || pgrep -f "Xtigervnc :1" > /dev/null 2>&1; then
    echo "  [ACTIVO] Servidor VNC en ${DISPLAY_NUM} (puerto ${VNC_PORT})"
else
    echo "  [INACTIVO] Servidor VNC no está corriendo."
fi

# Verificar noVNC
for P in 8080 6080; do
    if pgrep -f "websockify.*${P}" > /dev/null 2>&1; then
        echo "  [ACTIVO] noVNC / Websockify escuchando en el puerto ${P}"
    else
        echo "  [INACTIVO] noVNC no está corriendo en el puerto ${P}."
    fi
done

# Verificar KWin / Plasma
if pgrep -f "plasmashell" > /dev/null 2>&1; then
    echo "  [ACTIVO] Shell de KDE Plasma (plasmashell) ejecutándose."
else
    echo "  [INFO] plasmashell no detectado en memoria."
fi

# Verificar Gestor de Ventanas (KWin)
if pgrep -f "kwin_x11" > /dev/null 2>&1; then
    echo "  [ACTIVO] Gestor de ventanas (kwin_x11) activo (barras de título y bordes)."
else
    echo "  [ALERTA] Gestor de ventanas (kwin_x11) inactivo."
fi

echo "====================================="

