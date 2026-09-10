# Comprobar si VNC (puerto 5901) o websockify (puerto 8080) no estan escuchando
if ! ss -tlpn 2>/dev/null | grep -E "(:5901\s)" >/dev/null 2>&1 || ! ss -tlpn 2>/dev/null | grep -E "(:8080\s)" >/dev/null 2>&1; then
    nohup /usr/local/bin/start-desktop.sh >/dev/null 2>&1 &
fi
