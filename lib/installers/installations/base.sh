################################################################################
# 0.  cd to repo root (adjust if your clone lives elsewhere)
################################################################################
cd /scratch/.github/sambitmishra98/terminal-helper

################################################################################
# 1.  Write the new base.sh (overwrite if it already exists)
################################################################################
mkdir -p lib/installers/installations
cat > lib/installers/installations/base.sh <<'EOF'
#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# base.sh  —  universal fetch helper for installation scripts
#
# Usage (exec):   base.sh <pkg> <version> <url> [install-prefix]
# Usage (source): set PKG=… VER=… URL=… [PREFIX=…]; source base.sh
#
# • Detects wget-able vs git-clone-able URLs
# • Validates arguments & paths; emits clear errors
# • Prints the final \$SRC_DIR (source tree) & \$PREFIX (install root)
# ---------------------------------------------------------------------------
set -euo pipefail

# ── 1. collect args / envs ──────────────────────────────────────────────────
PKG=${PKG:-${1-}}
VER=${VER:-${2-}}
URL=${URL:-${3-}}
PREFIX=${PREFIX:-${4:-$HOME/.local/installs/${PKG}-${VER}}}

# ── 2. sanity checks ────────────────────────────────────────────────────────
err() { printf "\e[31merror:\e[0m %s\n" "$*" >&2; exit 2; }
[[ -n $PKG   ]] || err "missing <pkg> name"
[[ -n $VER   ]] || err "missing <version>"
[[ -n $URL   ]] || err "missing <url>"
[[ $URL =~ ^(https?|git|ssh)://|git@|\.git$ ]] \
  || err "URL looks invalid: $URL"

[[ -d $(dirname "$PREFIX") ]] || mkdir -p "$(dirname "$PREFIX")"
SRC_DIR=/tmp/${PKG}-${VER}-src
rm -rf "$SRC_DIR" && mkdir -p "$SRC_DIR"

echo "→ package : $PKG"
echo "→ version : $VER"
echo "→ url     : $URL"
echo "→ prefix  : $PREFIX"
echo "→ src dir : $SRC_DIR"

# ── 3. fetch source tree ────────────────────────────────────────────────────
case "$URL" in
  *.git|git@*|*github.com*)
      echo "Cloning via git…"
      git clone --depth 1 "$URL" "$SRC_DIR" || err "git clone failed"
      ;;
  http*|https* )
      echo "Downloading via wget…"
      fname=${URL##*/}
      wget -q --show-progress -O "$SRC_DIR/$fname" "$URL" \
        || err "wget failed"
      ;;
  *)
      err "Cannot determine fetch method for $URL"
      ;;
esac

echo -e "\e[32m✓ fetch complete\e[0m"
export SRC_DIR PREFIX     # for downstream scripts
EOF
chmod +x lib/installers/installations/base.sh

################################################################################
# 2.  Quick self-tests (will NOT pollute the repo)
################################################################################
echo -e "\n--- TEST 1: missing args (should error) ----------------------------"
(! lib/installers/installations/base.sh 2>&1 ) | head -n2

echo -e "\n--- TEST 2: clone a tiny public git repo ---------------------------"
lib/installers/installations/base.sh ansi-colors-demo 0.1 https://github.com/clarketm/ansi-colors.git /tmp/ansi-test | head

################################################################################
# 3.  Commit & push
################################################################################
git add lib/installers/installations/base.sh
git commit -m "feat: add universal fetch helper (lib/installers/installations/base.sh)"
git push
