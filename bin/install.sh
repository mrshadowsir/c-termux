#!/usr/bin/env bash
# c-termux installer: Termux (mobile) aur Linux/WSL/macOS (computer) dono par.
#   git clone ... && cd c-termux && bash install.sh      (dobara chalana safe hai)
#
# Har step ka live status dikhta hai. Poora log: ~/.c-state/install.log
# Optional:  C_TOKEN=<key> bash install.sh   (API key pehle se do)
#            C_SKIP_UPDATE=1 bash install.sh (claude/omniroute update skip)
set -u
T0=$SECONDS
R="$(cd "$(dirname "$0")" && pwd)"; H="$HOME"; S="$H/.c-state"; SET="$H/.claude/settings.json"
LOG="$S/install.log"; SUM="$S/summary.txt"
mkdir -p "$S" && chmod 700 "$S" 2>/dev/null; : > "$LOG"; : > "$SUM"

if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; then PLAT=termux
elif [ "$(uname -s)" = Darwin ]; then PLAT=mac
else PLAT=linux; fi
if [ "$PLAT" = termux ]; then BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"; else BIN="$H/.local/bin"; mkdir -p "$BIN"; fi
export PATH="$BIN:$PATH"
[ "$PLAT" != termux ] && export NPM_CONFIG_PREFIX="$H/.local"
BASHP="$(command -v bash)"

# ---------- status helpers ----------
if [ -t 1 ]; then G=$'\033[32m'; RD=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else G=; RD=; Y=; B=; D=; N=; fi
SP='|/-\'; FAILS=0; WARNS=0; STEPN=0; TOTAL=8; LASTT=0
ok()   { printf '   %s✔%s %s\n' "$G" "$N" "$*"; echo "OK   $*" >>"$SUM"; }
warn() { printf '   %s!%s %s\n' "$Y" "$N" "$*"; echo "WARN $*" >>"$SUM"; WARNS=$((WARNS+1)); }
bad()  { printf '   %s✘%s %s\n' "$RD" "$N" "$*"; echo "FAIL $*" >>"$SUM"; FAILS=$((FAILS+1)); }
info() { printf '   %s%s%s\n' "$D" "$*" "$N"; }
step() { STEPN=$((STEPN+1)); printf '\n%s[%d/%d] %s%s\n' "$B" "$STEPN" "$TOTAL" "$*" "$N"; echo "### STEP $STEPN: $*" >>"$LOG"; }
showlog() { printf '   %s--- log ke aakhri lines ---%s\n' "$D" "$N"; tail -n 10 "$LOG" | sed 's/^/   | /'; info "poora log: $LOG"; }

