rcon-cli say "Backup process should be complete"

# Keep only the 12 most recent backups
ls -t /backups/*.tgz 2>/dev/null | tail -n +13 | xargs -r rm --
