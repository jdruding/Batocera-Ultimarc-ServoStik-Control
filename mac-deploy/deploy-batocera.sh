#!/usr/bin/env bash
set -euo pipefail
# -e : exit immediately on error
# -u : treat unset variables as an error
# -o pipefail : fail if any command in a pipeline fails

# ===========
# CLI / ENV OVERRIDES (captured BEFORE loading config.env so they can win)
# ===========
CLI_GITHUB_REPO="${GITHUB_REPO-}"
CLI_GIT_REF="${GIT_REF-}"
CLI_BATOCERA_HOST="${BATOCERA_HOST-}"
CLI_BATOCERA_SHARE="${BATOCERA_SHARE-}"
CLI_MOUNT_POINT="${MOUNT_POINT-}"
CLI_SMB_USER="${SMB_USER-}"
CLI_SMB_PASS="${SMB_PASS-}"
CLI_RSYNC_DELETE="${RSYNC_DELETE-}"
CLI_DRY_RUN="${DRY_RUN-}"
CLI_DO_CHMOD_SSH="${DO_CHMOD_SSH-}"
CLI_SSH_USER="${SSH_USER-}"
CLI_SSH_PORT="${SSH_PORT-}"

# ===========
# Load configuration (config.env lives next to this script)
# ===========
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/config.env"
else
  echo "Missing config.env next to this script. (Tip: keep a config.env.sample for reference.)" >&2
  # Not fatal if you passed everything via env, so don't exit here.
fi

# ===========
# Defaults (only if still unset after config/env)
# ===========
: "${GITHUB_REPO:=https://github.com/jdruding/Batocera-Ultimarc-ServoStik-Conrol.git}"
: "${GIT_REF:=main}"
: "${BATOCERA_HOST:=batocera.local}"
: "${BATOCERA_SHARE:=share}"
# Use a user-writable default to avoid /Volumes permission friction
: "${MOUNT_POINT:=$HOME/BATOCERA}"
: "${SMB_USER:=}"
: "${SMB_PASS:=}"
: "${RSYNC_DELETE:=}"
: "${DRY_RUN:=}"
: "${DO_CHMOD_SSH:=}"
: "${SSH_USER:=root}"
: "${SSH_PORT:=22}"

# ===========
# Re-apply CLI / ENV overrides so they take precedence over config.env
# ===========
[[ -n "$CLI_GITHUB_REPO"    ]] && GITHUB_REPO="$CLI_GITHUB_REPO"
[[ -n "$CLI_GIT_REF"        ]] && GIT_REF="$CLI_GIT_REF"
[[ -n "$CLI_BATOCERA_HOST"  ]] && BATOCERA_HOST="$CLI_BATOCERA_HOST"
[[ -n "$CLI_BATOCERA_SHARE" ]] && BATOCERA_SHARE="$CLI_BATOCERA_SHARE"
[[ -n "$CLI_MOUNT_POINT"    ]] && MOUNT_POINT="$CLI_MOUNT_POINT"
[[ -n "$CLI_SMB_USER"       ]] && SMB_USER="$CLI_SMB_USER"
[[ -n "$CLI_SMB_PASS"       ]] && SMB_PASS="$CLI_SMB_PASS"
[[ -n "$CLI_RSYNC_DELETE"   ]] && RSYNC_DELETE="$CLI_RSYNC_DELETE"
[[ -n "$CLI_DRY_RUN"        ]] && DRY_RUN="$CLI_DRY_RUN"
[[ -n "$CLI_DO_CHMOD_SSH"   ]] && DO_CHMOD_SSH="$CLI_DO_CHMOD_SSH"
[[ -n "$CLI_SSH_USER"       ]] && SSH_USER="$CLI_SSH_USER"
[[ -n "$CLI_SSH_PORT"       ]] && SSH_PORT="$CLI_SSH_PORT"

# ===========
# Internal paths from repo → Batocera
# ===========
REPO_DIR="$SCRIPT_DIR/.repo"
GAME_START_REL="system/configs/emulationstation/scripts/game-start/restrictor-start.sh"
DEST_GAME_START="system/configs/emulationstation/scripts/game-start/restrictor-start.sh"

# ===========
# Helpers
# ===========
log()  { printf "\033[1;34m[deploy]\033[0m %s\n" "$*"; }  # blue
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }    # yellow
err()  { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; } # red

need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }
need git
need rsync
need mount_smbfs

