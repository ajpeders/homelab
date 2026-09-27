# shellcheck shell=bash
# Load host config (plain KEY=VALUE lines) from services/.env into the
# environment, WITHOUT overriding anything the caller already exported — so a
# one-off `BACKUP_REMOTE_HOST=x ./bin/backup` still wins. Needs $REPO set.
while IFS= read -r _l || [[ -n $_l ]]; do
  [[ $_l =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
  [[ -n ${!BASH_REMATCH[1]+x} ]] || export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
done < "$REPO/services/.env"
unset _l
