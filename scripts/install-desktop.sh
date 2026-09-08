#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " Instalación de KDE Plasma Minimal + TigerVNC + noVNC"
echo "=========================================================="

export DEBIAN_FRONTEND=noninteractive

echo "debconf debconf/frontend select Noninteractive" | sudo debconf-set-selections 2>/dev/null || true

echo "[1/4] Actualizando lista de paquetes e instalando dependencias..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    kde-plasma-desktop \
    kwin-x11 \
    konsole \
    dolphin \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    dbus-x11 \
    x11-xserver-utils \
    xterm \
    curl \
    wget \
    xdotool

if ! command -v google-chrome >/dev/null 2>&1; then
    echo "[+] Instalando Google Chrome oficial..."
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/google-chrome.deb
    rm -f /tmp/google-chrome.deb
    mkdir -p "$HOME/Desktop"
    cp /usr/share/applications/google-chrome.desktop "$HOME/Desktop/" 2>/dev/null || true
    chmod +x "$HOME/Desktop/google-chrome.desktop" 2>/dev/null || true
fi

# Optimizar Chrome para contenedores y evitar errores SIGILL con WebAssembly/Gemini
sudo sed -i 's|exec -a "$0" "$HERE/chrome" "$@"|exec -a "$0" "$HERE/chrome" --disable-dev-shm-usage --disable-features=WebAssemblySIMD "$@"|' /opt/google/chrome/google-chrome 2>/dev/null || true
sudo mount -o remount,size=2G /dev/shm 2>/dev/null || true

# Descargar e instalar Google Antigravity IDE (2.5.5) oficial
if [ ! -d "/opt/antigravity-ide" ]; then
    echo "[+] Instalando Google Antigravity IDE (v2.5.5)..."
    sudo mkdir -p /opt/antigravity-ide
    curl -sL "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz" | sudo tar -xz -C /opt/antigravity-ide --strip-components=1
    sudo chown -R root:root /opt/antigravity-ide
    sudo chmod -R a+rX /opt/antigravity-ide
fi

# Configurar wrappers y accesos directos
echo "[+] Configurando wrappers y accesos directos de Antigravity IDE..."
sudo bash -c 'cat << "EOF" > /usr/local/bin/antigravity-ide
#!/usr/bin/env bash
unset ELECTRON_RUN_AS_NODE
export DISPLAY="${DISPLAY:-:1}"
if [ $# -eq 0 ]; then
    set -- "/workspaces/linux-kde-lite"
fi
exec /opt/antigravity-ide/bin/antigravity-ide \
    --disable-gpu \
    --disable-dev-shm-usage \
    --no-sandbox \
    "$@"
EOF
chmod +x /usr/local/bin/antigravity-ide'

sudo ln -sf /usr/local/bin/antigravity-ide /usr/local/bin/antigravity

# Configurar iconos y entradas de escritorio
mkdir -p "$HOME/Desktop"
[ -f "/opt/antigravity-ide/resources/app/resources/linux/code.png" ] && sudo cp /opt/antigravity-ide/resources/app/resources/linux/code.png /usr/share/pixmaps/antigravity-ide.png 2>/dev/null || true

sudo bash -c 'cat << "EOF" > /usr/share/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity Code Editor
Exec=/usr/local/bin/antigravity-ide %F
Icon=/usr/share/pixmaps/antigravity-ide.png
Type=Application
StartupNotify=false
StartupWMClass=Antigravity-ide
Categories=Development;IDE;TextEditor;
EOF'

cp /usr/share/applications/antigravity-ide.desktop "$HOME/Desktop/" 2>/dev/null || true
chmod +x "$HOME/Desktop/antigravity-ide.desktop" 2>/dev/null || true

echo "[2/4] Configurando entorno VNC y credenciales..."
echo "$USER:$USER" | sudo chpasswd 2>/dev/null || true
mkdir -p "$HOME/.vnc"

cat << 'EOF' > "$HOME/.vnc/xstartup"
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
export DESKTOP_SESSION=plasma
export QT_QPA_PLATFORM=xcb

# Desactivar efectos 3D de composición para máxima fluidez y menor consumo en VNC
if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file kwinrc --group Compositing --key Enabled false
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume false
    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 0
fi

xset s off 2>/dev/null || true
xset s noblank 2>/dev/null || true

[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"

# Iniciar bus de sesión D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Iniciar gestor de ventanas KWin (para barras de título y movimiento de ventanas)
kwin_x11 --replace &

exec startplasma-x11
EOF

chmod +x "$HOME/.vnc/xstartup"

echo "[3/4] Configurando opciones predeterminadas de TigerVNC..."
cat << 'EOF' > "$HOME/.vnc/config"
geometry=1280x800
depth=24
localhost=yes
EOF

echo "[4/4] Optimizando acceso web de noVNC..."
# Configurar redirección automática con autoconnect y escalado dinámico
if [ -d "/usr/share/novnc" ]; then
    sudo bash -c 'cat << "EOF" > /usr/share/novnc/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=remote">
    <title>KDE Plasma Lite</title>
</head>
<body style="background-color: #1b1e20; color: #fff; font-family: sans-serif; text-align: center; padding-top: 50px;">
    <h2>Iniciando KDE Plasma Desktop...</h2>
    <p>Si no eres redirigido automáticamente, <a href="vnc.html?autoconnect=true&resize=remote" style="color: #3daee9;">haz clic aquí</a>.</p>
</body>
</html>
EOF'
fi

echo "=========================================================="
echo " ¡Instalación completada con éxito!"
echo " Para iniciar el escritorio ejecuta: ./scripts/start-desktop.sh"
echo "=========================================================="

