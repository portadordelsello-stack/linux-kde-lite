if [ -z "${KDE_DESKTOP_STARTED:-}" ]; then
    export KDE_DESKTOP_STARTED=1
    if ! pgrep -f "websockify.*8080" >/dev/null 2>&1; then
        nohup /usr/local/bin/start-desktop.sh >/dev/null 2>&1 &
    fi
fi
