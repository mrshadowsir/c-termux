#!/usr/bin/env bash
# c-termux installer: Termux (mobile) aur Linux/WSL/macOS (computer) dono par.
#   git clone ... && cd c-termux && bash install.sh      (dobara chalana safe hai)
set -u
R="$(cd "$(dirname "$0")" && pwd)"; H="$HOME"; S="$H/.c-state"; SET="$H/.claude/settings.json"
if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; then PLAT=termux
elif [ "$(uname -s)" = Darwin ]; then PLAT=mac
else PLAT=linux; fi
if [ "$PLAT" = termux ]; then BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"; else BIN="$H/.local/bin"; mkdir -p "$BIN"; fi
export PATH="$BIN:$PATH"
[ "$PLAT" != termux ] && export NPM_CONFIG_PREFIX="$H/.local"
BASHP="$(command -v bash)"
echo "== Platform: $PLAT  (bin: $BIN) =="

echo "== 1. Packages =="
need=""; for t in curl jq tmux node npm pgrep md5sum git; do command -v $t >/dev/null 2>&1 || need="$need $t"; done
if [ -n "$need" ]; then
  echo "missing:$need -> install ho raha hai"
  SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo
  case $PLAT in
    termux) pkg install -y curl jq tmux nodejs procps coreutils git </dev/null >/dev/null 2>&1;;
    mac)    brew install curl jq tmux node coreutils git >/dev/null 2>&1;;
    linux)
      if   command -v apt-get >/dev/null; then $SUDO apt-get update -qq >/dev/null 2>&1; $SUDO apt-get install -y curl jq tmux nodejs npm procps coreutils git xdg-utils >/dev/null 2>&1
      elif command -v dnf >/dev/null;     then $SUDO dnf install -y curl jq tmux nodejs npm procps-ng coreutils git xdg-utils >/dev/null 2>&1
      elif command -v pacman >/dev/null;  then $SUDO pacman -Sy --noconfirm curl jq tmux nodejs npm procps-ng coreutils git xdg-utils >/dev/null 2>&1
      elif command -v zypper >/dev/null;  then $SUDO zypper -n install curl jq tmux nodejs npm procps coreutils git xdg-utils >/dev/null 2>&1
      elif command -v apk >/dev/null;     then $SUDO apk add curl jq tmux nodejs npm procps coreutils git xdg-utils bash >/dev/null 2>&1
      fi;;
  esac
fi
for t in curl jq tmux node npm pgrep md5sum git; do command -v $t >/dev/null 2>&1 || { echo "ABORT: '$t' install nahi hua. Haath se install karo, phir bash install.sh"; exit 1; }; done
NV=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
[ "${NV:-0}" -ge 18 ] || { echo "ABORT: Node 18+ chahiye (abhi: $(node -v)). https://nodejs.org se naya Node lo."; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "Claude Code install ho raha hai..."; npm i -g @anthropic-ai/claude-code >/dev/null 2>&1 || echo "WARN: claude install fail (npm i -g @anthropic-ai/claude-code khud chalao)"; }
command -v omniroute >/dev/null 2>&1 || { echo "OmniRoute install ho raha hai..."; npm i -g omniroute >/dev/null 2>&1 || echo "WARN: omniroute global install fail (c npx se chalayega)"; }

echo "== 2. Scripts =="
mkdir -p "$S/clients" "$S/m"; chmod 700 "$S"
pkill -f c-tester.sh 2>/dev/null; pkill -f "$S/router.js" 2>/dev/null; pkill -f c-health.sh 2>/dev/null; pkill -f "$S/office.js" 2>/dev/null
inst(){ # src dst mode : shebang + PATH + $PREFIX/bin is platform ke hisab se
  { echo "#!$BASHP"; echo "export PATH=\"$BIN:\$PATH\""; tail -n +2 "$1" | sed "s|\$PREFIX/bin|$BIN|g"; } > "$2.tmp" && chmod "$3" "$2.tmp" && mv "$2.tmp" "$2"; }
