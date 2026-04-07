#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
archive_path="$project_root/.codex-run/linux-server.tar.gz"

: "${DEPLOY_SSH_HOST:?Missing DEPLOY_SSH_HOST}"
: "${DEPLOY_SSH_PORT:?Missing DEPLOY_SSH_PORT}"
: "${DEPLOY_SSH_USER:?Missing DEPLOY_SSH_USER}"
: "${DEPLOY_TARGET_DIR:?Missing DEPLOY_TARGET_DIR}"
: "${DEPLOY_RESTART_COMMAND:?Missing DEPLOY_RESTART_COMMAND}"

if [ ! -f "$archive_path" ]; then
  echo "Linux server archive not found: $archive_path" >&2
  exit 1
fi

release_id="$(date -u +%Y%m%d%H%M%S)"
remote_archive="/tmp/duel-linux-server-${release_id}.tar.gz"

scp -P "$DEPLOY_SSH_PORT" "$archive_path" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}:$remote_archive"

ssh -p "$DEPLOY_SSH_PORT" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" \
  "set -euo pipefail; \
   target_dir='$DEPLOY_TARGET_DIR'; \
   release_id='$release_id'; \
   remote_archive='$remote_archive'; \
   staging_dir=\"\$target_dir/.deploy-staging/\$release_id\"; \
   backup_dir=\"\$target_dir/.deploy-backups/\$release_id\"; \
   mkdir -p \"\$target_dir\"; \
   rm -rf \"\$staging_dir\"; \
   mkdir -p \"\$staging_dir\"; \
   tar -xzf \"\$remote_archive\" -C \"\$staging_dir\"; \
   test -f \"\$staging_dir/DUEL.x86_64\"; \
   test -f \"\$staging_dir/DUEL.pck\"; \
   mkdir -p \"\$backup_dir\"; \
   if [ -f \"\$target_dir/DUEL.x86_64\" ]; then cp -f \"\$target_dir/DUEL.x86_64\" \"\$backup_dir/DUEL.x86_64\"; fi; \
   if [ -f \"\$target_dir/DUEL.pck\" ]; then cp -f \"\$target_dir/DUEL.pck\" \"\$backup_dir/DUEL.pck\"; fi; \
   mv -f \"\$staging_dir/DUEL.x86_64\" \"\$target_dir/DUEL.x86_64\"; \
   mv -f \"\$staging_dir/DUEL.pck\" \"\$target_dir/DUEL.pck\"; \
   chmod +x \"\$target_dir/DUEL.x86_64\"; \
   rm -rf \"\$staging_dir\"; \
   rm -f \"\$remote_archive\"; \
   $DEPLOY_RESTART_COMMAND"

echo "Linux server deployed to ${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}:${DEPLOY_TARGET_DIR}"
