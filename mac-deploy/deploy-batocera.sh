#!/usr/bin/env bash
set -euo pipefail
# -e = exit immediately on error
# -u = treat unset variables as an error
# -o pipefail = fail if any command in a pipeline fails

# --- Load configuration from config.env ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  source "$SCRIPT_DIR/config.env"   # Load variables from config.env
else
  echo "Missing config.env. Exiting." >&2
  exit 1
fi

# --- Default values if not set in config.env ---
: "${GITHUB_REPO:=https://github.com/jdruding/Batocera-Ultimarc-ServoStik-Conrol.git}"
: "${GIT_REF:=main}"
: "${BATOCERA_HOST:=batocera.local}"
: "${BATOCERA_SHARE:=share}"
: "${MOUNT_POINT:=/Volumes/BATOCERA}"
: "${SMB_USER:=}"
: "${SMB_PASS:=}"
: "${RSYNC_DELETE:=}"
: "${DRY_RUN:=}"
: "${DO_CHMOD_SSH:=}"
: "${SSH_USER:=root}"
: "${SSH_PORT:=22}"

# --- Internal paths ---
REPO_DIR="$SCRIPT_DIR/.repo"
GAME_START_REL="system/configs/emulationstation/scripts/game-start/restrictor-start.sh"
DEST_GAME_START="system/configs/emulationstation/scripts/game-start/restrictor-start.sh"

# --- Helper functions for colored output ---
log() { printf "\033[1;34m[deploy]\033[0m %s\n" "$*"; }  # Blue
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }   # Yellow
err() { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; } # Red

# --- Check that required commands exist ---
need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }
need git
need rsync

# --- Mount the Batocera SMB share if not already mounted ---
ensure_mount() {
  # Already mounted?
  if mount | grep -q "on $MOUNT_POINT "; then
    log "Share already mounted at $MOUNT_POINT"
    return 0
  fi

  # Try to prepare mountpoint
  if [[ ! -d "$MOUNT_POINT" ]]; then
    if mkdir -p "$MOUNT_POINT" 2>/dev/null; then
      :
    else
      warn "Cannot create $MOUNT_POINT (permission denied). Falling back to \$HOME/BATOCERA."
      MOUNT_POINT="$HOME/BATOCERA"
      mkdir -p "$MOUNT_POINT"
    fi
  fi

  # Pick SMB user (guest if blank)
  local user_spec
  if [[ -n "${SMB_USER}" ]]; then user_spec="${SMB_USER}"; else user_spec="guest"; fi

  local url="//${user_spec}@${BATOCERA_HOST}/${BATOCERA_SHARE}"
  log "Mounting SMB: $url → $MOUNT_POINT"
  if ! mount_smbfs "$url" "$MOUNT_POINT"; then
    err "Failed to mount SMB at $MOUNT_POINT. Verify host/share/credentials (BATOCERA_HOST=${BATOCERA_HOST}, BATOCERA_SHARE=${BATOCERA_SHARE})."
    exit 1
  fi
}


# --- Clone or update your GitHub repo locally ---
sync_repo() {
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating repo in $REPO_DIR"
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout "$GIT_REF"
    git -C "$REPO_DIR" pull --ff-only origin "$GIT_REF" || true
  else
    log "Cloning $GITHUB_REPO → $REPO_DIR"
    git clone --depth 1 --branch "$GIT_REF" "$GITHUB_REPO" "$REPO_DIR"
  fi

  # Ensure restrictor-start.sh is marked executable locally
  if [[ -f "$REPO_DIR/$GAME_START_REL" ]]; then
    chmod +x "$REPO_DIR/$GAME_START_REL" || true
  fi
}

# --- Defines what should be deployed ---
# Left side = repo path, right side = Batocera share path
deploy_map() {
  cat <<EOF
restrictor/    restrictor/
$GAME_START_REL    $DEST_GAME_START
EOF
}

# --- Copy files using rsync ---
deploy() {
  local rsync_flags="-avp"  # a=archive, v=verbose, p=preserve permissions
  [[ -n "$DRY_RUN" ]] && rsync_flags="$rsync_flags -n"       # Add dry-run if enabled
  [[ -n "$RSYNC_DELETE" ]] && rsync_flags="$rsync_flags --delete" # Mirror deletes if enabled

  # Force safe default permissions: directories 755, files 644
  rsync_flags="$rsync_flags --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r"

  # Process each mapping
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    src=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $2}')
    local src_abs="$REPO_DIR/$src"
    local dest_abs="$MOUNT_POINT/$dest"

    if [[ ! -e "$src_abs" ]]; then
      warn "Missing source: $src_abs"
      continue
    fi

    mkdir -p "$(dirname "$dest_abs")"
    log "Rsync: $src → $dest"
    rsync $rsync_flags "$src_abs" "$dest_abs"
  done < <(deploy_map)

  # Try to chmod the game-start script over SMB (sometimes ignored)
  if [[ -f "$MOUNT_POINT/$DEST_GAME_START" && -z "$DRY_RUN" ]]; then
    chmod +x "$MOUNT_POINT/$DEST_GAME_START" || \
      warn "chmod via SMB may be ignored; using SSH fallback if enabled."
  fi

  # Optional SSH chmod directly on Batocera
  if [[ -n "$DO_CHMOD_SSH" && -z "$DRY_RUN" ]]; then
    log "SSH chmod on Batocera to ensure execute bit"
    ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$BATOCERA_HOST" \
      "chmod +x /userdata/$DEST_GAME_START" || warn "SSH chmod failed"
  fi

  # Drop a timestamp file for traceability
  if [[ -d "$MOUNT_POINT" && -z "$DRY_RUN" ]]; then
    date +"%Y-%m-%d %H:%M:%S" > "$MOUNT_POINT/.last_batocera_servostik_deploy"
  fi
}

# --- Main flow ---
main() {
  ensure_mount    # Make sure the share is mounted
  sync_repo       # Clone/update the repo locally
  deploy          # Run rsync and optional chmod
  if [[ -n "$DRY_RUN" ]]; then
    warn "DRY_RUN enabled — no writes performed."
  else
    log "Deploy complete."
  fi
}

main "$@"