# run "label" cmd args... : command background mein, spinner + seconds, output log mein
run() {
  local label="$1" t0=$SECONDS pid rc i=0; shift
  echo "--- $label: $*" >>"$LOG"
  "$@" >>"$LOG" 2>&1 </dev/null & pid=$!
  if [ -t 1 ]; then
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r\033[K   %s %s ... %ss' "${SP:$((i%4)):1}" "$label" "$((SECONDS-t0))"; i=$((i+1)); sleep 0.25
    done; printf '\r\033[K'
  else info "$label ..."; fi
  wait "$pid"; rc=$?; LASTT=$((SECONDS-t0)); return $rc
}
# retry N "label" cmd args...
retry() {
  local n="$1" label="$2" a=1; shift 2
  while [ "$a" -le "$n" ]; do
    run "$label" "$@" && return 0
    a=$((a+1)); [ "$a" -le "$n" ] && { printf '   %s↻%s dobara koshish (%d/%d) ...\n' "$Y" "$N" "$a" "$n"; sleep 3; }
  done; return 1
}
missing() { local t o=""; for t in curl jq tmux node npm pgrep md5sum git; do command -v "$t" >/dev/null 2>&1 || o="$o $t"; done; echo "${o# }"; }
ver_npm() { npm ls -g --depth=0 "$1" 2>/dev/null | grep -o "${1##*/}@[^ ]*" | head -1 | sed 's/.*@//'; }

printf '%s== c-termux installer ==%s\n' "$B" "$N"
info "Har step ka status yahin dikhega. Kuch minute lag sakte hain, ruke rehna."

# ---------- API key pehle hi pooch lo (baaki sab automatic) ----------
TOK="${C_TOKEN:-}"
HAVEKEY=0; [ -f "$SET" ] && grep -q '"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"[^"]' "$SET" 2>/dev/null && HAVEKEY=1
if [ "$HAVEKEY" = 0 ] && [ -z "$TOK" ] && [ -t 0 ]; then
  printf '\nOmniRoute API key (dashboard se; khali = baad mein): '; read -rs TOK; echo
fi

# ---------- 1. System check ----------
step "System check"
ok "Platform: $PLAT  (bin: $BIN)"
av=$(df -Pk "$H" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${av:-}" ] && [ "$av" -lt 600000 ] 2>/dev/null; then warn "Storage kam hai ($((av/1024)) MB khali). Kam se kam 600 MB rakho."
else ok "Storage theek hai"; fi
if [ "${C_NOCHECK:-0}" = 1 ] || ! command -v curl >/dev/null 2>&1; then info "internet check skip"
elif curl -fsS -m 10 -o /dev/null https://registry.npmjs.org/ 2>>"$LOG"; then ok "Internet OK"
else bad "Internet / npm registry tak nahi pahunch pa raha. Net check karo, phir: bash install.sh"; exit 1; fi

# ---------- 2. Packages ----------
step "Zaroori packages (curl jq tmux node npm git)"
need="$(missing)"
if [ -z "$need" ]; then ok "sab pehle se install hain"
else
  info "missing: $need -> install ho raha hai"
  SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo
  [ -n "$SUDO" ] && [ "$PLAT" = linux ] && { info "sudo password maang sakta hai:"; sudo -v; }
  PM=""; PK=""
  case $PLAT in
    termux)
      export DEBIAN_FRONTEND=noninteractive
      AO='-o Dpkg::Options::=--force-confnew'
      retry 3 "package list update" apt-get update && ok "package list update (${LASTT}s)" || warn "package list update fail (mirror dikkat? 'termux-change-repo' chalao)"
      retry 2 "Termux upgrade (pehli baar thoda time lagta hai)" apt-get -y $AO full-upgrade && ok "Termux upgrade (${LASTT}s)" || warn "upgrade poora nahi hua, aage chalte hain"
      retry 3 "packages install" apt-get -y $AO install curl jq tmux nodejs procps coreutils git && ok "packages install (${LASTT}s)" || warn "batch install fail, ek-ek karke try karta hoon"
      ;;
    mac) retry 2 "brew install" brew install curl jq tmux node coreutils git && ok "brew install (${LASTT}s)" || warn "brew install fail";;
    linux)
      if   command -v apt-get >/dev/null; then retry 2 "apt update" $SUDO apt-get update -qq; PM="$SUDO apt-get install -y"; PK="curl jq tmux nodejs npm procps coreutils git xdg-utils"
      elif command -v dnf >/dev/null;     then PM="$SUDO dnf install -y";            PK="curl jq tmux nodejs npm procps-ng coreutils git xdg-utils"
      elif command -v pacman >/dev/null;  then PM="$SUDO pacman -Sy --noconfirm";    PK="curl jq tmux nodejs npm procps-ng coreutils git xdg-utils"
      elif command -v zypper >/dev/null;  then PM="$SUDO zypper -n install";         PK="curl jq tmux nodejs npm procps coreutils git xdg-utils"
      elif command -v apk >/dev/null;     then PM="$SUDO apk add";                   PK="curl jq tmux nodejs npm procps coreutils git xdg-utils bash"
      else warn "package manager nahi mila"; fi
      [ -n "$PM" ] && { retry 2 "packages install" $PM $PK && ok "packages install (${LASTT}s)" || warn "batch install fail, ek-ek karke try karta hoon"; }
      ;;
  esac
  need="$(missing)"
  if [ -n "$need" ]; then   # ek-ek karke
    for t in $need; do
      case $t in node|npm) p=nodejs;; pgrep) p=procps;; md5sum) p=coreutils;; *) p=$t;; esac
      case $PLAT in termux) run "$p install" apt-get -y install "$p";; mac) run "$p install" brew install "$p";; *) [ -n "$PM" ] && run "$p install" $PM "$p";; esac
    done
    need="$(missing)"
  fi
  if [ -n "$need" ]; then
    bad "install nahi hue: $need"; showlog
    [ "$PLAT" = termux ] && info "Fix: 'termux-change-repo' chalao, mirror badlo, phir 'bash install.sh'"
    exit 1
  fi