for f in "$R"/bin/*; do inst "$f" "$BIN/$(basename "$f")" 755; done
install -m 644 "$R/lib/router.js" "$S/router.js"
install -m 644 "$R/lib/office.js" "$S/office.js"
install -m 644 "$R/lib/office.html" "$S/office.html"
inst "$R/lib/view.sh" "$S/view.sh" 755
for f in c c-boot c-stop c-leave c-panel c-open c-health.sh c-tester.sh; do bash -n "$BIN/$f" || { echo "SYNTAX ERR $f"; exit 1; }; done
node --check "$S/router.js" && node --check "$S/office.js" || exit 1
echo "scripts OK"

echo "== 3. Claude settings (token repo mein nahi hai) =="
mkdir -p "$H/.claude"
if [ -f "$SET" ] && jq -e '.env.ANTHROPIC_AUTH_TOKEN|length>0' "$SET" >/dev/null 2>&1; then
  echo "existing settings.json + token preserve kiya"
else
  [ -f "$SET" ] && cp -a "$SET" "$SET.bak-$(date +%s)"
  TOK="${C_TOKEN:-}"
  if [ -z "$TOK" ] && [ -t 0 ]; then printf 'OmniRoute API key (dashboard se; khali = bina key): '; read -rs TOK; echo; fi
  base='{}'; [ -f "$SET" ] && base=$(cat "$SET")
  printf '%s' "$base" | jq --arg t "$TOK" '.env=((.env//{})+{ANTHROPIC_BASE_URL:"http://localhost:20128",ANTHROPIC_AUTH_TOKEN:$t,CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:"1"})' > "$SET.new" && mv "$SET.new" "$SET"
  chmod 600 "$SET"; echo "settings.json bana diya"
  [ -z "$TOK" ] && echo "NOTE: API key khali hai. OmniRoute dashboard se key lo, phir: C_TOKEN=<key> bash install.sh  (ya settings.json mein ANTHROPIC_AUTH_TOKEN daalo)"
fi

echo "== 4. Autostart =="
RC="$H/.bashrc"; [ "$PLAT" = mac ] && RC="$H/.zshrc"
if [ "$PLAT" = termux ]; then
  cp -a "$H/.bashrc" "$H/.bashrc.bak-$(date +%s)" 2>/dev/null
  sed -i '/# c-autostart/,/^fi$/d' "$H/.bashrc" 2>/dev/null
  sed -i '/# c-launcher-shadow/,+1d' "$H/.bashrc" 2>/dev/null
  cat >> "$H/.bashrc" <<EOF

# c-autostart
if [[ \$- == *i* ]] && [ -z "\${TMUX:-}" ] && [ -x "$BIN/c-boot" ]; then
  unalias c 2>/dev/null; unset -f c 2>/dev/null
  c-boot \$\$ >/dev/null 2>&1
  trap 'c-leave \$\$ >/dev/null 2>&1' EXIT
  trap 'exit' HUP TERM
  c-panel
fi
EOF
  echo "Termux hook OK (Termux khulte hi services start, band hote hi kill)"
else
  grep -qs '# c-path' "$RC" || printf '\n# c-path\nexport PATH="%s:$PATH"\n' "$BIN" >> "$RC"
  echo "computer par autostart nahi: sirf 'c' chalane par sab start hota hai, band karne par sab band."
fi

echo "== 5. ECC plugin (agents) =="
if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then echo "ECC enabled"
elif command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add https://github.com/affaan-m/ECC >/dev/null 2>&1
  claude plugin install ecc@ecc >/dev/null 2>&1
  if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then echo "ECC install ho gaya"
  else echo "ECC auto-install nahi hua. 'c' kholo aur Claude Code mein ye 2 command chalao:"
       echo "   /plugin marketplace add https://github.com/affaan-m/ECC"; echo "   /plugin install ecc@ecc"; fi
fi

echo
if [ "$PLAT" = termux ]; then NXT="Termux ko Exit karke dobara kholo"; else NXT="Naya terminal kholo (ya: source $RC)"; fi
echo "DONE ($PLAT). $NXT, phir sirf:  c"
echo "  c chalate hi browser mein khulega:"
echo "    3D Office        -> http://localhost:20130   (mobile/desktop auto; /m ya /d se force)"
echo "    OmniRoute Dashboard -> http://localhost:20128   (yahan providers/keys jodo)"
echo "  Browser band ho to: c-open     |  Status: c-panel     |  Sab band: c-stop"
