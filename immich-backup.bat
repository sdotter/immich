@echo off
REM Run the WSL backup script
wsl -d Ubuntu -- bash -lc "cd '/mnt/d/[ Infra ]/docker/immich'; ./immich-backup.sh"
pause