# ===========
# Mount SMB share (robust but simple)
# ===========
ensure_mount() {
  # If already mounted at the configured point, reuse it
  if mount | grep -q "on $MOUNT_POINT "; then
    log "Share already mounted at $MOUNT_POINT"
    return 0
  fi

  # If mount dir exists, not a mount, and NOT empty → move aside once
  if [[ -d "$MOUNT_POINT" ]] && ! mount | grep -q "on $MOUNT_POINT "; then
    if [ -n "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
      warn "$MOUNT_POINT exists and is not empty; moving aside."
      mv "$MOUNT_POINT" "${MOUNT_POINT}.backup.$(date +%s)"
    fi
  fi

  # Create mount dir; if that fails (e.g., /Volumes permission), fall back to $HOME/BATOCERA
  if ! mkdir -p "$MOUNT_POINT" 2>/dev/null; then
    warn "Cannot create $MOUNT_POINT (permission denied). Falling back to \$HOME/BATOCERA."
    MOUNT_POINT="$HOME/BATOCERA"
    mkdir -p "$MOUNT_POINT"
  fi

  # If hostname doesn't resolve, gently try .local
  if ! smbutil lookup "$BATOCERA_HOST" >/dev/null 2>&1; then
    if smbutil lookup "${BATOCERA_HOST}.local" >/dev/null 2>&1; then
      warn "Host '$BATOCERA_HOST' not found; using '${BATOCERA_HOST}.local'."
      BATOCERA_HOST="${BATOCERA_HOST}.local"
    fi
  fi

  # Build SMB URL (guest if SMB_USER is blank)
  local user_spec
  if [[ -n "${SMB_USER}" ]]; then user_spec="${SMB_USER}"; else user_spec="guest"; fi
  local url="//${user_spec}@${BATOCERA_HOST}/${BATOCERA_SHARE}"

  log "Mounting SMB: $url → $MOUNT_POINT"
  if ! mount_smbfs "$url" "$MOUNT_POINT"; then
    err "Failed to mount SMB at $MOUNT_POINT. Verify host/share/credentials (BATOCERA_HOST=${BATOCERA_HOST}, BATOCERA_SHARE=${BATOCERA_SHARE})."
    exit 1
  fi
}

# ===========
# Clone or update the repo locally
# ===========
sync_repo() {
  log "Using local repo at $REPO_DIR"
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating repo in $REPO_DIR"
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout "$GIT_REF"
    git -C "$REPO_DIR" pull --ff-only origin "$GIT_REF" || true
  else
    log "Cloning $GITHUB_REPO → $REPO_DIR"
    git clone --depth 1 --branch "$GIT_REF" "$GITHUB_REPO" "$REPO_DIR"
  fi

  # Ensure the game-start script is executable locally so rsync can preserve it (-p)
  if [[ -f "$REPO_DIR/$GAME_START_REL" ]]; then
    chmod +x "$REPO_DIR/$GAME_START_REL" || true
  fi
}

# ===========
# What to deploy (source → destination relative to share root)
# ===========
deploy_map() {
  cat <<EOF
restrictor/    restrictor/
$GAME_START_REL    $DEST_GAME_START
EOF
}

# ===========
# Rsync files to the mounted share
# ===========
deploy() {
  local rsync_flags="-avp"                  # a=archive, v=verbose, p=preserve perms
  [[ -n "$DRY_RUN"       ]] && rsync_flags="$rsync_flags -n"
  [[ -n "$RSYNC_DELETE"  ]] && rsync_flags="$rsync_flags --delete"
  rsync_flags="$rsync_flags --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r"  # dirs 755, files 644

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

  # Extra safety: attempt chmod over SMB (sometimes ignored depending on server)
  if [[ -f "$MOUNT_POINT/$DEST_GAME_START" && -z "$DRY_RUN" ]]; then
    chmod +x "$MOUNT_POINT/$DEST_GAME_START" || \
      warn "chmod via SMB may be ignored; use DO_CHMOD_SSH=1 if needed."
  fi

  # Optional: enforce execute bit via SSH (set DO_CHMOD_SSH=1)
  if [[ -n "$DO_CHMOD_SSH" && -z "$DRY_RUN" ]]; then
    log "Ensuring execute bit via SSH on Batocera"
    ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$BATOCERA_HOST" \
      "chmod +x /userdata/$DEST_GAME_START; date +\"%F %T\" > /userdata/.last_batocera_servostik_deploy" \
      || warn "SSH chmod failed"
  elif [[ -z "$DRY_RUN" ]]; then
    # still drop a timestamp if we wrote via SMB
    date +"%Y-%m-%d %H:%M:%S" > "$MOUNT_POINT/.last_batocera_servostik_deploy" || true
  fi
}

# ===========
# Main flow
# ===========
main() {
  ensure_mount
  sync_repo
  deploy
  if [[ -n "$DRY_RUN" ]]; then
    warn "DRY_RUN enabled — no writes performed."
  else
    log "Deploy complete."
  fi
}

main "$@"