fi
NV=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
if [ "${NV:-0}" -ge 18 ] 2>/dev/null; then ok "node $(node -v) | npm $(npm -v 2>/dev/null) | jq $(jq --version 2>/dev/null) | tmux $(tmux -V 2>/dev/null | awk '{print $2}')"
else bad "Node 18+ chahiye (abhi: $(node -v 2>/dev/null)). https://nodejs.org se naya Node lo."; exit 1; fi

# ---------- 3. Claude Code + OmniRoute (latest) ----------
step "Claude Code aur OmniRoute (latest version)"
npm_latest() { # pkg label cmd fatal(1/0)
  local pkg="$1" label="$2" cmd="$3" fatal="$4" have=0 act v
  command -v "$cmd" >/dev/null 2>&1 && have=1
  if [ "$have" = 1 ] && [ "${C_SKIP_UPDATE:-0}" = 1 ]; then ok "$label pehle se hai (update skip)"; return; fi
  if [ "$have" = 1 ]; then act="update"; else act="install"; fi
  if retry 2 "$label $act (latest)" npm i -g "$pkg@latest" --no-fund --no-audit --loglevel=error; then
    hash -r 2>/dev/null; v="$(ver_npm "$pkg")"; ok "$label $act ho gaya${v:+ (v$v)} (${LASTT}s)"
  elif [ "$have" = 1 ]; then warn "$label update fail, purana version chalega"; showlog
  elif [ "$fatal" = 1 ]; then bad "$label install nahi hua. Haath se: npm i -g $pkg"; showlog
  else warn "$label global install fail. Koi dikkat nahi, 'c' npx se chalayega"; showlog; fi
}
npm_latest @anthropic-ai/claude-code "Claude Code" claude 1
npm_latest omniroute "OmniRoute" omniroute 0

# ---------- 4. Scripts ----------
step "Scripts install"
mkdir -p "$S/clients" "$S/m"; chmod 700 "$S"
pkill -f c-tester.sh 2>/dev/null; pkill -f "$S/router.js" 2>/dev/null; pkill -f c-health.sh 2>/dev/null; pkill -f "$S/office.js" 2>/dev/null
inst(){ # src dst mode : shebang + PATH + $PREFIX/bin is platform ke hisab se
  { echo "#!$BASHP"; echo "export PATH=\"$BIN:\$PATH\""; tail -n +2 "$1" | sed "s|\$PREFIX/bin|$BIN|g"; } > "$2.tmp" && chmod "$3" "$2.tmp" && mv "$2.tmp" "$2"; }
