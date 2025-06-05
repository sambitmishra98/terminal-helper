#!/usr/bin/env bash
# Helper: simplified rsync push/pull utilities
# Usage: source sync.sh to use set_sync_paths/rsync_to_remote/rsync_to_local
# Requires: LOCAL_NAME, REMOTE_NAME, RSYNC_HOST variables

set -euo pipefail
IFS=$'\n\t'

# You can override these in your ~/.bashrc:
: "${LOCAL_NAME:=local}"
: "${REMOTE_NAME:=$(hostname)}"
: "${RSYNC_HOST:=sambit@spitfire.engr.tamu.edu}"

# Usage: set_sync_paths <local_directory> <remote_directory>
set_sync_paths() {
  if [ $# -ne 2 ]; then
    printf "Usage: %s <local_dir> <remote_dir>\n" "${0##*/}" >&2
    exit 1
  fi

  local ld="$1" rd="$2"
  if [ ! -d "$ld" ]; then
    printf "\e[31mERROR: '%s' is not a directory!\e[0m\n" "$ld" >&2
    exit 1
  fi

  export SYNC_LOCAL="$ld"
  export SYNC_REMOTE="$rd"
  printf "[INFO] SYNC_LOCAL set to %s\n" "$SYNC_LOCAL"
  printf "[INFO] SYNC_REMOTE set to %s on host %s\n" "$SYNC_REMOTE" "$RSYNC_HOST"
}

# Push a single item from local → remote
# $1 = relative path under "${LOCAL_NAME}-to-${REMOTE_NAME}"
rsync_to_remote() {
  local item="$1"
  local src="$SYNC_LOCAL/${LOCAL_NAME}-to-${REMOTE_NAME}/$item"
  local dest="$SYNC_REMOTE/${LOCAL_NAME}-to-${REMOTE_NAME}/$item"

  if rsync -av -e ssh --delete "$src" "${RSYNC_HOST}:$dest"; then
    printf "\e[32m[OK] Synced %s ↠ %s:%s\e[0m\n" \
      "$src" "$RSYNC_HOST" "$dest"
  else
    printf "\e[31m[ERROR] Failed to sync %s to remote\e[0m\n" "$item" >&2
  fi
}

# Pull a single item from remote → local
# $1 = relative path under "${REMOTE_NAME}-to-${LOCAL_NAME}"
rsync_to_local() {
  local item="$1"
  local src="$SYNC_REMOTE/${REMOTE_NAME}-to-${LOCAL_NAME}/$item"
  local dest="$SYNC_LOCAL/${REMOTE_NAME}-to-${LOCAL_NAME}/$item"

  if rsync -av -e ssh --delete "${RSYNC_HOST}:$src" "$dest"; then
    printf "\e[32m[OK] Synced %s:%s ↠ %s\e[0m\n" \
      "$RSYNC_HOST" "$src" "$dest"
  else
    printf "\e[31m[ERROR] Failed to sync %s from remote\e[0m\n" "$item" >&2
  fi
}
