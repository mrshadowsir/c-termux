#!/usr/bin/env bash
# c-termux ek-command setup (naye phone / PC par):
#   curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/setup.sh | bash
# API key pehle se dena ho:
#   curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/setup.sh | C_TOKEN=apni_key bash
set -u
REPO="${C_REPO:-https://github.com/mrshadowsir/c-termux.git}"
DIR="$HOME/c-termux"
say() { printf '\n== %s ==\n' "$*"; }

IS_TERMUX=0
{ [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; } && IS_TERMUX=1

say "1/3 Pehle git aur curl ready kar raha hoon"
if [ "$IS_TERMUX" = 1 ]; then
  export DEBIAN_FRONTEND=noninteractive
  AO='-o Dpkg::Options::=--force-confnew'
  for i in 1 2 3; do apt-get update && break; echo "  dobara koshish ($i/3)..."; sleep 3; done
  apt-get -y $AO full-upgrade || echo "  upgrade poora nahi hua, aage chalte hain"
  apt-get -y $AO install git curl || { echo "ABORT: git install nahi hua. 'termux-change-repo' chalao, phir ye command dobara chalao."; exit 1; }
else
  if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo
    if   command -v apt-get >/dev/null; then $SUDO apt-get update -qq; $SUDO apt-get install -y git curl
    elif command -v dnf >/dev/null;     then $SUDO dnf install -y git curl
    elif command -v pacman >/dev/null;  then $SUDO pacman -Sy --noconfirm git curl
    elif command -v zypper >/dev/null;  then $SUDO zypper -n install git curl
    elif command -v apk >/dev/null;     then $SUDO apk add git curl bash
    elif command -v brew >/dev/null;    then brew install git curl; fi
  fi
  command -v git >/dev/null 2>&1 || { echo "ABORT: git install karo, phir ye command dobara chalao."; exit 1; }
fi
echo "  git $(git --version | awk '{print $3}') ready"

say "2/3 c-termux download / update"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only || { echo "  pull fail, naya download karta hoon"; mv "$DIR" "$DIR.bak-$(date +%s)"; git clone --depth 1 "$REPO" "$DIR" || exit 1; }
else
  [ -e "$DIR" ] && mv "$DIR" "$DIR.bak-$(date +%s)"
  git clone --depth 1 "$REPO" "$DIR" || { echo "ABORT: download nahi hua. Net check karo."; exit 1; }
fi

say "3/3 Installer chala raha hoon"
cd "$DIR" || exit 1
# 'curl | bash' mein keyboard input pipe se band ho jata hai, isliye key poochhne ke liye tty wapas jodte hain
if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then bash install.sh </dev/tty; else bash install.sh; fi
