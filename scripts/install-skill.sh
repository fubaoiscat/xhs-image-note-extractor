#!/usr/bin/env bash
set -euo pipefail

REPO="${XHS_SKILL_REPO:-fubaoiscat/xhs-image-note-extractor}"
REF="${XHS_SKILL_REF:-latest}"
TARGET_DIR="${XHS_SKILL_TARGET:-$HOME/.claude/skills/xhs-image-note-extractor}"
SKIP_TESSERACT_INSTALL=0
SKIP_NODE_INSTALL=0

log() {
  printf '[xhs-installer] %s\n' "$1"
}

err() {
  printf '[xhs-installer] ERROR: %s\n' "$1" >&2
}

usage() {
  cat <<'EOF'
Usage:
  bash install-skill.sh [options]

Options:
  --repo <owner/repo>      GitHub repository (default: fubaoiscat/xhs-image-note-extractor)
  --ref <branch|tag|sha>   Git ref to download (default: latest release tag)
  --target <path>          Install path (default: ~/.claude/skills/xhs-image-note-extractor)
  --skip-node              Skip Node.js install step (default installer uses 22 LTS)
  --skip-tesseract         Skip tesseract install step
  -h, --help               Show this help

Env overrides:
  XHS_SKILL_REPO, XHS_SKILL_REF, XHS_SKILL_TARGET
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 1
  fi
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "Need root privilege for package installation. Install sudo or run as root."
    exit 1
  fi
}

install_tesseract_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is required on macOS. Install from https://brew.sh first."
    exit 1
  fi
  log "Installing tesseract on macOS via Homebrew..."
  brew install tesseract tesseract-lang
}

install_tesseract_linux() {
  log "Installing tesseract on Linux..."
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y tesseract tesseract-langpack-chi_sim tesseract-langpack-eng
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y tesseract tesseract-langpack-chi_sim tesseract-langpack-eng
    return
  fi
  if command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -Sy --noconfirm tesseract tesseract-data-chi_sim tesseract-data-eng
    return
  fi
  err "Unsupported Linux package manager. Install tesseract manually."
  exit 1
}

node_major() {
  node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true
}

install_node22_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is required on macOS. Install from https://brew.sh first."
    exit 1
  fi
  log "Installing Node.js 22 LTS on macOS via Homebrew..."
  brew install node@22

  # node@22 may be keg-only; prepend PATH for current session.
  prefix="$(brew --prefix node@22 2>/dev/null || true)"
  if [ -n "$prefix" ] && [ -x "$prefix/bin/node" ]; then
    export PATH="$prefix/bin:$PATH"
  fi
}

install_node22_linux() {
  log "Installing Node.js 22 LTS on Linux..."
  if command -v apt-get >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    elif command -v sudo >/dev/null 2>&1; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    else
      err "Need sudo/root to configure NodeSource for Node.js 22."
      exit 1
    fi
    run_as_root apt-get install -y nodejs
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    elif command -v sudo >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo -E bash -
    else
      err "Need sudo/root to configure NodeSource for Node.js 22."
      exit 1
    fi
    run_as_root dnf install -y nodejs
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    elif command -v sudo >/dev/null 2>&1; then
      curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo -E bash -
    else
      err "Need sudo/root to configure NodeSource for Node.js 22."
      exit 1
    fi
    run_as_root yum install -y nodejs
    return
  fi
  if command -v pacman >/dev/null 2>&1; then
    if run_as_root pacman -Sy --noconfirm nodejs-lts-jod; then
      return
    fi
    if run_as_root pacman -Sy --noconfirm nodejs-lts; then
      return
    fi
    run_as_root pacman -Sy --noconfirm nodejs
    return
  fi
  err "Unsupported Linux package manager for Node.js install."
  exit 1
}

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    major="$(node_major)"
    if [ -n "$major" ] && [ "$major" -ge 18 ]; then
      log "Node.js already installed: $(node --version)"
      return
    fi
  fi

  case "$(uname -s)" in
    Darwin)
      install_node22_macos
      ;;
    Linux)
      install_node22_linux
      ;;
    MINGW*|MSYS*|CYGWIN*)
      err "Windows detected. Please run scripts/install-skill.ps1 in PowerShell."
      exit 1
      ;;
    *)
      err "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  if ! command -v node >/dev/null 2>&1; then
    err "Node.js install completed but 'node' is not in PATH."
    exit 1
  fi
  major="$(node_major)"
  if [ -z "$major" ] || [ "$major" -lt 18 ]; then
    err "Node.js version is below 18: $(node --version 2>/dev/null || echo unknown)"
    exit 1
  fi
}

