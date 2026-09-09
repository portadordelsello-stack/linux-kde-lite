# =============================================================================
# Linux KDE Lite — Imagen Docker con escritorio completo pre-instalado
# =============================================================================
# Esta imagen se construye UNA sola vez. Cada alumno recibe una copia
# con KDE Plasma, TigerVNC, noVNC, Google Chrome y Antigravity IDE
# ya instalados. Solo necesita ejecutar start-desktop.sh (~5 seg).
# =============================================================================

FROM mcr.microsoft.com/devcontainers/universal:2

# Evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Limpiar repositorios con llaves GPG rotas e instalar KDE + Chrome + VNC
# ---------------------------------------------------------------------------
RUN echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections \
    && rm -f /etc/apt/sources.list.d/yarn*.list 2>/dev/null || true \
    && rm -f /etc/apt/sources.list.d/github-cli*.list 2>/dev/null || true \
    && wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        kde-plasma-desktop \
        kwin-x11 \
        konsole \
        dolphin \
        tigervnc-standalone-server \
        tigervnc-common \
        novnc \
        websockify \
        autocutsel \
        xclip \
        dbus-x11 \
        x11-xserver-utils \
        xterm \
        curl \
        wget \
        xdotool \
        /tmp/google-chrome.deb \
    && rm -f /tmp/google-chrome.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's|exec -a "$0" "$HERE/chrome" "$@"|exec -a "$0" "$HERE/chrome" --disable-dev-shm-usage --disable-features=WebAssemblySIMD "$@"|' \
        /opt/google/chrome/google-chrome 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Instalar Google Antigravity IDE
# ---------------------------------------------------------------------------
RUN mkdir -p /opt/antigravity-ide \
    && curl -sL "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz" \
        | tar -xz -C /opt/antigravity-ide --strip-components=1 \
    && chown -R root:root /opt/antigravity-ide \
    && chmod -R a+rX /opt/antigravity-ide

# Wrapper ejecutable para Antigravity IDE
RUN printf '#!/usr/bin/env bash\nunset ELECTRON_RUN_AS_NODE\nexport DISPLAY="${DISPLAY:-:1}"\nif [ $# -eq 0 ]; then\n    set -- "/workspaces/linux-kde-lite"\nfi\nexec /opt/antigravity-ide/bin/antigravity-ide \\\n    --disable-gpu \\\n    --disable-dev-shm-usage \\\n    --no-sandbox \\\n    "$@"\n' > /usr/local/bin/antigravity-ide \
    && chmod +x /usr/local/bin/antigravity-ide \
    && ln -sf /usr/local/bin/antigravity-ide /usr/local/bin/antigravity

# Entrada de escritorio para Antigravity IDE y Antigravity Web Hub
RUN [ -f /opt/antigravity-ide/resources/app/resources/linux/code.png ] \
    && cp /opt/antigravity-ide/resources/app/resources/linux/code.png /usr/share/pixmaps/antigravity-ide.png \
    || true \
    && printf '[Desktop Entry]\nName=Antigravity IDE\nComment=Google Antigravity Code Editor\nExec=/usr/local/bin/antigravity-ide %%F\nIcon=/usr/share/pixmaps/antigravity-ide.png\nType=Application\nStartupNotify=false\nStartupWMClass=Antigravity-ide\nCategories=Development;IDE;TextEditor;\n' \
        > /usr/share/applications/antigravity-ide.desktop \
    && printf '[Desktop Entry]\nName=Antigravity Web Hub (Puerto 3000)\nComment=Google Antigravity 2.0 Web UI\nExec=google-chrome --new-window http://localhost:3000\nIcon=/usr/share/pixmaps/antigravity-ide.png\nType=Application\nStartupNotify=false\nCategories=Development;IDE;\n' \
        > /usr/share/applications/antigravity-web.desktop

# ---------------------------------------------------------------------------
# 4. Configurar noVNC: página de redirección automática
# ---------------------------------------------------------------------------
RUN printf '<!DOCTYPE html>\n<html lang="es">\n<head>\n    <meta charset="UTF-8">\n    <meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=remote">\n    <title>KDE Plasma Lite</title>\n</head>\n<body style="background-color: #1b1e20; color: #fff; font-family: sans-serif; text-align: center; padding-top: 50px;">\n    <h2>Iniciando KDE Plasma Desktop...</h2>\n    <p>Si no eres redirigido automáticamente, <a href="vnc.html?autoconnect=true&resize=remote" style="color: #3daee9;">haz clic aquí</a>.</p>\n</body>\n</html>\n' > /usr/share/novnc/index.html

