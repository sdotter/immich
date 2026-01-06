@echo off
REM Run the WSL backup script
start "" /b wsl -d Ubuntu -- bash -lc "dbus-launch true >/dev/null 2>&1; cd '/mnt/d/[ Infra ]/docker/immich' && docker compose up -d"