ensure_tesseract() {
  if command -v tesseract >/dev/null 2>&1; then
    log "tesseract already installed: $(tesseract --version | awk 'NR==1{print $2}')"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      install_tesseract_macos
      ;;
    Linux)
      install_tesseract_linux
      ;;
    MINGW*|MSYS*|CYGWIN*)
      err "Windows detected. Please run scripts/install-skill.ps1 in PowerShell."
      exit 1
      ;;
    *)
      err "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac
}

verify_tesseract_langs() {
  require_cmd tesseract
  langs="$(tesseract --list-langs 2>/dev/null || true)"
  missing=0
  if ! printf '%s\n' "$langs" | awk '$0=="chi_sim"{ok=1} END{exit(ok?0:1)}'; then
    err "Language data missing: chi_sim"
    missing=1
  fi
  if ! printf '%s\n' "$langs" | awk '$0=="eng"{ok=1} END{exit(ok?0:1)}'; then
    err "Language data missing: eng"
    missing=1
  fi
  if [ "$missing" -eq 1 ]; then
    err "tesseract is installed but required languages are missing."
    err "Please install language data and rerun."
    exit 1
  fi
}

resolve_ref() {
  if [ "$REF" != "latest" ]; then
    return
  fi

  require_cmd curl
  api_url="https://api.github.com/repos/${REPO}/releases/latest"
  log "Resolving latest release tag from ${REPO}..."
  latest_tag="$(
    curl -fsSL "$api_url" | awk -F'"' '/"tag_name":/ {print $4; exit}'
  )"

  if [ -z "${latest_tag:-}" ]; then
    err "Could not resolve latest release tag for ${REPO}."
    err "Please create a release or pass --ref <tag|branch|sha>."
    exit 1
  fi

  REF="$latest_tag"
  log "Using release tag: ${REF}"
}

download_skill() {
  require_cmd curl
  require_cmd tar
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  url_tags="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz"
  url_heads="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"
  url_commit="https://github.com/${REPO}/archive/${REF}.tar.gz"

  archive="$tmp_dir/skill.tar.gz"
  log "Downloading ${REPO}@${REF}..."
  if curl -fsSL "$url_tags" -o "$archive"; then
    :
  elif curl -fsSL "$url_heads" -o "$archive"; then
    :
  elif curl -fsSL "$url_commit" -o "$archive"; then
    :
  else
    err "Unable to download ref '${REF}' from ${REPO}"
    exit 1
  fi

  tar -xzf "$archive" -C "$tmp_dir"

  set -- "$tmp_dir"/*
  src_dir="$1"
  if [ ! -d "$src_dir" ]; then
    err "Archive extraction failed."
    exit 1
  fi

  mkdir -p "$(dirname "$TARGET_DIR")"
  rm -rf "$TARGET_DIR"
  cp -R "$src_dir" "$TARGET_DIR"
  log "Skill installed to: $TARGET_DIR"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --ref)
      REF="$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --skip-node)
      SKIP_NODE_INSTALL=1
      shift
      ;;
    --skip-tesseract)
      SKIP_TESSERACT_INSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

resolve_ref
download_skill

if [ "$SKIP_NODE_INSTALL" -eq 0 ]; then
  ensure_node
fi

if [ "$SKIP_TESSERACT_INSTALL" -eq 0 ]; then
  ensure_tesseract
  verify_tesseract_langs
fi

log "Done. Quick check:"
printf '  node "%s/scripts/parse-xhs-page.mjs" --help\n' "$TARGET_DIR"
printf '  node "%s/scripts/ocr-image.mjs" /path/to/image.jpg\n' "$TARGET_DIR"