# ---------------------------------------------------------------------------
# 5. Patch de portapapeles bidireccional en noVNC
# ---------------------------------------------------------------------------
RUN python3 -c '\
UI_JS = "/usr/share/novnc/app/ui.js"\n\
try:\n\
    with open(UI_JS, "r") as f:\n\
        content = f.read()\n\
    if "noVNC_clipboard_text\x27).addEventListener(\x27input\x27" not in content:\n\
        content = content.replace(\n\
            "document.getElementById(\"noVNC_clipboard_text\")\n            .addEventListener(\x27change\x27, UI.clipboardSend);",\n\
            "document.getElementById(\"noVNC_clipboard_text\").addEventListener(\x27change\x27, UI.clipboardSend);\n        document.getElementById(\"noVNC_clipboard_text\").addEventListener(\x27input\x27, UI.clipboardSend);\n\n        window.addEventListener(\x27paste\x27, (e) => {\n            if (document.activeElement && document.activeElement.id === \"noVNC_clipboard_text\") return;\n            const p = e.clipboardData ? e.clipboardData.getData(\"text\") : null;\n            if (p && UI.rfb) { document.getElementById(\"noVNC_clipboard_text\").value = p; UI.rfb.clipboardPasteFrom(p); }\n        });\n        window.addEventListener(\x27focus\x27, () => {\n            if (navigator.clipboard && navigator.clipboard.readText && UI.rfb) {\n                navigator.clipboard.readText().then(t => { if (t && t !== document.getElementById(\"noVNC_clipboard_text\").value) { document.getElementById(\"noVNC_clipboard_text\").value = t; UI.rfb.clipboardPasteFrom(t); } }).catch(() => {});\n            }\n        });"\n\
        )\n\
        content = content.replace(\n\
            "document.getElementById(\x27noVNC_clipboard_text\x27).value = e.detail.text;\n        Log.Debug(\"<< UI.clipboardReceive\");",\n\
            "document.getElementById(\x27noVNC_clipboard_text\x27).value = e.detail.text;\n        if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(e.detail.text).catch(() => {}); }\n        Log.Debug(\"<< UI.clipboardReceive\");"\n\
        )\n\
        with open(UI_JS, "w") as f:\n\
            f.write(content)\n\
except Exception as err:\n\
    print(f"Clipboard patch skipped: {err}")\n\
' 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Configurar VNC para el usuario codespace
# ---------------------------------------------------------------------------
USER codespace

# Accesos directos de escritorio
RUN mkdir -p /home/codespace/Desktop \
    && cp /usr/share/applications/google-chrome.desktop /home/codespace/Desktop/ 2>/dev/null || true \
    && chmod +x /home/codespace/Desktop/google-chrome.desktop 2>/dev/null || true \
    && cp /usr/share/applications/antigravity-ide.desktop /home/codespace/Desktop/ 2>/dev/null || true \
    && chmod +x /home/codespace/Desktop/antigravity-ide.desktop 2>/dev/null || true \
    && cp /usr/share/applications/antigravity-web.desktop /home/codespace/Desktop/ 2>/dev/null || true \
    && chmod +x /home/codespace/Desktop/antigravity-web.desktop 2>/dev/null || true

# Configuración de VNC
RUN mkdir -p /home/codespace/.vnc \
    && printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexport XDG_SESSION_TYPE=x11\nexport XDG_CURRENT_DESKTOP=KDE\nexport DESKTOP_SESSION=plasma\nexport QT_QPA_PLATFORM=xcb\n\nif command -v kwriteconfig5 >/dev/null 2>&1; then\n    kwriteconfig5 --file kwinrc --group Compositing --key Enabled false\n    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false\n    kwriteconfig5 --file kscreenlockerrc --group Daemon --key LockOnResume false\n    kwriteconfig5 --file kscreenlockerrc --group Daemon --key Timeout 0\nfi\n\nxset s off 2>/dev/null || true\nxset s noblank 2>/dev/null || true\n\n[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"\n\nif command -v vncconfig >/dev/null 2>&1; then\n    vncconfig -nowin &\nfi\nif command -v autocutsel >/dev/null 2>&1; then\n    autocutsel -fork\n    autocutsel -selection CLIPBOARD -fork\nfi\n\nif [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then\n    eval $(dbus-launch --sh-syntax --exit-with-session)\nfi\n\nkwin_x11 --replace &\n\nexec startplasma-x11\n' \
        > /home/codespace/.vnc/xstartup \
    && chmod +x /home/codespace/.vnc/xstartup \
    && printf 'geometry=1280x800\ndepth=24\nlocalhost=yes\n' \
        > /home/codespace/.vnc/config

USER root

# ---------------------------------------------------------------------------
# 7. Script global de inicio del escritorio: /usr/local/bin/start-desktop.sh
# ---------------------------------------------------------------------------
COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh \
    && ln -sf /usr/local/bin/start-desktop.sh /usr/local/bin/start-desktop

# ---------------------------------------------------------------------------
# 8. Autostart secundario: garantiza arranque en cualquier conexión/terminal
# ---------------------------------------------------------------------------
COPY 01-start-desktop.sh /etc/profile.d/01-start-desktop.sh
RUN chmod +x /etc/profile.d/01-start-desktop.sh