for f in "$R"/bin/*; do inst "$f" "$BIN/$(basename "$f")" 755; done
install -m 644 "$R/lib/router.js" "$S/router.js"
install -m 644 "$R/lib/office.js" "$S/office.js"
install -m 644 "$R/lib/office.html" "$S/office.html"
inst "$R/lib/view.sh" "$S/view.sh" 755
for f in c c-boot c-stop c-leave c-panel c-open c-health.sh c-tester.sh; do bash -n "$BIN/$f" 2>>"$LOG" || { bad "SYNTAX ERR $f"; exit 1; }; done
node --check "$S/router.js" 2>>"$LOG" && node --check "$S/office.js" 2>>"$LOG" || { bad "JS syntax error"; exit 1; }
ok "8 commands + router + office install, syntax check pass"

# ---------- 5. Claude settings ----------
step "Claude settings (token repo mein nahi hai)"
if [ -f "$SET" ] && jq -e '.env.ANTHROPIC_AUTH_TOKEN|length>0' "$SET" >/dev/null 2>&1; then
  ok "existing settings.json + token preserve kiya"
else
  mkdir -p "$H/.claude"
  [ -f "$SET" ] && cp -a "$SET" "$SET.bak-$(date +%s)"
  base='{}'; [ -f "$SET" ] && base=$(cat "$SET")
  if printf '%s' "$base" | jq --arg t "$TOK" '.env=((.env//{})+{ANTHROPIC_BASE_URL:"http://localhost:20128",ANTHROPIC_AUTH_TOKEN:$t,CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:"1"})' > "$SET.new" 2>>"$LOG"; then
    mv "$SET.new" "$SET"; chmod 600 "$SET"; ok "settings.json ban gaya (chmod 600)"
  else bad "settings.json nahi bana"; showlog; rm -f "$SET.new"; fi
  [ -z "$TOK" ] && warn "API key khali hai. Dashboard se key lo, phir: C_TOKEN=<key> bash install.sh"
fi

# ---------- 6. Autostart ----------
step "Autostart / PATH"
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
  ok "Termux hook lag gaya (Termux khulte hi services start, band hote hi kill)"
else
  grep -qs '# c-path' "$RC" || printf '\n# c-path\nexport PATH="%s:$PATH"\n' "$BIN" >> "$RC"
  ok "PATH set. Computer par autostart nahi: sirf 'c' chalane par sab start, band karne par sab band"
fi

# ---------- 7. ECC plugin ----------
step "ECC plugin (agents)"
TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 180"
if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then ok "ECC pehle se enabled"
elif command -v claude >/dev/null 2>&1; then
  run "ECC marketplace add" $TO claude plugin marketplace add https://github.com/affaan-m/ECC
  run "ECC install" $TO claude plugin install ecc@ecc
  if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then ok "ECC install ho gaya"
  else warn "ECC auto-install nahi hua. 'c' kholo aur Claude Code mein ye 2 command chalao:"
       info "/plugin marketplace add https://github.com/affaan-m/ECC"; info "/plugin install ecc@ecc"; fi
else warn "claude nahi mila, ECC skip (pehle Claude Code install karo, phir bash install.sh)"; fi

# ---------- 8. Final status ----------
step "Final status"
chk() { # label  version-command  [required 1/0]
  local v; v="$(eval "$2" 2>/dev/null | head -1)"
  if [ -n "$v" ]; then ok "$(printf '%-12s %s' "$1" "$v")"
  elif [ "${3:-1}" = 1 ]; then bad "$(printf '%-12s NAHI MILA' "$1")"
  else warn "$(printf '%-12s nahi mila (npx se chalega)' "$1")"; fi
}
chk node    "node -v"
chk npm     "npm -v"
chk git     "git --version | awk '{print \$3}'"
chk jq      "jq --version"
chk tmux    "tmux -V | awk '{print \$2}'"
chk claude  "claude --version"
chk omniroute "command -v omniroute >/dev/null && echo v\$(npm ls -g --depth=0 omniroute 2>/dev/null | grep -o 'omniroute@[^ ]*' | head -1 | sed 's/.*@//')" 0
for f in c c-open c-panel c-stop; do [ -x "$BIN/$f" ] || bad "$f command nahi bana"; done
[ -x "$BIN/c" ] && ok "$(printf '%-12s %s' 'c command' 'taiyaar')"
if [ -f "$SET" ] && jq -e '.env.ANTHROPIC_AUTH_TOKEN|length>0' "$SET" >/dev/null 2>&1; then ok "$(printf '%-12s %s' 'API key' 'set hai')"
else warn "$(printf '%-12s %s' 'API key' 'khali (baad mein daalo)')"; fi

echo
printf '%sTime: %ss   Log: %s%s\n' "$D" "$((SECONDS-T0))" "$LOG" "$N"
if [ "$FAILS" -eq 0 ]; then
  if [ "$PLAT" = termux ]; then NXT="Termux ko Exit karke dobara kholo"; else NXT="Naya terminal kholo (ya: source $RC)"; fi
  printf '%sVERDICT: INSTALL OK%s' "$G$B" "$N"; [ "$WARNS" -gt 0 ] && printf '  (%d warning, upar ! dekho)' "$WARNS"; echo
  echo
  echo "DONE ($PLAT). $NXT, phir sirf:  c"
  echo "  c chalate hi browser mein khulega:"
  echo "    3D Office           -> http://localhost:20130   (mobile/desktop auto; /m ya /d se force)"
  echo "    OmniRoute Dashboard -> http://localhost:20128   (yahan providers/keys jodo)"
  echo "  Browser band ho to: c-open     |  Status: c-panel     |  Sab band: c-stop"
  exit 0
else
  printf '%sVERDICT: %d PROBLEM%s  (upar ✘ wali lines dekho)\n' "$RD$B" "$FAILS" "$N"
  echo "Dobara try: bash install.sh      Log: $LOG"
  exit 1
fi
