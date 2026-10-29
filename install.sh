#!/usr/bin/env bash
# c-termux: EK hi installer = install + update + setup + dashboards + API key + ECC + Claude start.
#
# Naye phone/PC par (sirf 1 command):
#   curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
# Repo se (dobara chalana safe hai, ye update bhi karta hai):
#   cd ~/c-termux && bash install.sh
#
# Options:  C_TOKEN=<key>     API key pehle se do (kuch poochhega nahi)
#           C_SKIP_UPDATE=1   update check skip
#           C_NOOPEN=1        browser mat kholo
#           C_NOSTART=1       end mein Claude start mat karo
# Poora log: ~/.c-state/install.log
set -u
REPO="${C_REPO:-https://github.com/mrshadowsir/c-termux.git}"
H="$HOME"
SRC="${BASH_SOURCE[0]:-$0}"
R="$(cd "$(dirname "$SRC")" 2>/dev/null && pwd)"

IS_TERMUX=0; { [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; } && IS_TERMUX=1
TTY=0; ( : </dev/tty ) 2>/dev/null && TTY=1

# ---------- 0. Bootstrap: 'curl | bash' se chalaya to pehle repo download ----------
if [ ! -f "$R/bin/c" ] || [ ! -f "$R/lib/router.js" ]; then
  printf '\n== c-termux download ==\n'
  if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    if [ "$IS_TERMUX" = 1 ]; then
      export DEBIAN_FRONTEND=noninteractive
      for i in 1 2 3; do apt-get update && break; echo "  dobara koshish ($i/3)..."; sleep 3; done
      apt-get -y -o Dpkg::Options::=--force-confnew install git curl
    else
      SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo
      if   command -v apt-get >/dev/null; then $SUDO apt-get update -qq; $SUDO apt-get install -y git curl
      elif command -v dnf >/dev/null;     then $SUDO dnf install -y git curl
      elif command -v pacman >/dev/null;  then $SUDO pacman -Sy --noconfirm git curl
      elif command -v zypper >/dev/null;  then $SUDO zypper -n install git curl
      elif command -v apk >/dev/null;     then $SUDO apk add git curl bash
      elif command -v brew >/dev/null;    then brew install git curl; fi
    fi
  fi
  command -v git >/dev/null 2>&1 || { echo "ABORT: git install nahi hua. Termux: 'termux-change-repo' chalao, phir ye command dobara chalao."; exit 1; }
  DIR="$H/c-termux"
  if [ -d "$DIR/.git" ]; then
    git -C "$DIR" pull --ff-only -q || { echo "  pull fail, naya download karta hoon"; mv "$DIR" "$DIR.bak-$(date +%s)"; git clone --depth 1 "$REPO" "$DIR" || exit 1; }
  else
    [ -e "$DIR" ] && mv "$DIR" "$DIR.bak-$(date +%s)"
    git clone --depth 1 "$REPO" "$DIR" || { echo "ABORT: download nahi hua. Net check karo."; exit 1; }
  fi
  export C_PULLED=1
  if [ "$TTY" = 1 ]; then exec bash "$DIR/install.sh" </dev/tty; else exec bash "$DIR/install.sh"; fi
fi

# ---------- Repo mein hain: naya version ho to khud pull karke dobara chalao ----------
if [ -d "$R/.git" ] && [ "${C_PULLED:-0}" != 1 ] && [ "${C_SKIP_UPDATE:-0}" != 1 ] && command -v git >/dev/null 2>&1; then
  _b="$(git -C "$R" rev-parse HEAD 2>/dev/null)"
  git -C "$R" pull --ff-only -q 2>/dev/null
  _a="$(git -C "$R" rev-parse HEAD 2>/dev/null)"
  if [ -n "$_b" ] && [ "$_b" != "$_a" ]; then
    echo "c-termux ka naya version mila, dobara chala raha hoon..."
    export C_PULLED=1; exec bash "$R/install.sh"
  fi
fi

T0=$SECONDS
S="$H/.c-state"; SET="$H/.claude/settings.json"
LOG="$S/install.log"; SUM="$S/summary.txt"
mkdir -p "$S" && chmod 700 "$S" 2>/dev/null; : > "$LOG"; : > "$SUM"

if [ "$IS_TERMUX" = 1 ]; then PLAT=termux
elif [ "$(uname -s)" = Darwin ]; then PLAT=mac
else PLAT=linux; fi
if [ "$PLAT" = termux ]; then BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"; else BIN="$H/.local/bin"; mkdir -p "$BIN"; fi
export PATH="$BIN:$PATH"
[ "$PLAT" != termux ] && export NPM_CONFIG_PREFIX="$H/.local"
BASHP="$(command -v bash)"
OMNI="http://localhost:20128"; OFFICE="http://localhost:20130"
TO30=""; TO180=""; TO20=""
command -v timeout >/dev/null 2>&1 && { TO30="timeout 30"; TO180="timeout 180"; TO20="timeout 20"; }

# ---------- status helpers ----------
if [ -t 1 ]; then G=$'\033[32m'; RD=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else G=; RD=; Y=; B=; D=; N=; fi
SP='|/-\'; FAILS=0; WARNS=0; STEPN=0; TOTAL=10; LASTT=0
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
retry() { # retry N "label" cmd args...
  local n="$1" label="$2" a=1; shift 2
  while [ "$a" -le "$n" ]; do
    run "$label" "$@" && return 0
    a=$((a+1)); [ "$a" -le "$n" ] && { printf '   %s↻%s dobara koshish (%d/%d) ...\n' "$Y" "$N" "$a" "$n"; sleep 3; }
  done; return 1
}
have_t() { # tool maujood hai? (Mac par md5sum = gmd5sum ya md5)
  case "$1" in
    md5sum) command -v md5sum >/dev/null 2>&1 || { [ "$PLAT" = mac ] && { command -v gmd5sum >/dev/null 2>&1 || command -v md5 >/dev/null 2>&1; }; };;
    *) command -v "$1" >/dev/null 2>&1;;
  esac
}
missing() { local t o=""; for t in curl jq tmux node npm pgrep md5sum git; do have_t "$t" || o="$o $t"; done; echo "${o# }"; }
ver_npm() { npm ls -g --depth=0 "$1" 2>/dev/null | grep -o "${1##*/}@[^ ]*" | head -1 | sed 's/.*@//'; }
wait_http() { # url secs : koi bhi HTTP jawab aaye to OK
  local u="$1" n="$2" i=0
  while [ "$i" -lt "$n" ]; do
    [ "$(curl -s -o /dev/null -m 2 -w '%{http_code}' "$u" 2>/dev/null)" != 000 ] && { [ -t 1 ] && printf '\r\033[K'; return 0; }
    i=$((i+1)); [ -t 1 ] && printf '\r\033[K   ruko ... %ss' "$i"; sleep 1
  done; [ -t 1 ] && printf '\r\033[K'; return 1
}
have_token() { [ -f "$SET" ] && jq -e '.env.ANTHROPIC_AUTH_TOKEN|length>0' "$SET" >/dev/null 2>&1; }
write_settings() { # $1 = token (khali bhi chalega)
  local base='{}'; mkdir -p "$H/.claude"
  [ -f "$SET" ] && base=$(cat "$SET")
  printf '%s' "$base" | jq --arg t "$1" '.env=((.env//{})+{ANTHROPIC_BASE_URL:"http://localhost:20128",ANTHROPIC_AUTH_TOKEN:$t,CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:"1"})' > "$SET.new" 2>>"$LOG" \
    && mv "$SET.new" "$SET" && chmod 600 "$SET"
}
restart_services() { c-stop >>"$LOG" 2>&1; c-boot $$ >>"$LOG" 2>&1; }

printf '%s== c-termux installer ==%s\n' "$B" "$N"
info "Har step ka status yahin dikhega. Kuch minute lag sakte hain, ruke rehna."

# ---------- 1. System check ----------
step "System check"
ok "Platform: $PLAT  (bin: $BIN)"
av=$(df -Pk "$H" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${av:-}" ] && [ "$av" -lt 600000 ] 2>/dev/null; then warn "Storage kam hai ($((av/1024)) MB khali). Kam se kam 600 MB rakho."
else ok "Storage theek hai"; fi
if [ "${C_NOCHECK:-0}" = 1 ] || ! command -v curl >/dev/null 2>&1; then info "internet check skip"
elif curl -fsS -m 10 -o /dev/null https://registry.npmjs.org/ 2>>"$LOG"; then ok "Internet OK"
else bad "Internet / npm registry tak nahi pahunch pa raha. Net check karo, phir: bash install.sh"; exit 1; fi

# ---------- 2. Packages: pehle check, update ho to update, na ho to install ----------
step "Packages (check, update, install)"
SUDO=""; [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1 && SUDO=sudo
if [ "$PLAT" = termux ]; then
  export DEBIAN_FRONTEND=noninteractive
  AO='-o Dpkg::Options::=--force-confnew'
  retry 3 "package list update" apt-get update && ok "package list update (${LASTT}s)" || warn "package list update fail (mirror dikkat? 'termux-change-repo' chalao)"
  up=$(apt-get -s full-upgrade 2>/dev/null | grep -c '^Inst' || true)
  if [ "${up:-0}" -gt 0 ] 2>/dev/null && [ "${C_SKIP_UPDATE:-0}" != 1 ]; then
    info "$up package ka update mila"
    retry 2 "Termux upgrade ($up packages)" apt-get -y $AO full-upgrade && ok "Termux upgrade ho gaya (${LASTT}s)" || warn "upgrade poora nahi hua, aage chalte hain"
  else ok "Termux ke packages latest hain"; fi
fi
need="$(missing)"
if [ -z "$need" ]; then ok "zaroori packages sab maujood hain"
else
  info "missing: $need -> install ho raha hai"
  [ -n "$SUDO" ] && [ "$PLAT" = linux ] && { info "sudo password maang sakta hai:"; sudo -v; }
  PM=""; PK=""
  case $PLAT in
    termux) retry 3 "packages install" apt-get -y $AO install curl jq tmux nodejs procps coreutils git && ok "packages install (${LASTT}s)" || warn "batch install fail, ek-ek karke try karta hoon";;
    mac)    retry 2 "brew install" brew install curl jq tmux node coreutils git && ok "brew install (${LASTT}s)" || warn "brew install fail";;
    linux)
      if   command -v apt-get >/dev/null; then retry 2 "apt update" $SUDO apt-get update -qq; PM="$SUDO apt-get install -y"; PK="curl jq tmux nodejs npm procps coreutils git xdg-utils"
      elif command -v dnf >/dev/null;     then PM="$SUDO dnf install -y";          PK="curl jq tmux nodejs npm procps-ng coreutils git xdg-utils"
      elif command -v pacman >/dev/null;  then PM="$SUDO pacman -Sy --noconfirm";  PK="curl jq tmux nodejs npm procps-ng coreutils git xdg-utils"
      elif command -v zypper >/dev/null;  then PM="$SUDO zypper -n install";       PK="curl jq tmux nodejs npm procps coreutils git xdg-utils"
      elif command -v apk >/dev/null;     then PM="$SUDO apk add";                 PK="curl jq tmux nodejs npm procps coreutils git xdg-utils bash"
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

# ---------- 3. Claude Code + OmniRoute: pehle version check ----------
step "Claude Code aur OmniRoute (check + update)"
npm_latest() { # pkg label cmd fatal(1/0)
  local pkg="$1" label="$2" cmd="$3" fatal="$4" have=0 act cur latest v
  command -v "$cmd" >/dev/null 2>&1 && have=1
  if [ "$have" = 1 ] && [ "${C_SKIP_UPDATE:-0}" = 1 ]; then ok "$label pehle se hai (update skip)"; return; fi
  cur="$(ver_npm "$pkg")"
  latest="$($TO30 npm view "$pkg" version 2>>"$LOG" | tail -1)"
  if [ "$have" = 1 ] && [ -n "$cur" ] && [ "$cur" = "$latest" ]; then ok "$label latest hai (v$cur)"; return; fi
  if [ "$have" = 1 ]; then act="update"; [ -n "$cur" ] && [ -n "$latest" ] && info "$label: v$cur -> v$latest"; else act="install"; fi
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
  { echo "#!$BASHP"; echo "export PATH=\"$BIN:\$PATH\""; tail -n +2 "$1" | sed "s|\$PREFIX/bin|$BIN|g"; } > "$2.tmp" && chmod "$3" "$2.tmp" && mv "$2.tmp" "$2"
}
for f in "$R"/bin/*; do inst "$f" "$BIN/$(basename "$f")" 755; done
install -m 644 "$R/lib/router.js" "$S/router.js"
install -m 644 "$R/lib/office.js" "$S/office.js"
install -m 644 "$R/lib/office.html" "$S/office.html"
inst "$R/lib/view.sh" "$S/view.sh" 755
for f in c c-boot c-stop c-leave c-panel c-open c-health.sh c-tester.sh; do bash -n "$BIN/$f" 2>>"$LOG" || { bad "SYNTAX ERR $f"; exit 1; }; done
node --check "$S/router.js" 2>>"$LOG" && node --check "$S/office.js" 2>>"$LOG" || { bad "JS syntax error"; exit 1; }
ok "8 commands + router + office install, syntax check pass"

# ---------- 5. Claude settings ----------
step "Claude settings (token repo mein nahi hota)"
if have_token; then
  ok "existing settings.json + token preserve kiya"
else
  [ -f "$SET" ] && cp -a "$SET" "$SET.bak-$(date +%s)"
  if write_settings "${C_TOKEN:-}"; then ok "settings.json ban gaya (chmod 600)"
  else bad "settings.json nahi bana"; showlog; rm -f "$SET.new"; fi
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

# ---------- 7. Services start + dono dashboard browser mein ----------
step "Services start aur dono dashboard browser mein"
if c-boot $$ >>"$LOG" 2>&1; then ok "services start command chali"; else warn "c-boot mein dikkat, log dekho"; fi
if wait_http "$OMNI/v1/models" 150; then ok "OmniRoute chal raha hai ($OMNI)"
else bad "OmniRoute start nahi hua (150 sec)"; [ -f "$S/omniroute.log" ] && tail -n 8 "$S/omniroute.log" | sed 's/^/   | /'; showlog; fi
if wait_http "$OFFICE/__ok" 30; then ok "3D Office chal raha hai ($OFFICE)"; else warn "3D Office abhi nahi chala. Baad mein: c-open"; fi
if [ -n "${C_NOOPEN:-}" ]; then info "C_NOOPEN set hai, browser nahi khola"
else
  c-open omni -f >>"$LOG" 2>&1; sleep 2; c-open office -f >>"$LOG" 2>&1
  ok "browser mein OmniRoute aur 3D Office khol diye"
  info "Agar browser na khule: link haath se kholo ->  $OMNI   aur   $OFFICE"
  [ "$PLAT" = termux ] && info "Phir bhi na khule: Android Settings > Apps > Termux > Display over other apps ON karo"
fi

# ---------- 8. API key: dashboard se banao, yahan paste karo ----------
step "API key (OmniRoute dashboard se)"
KEYNEW=0
if have_token && [ -z "${C_TOKEN:-}" ]; then
  ok "API key pehle se set hai"
else
  TOK="${C_TOKEN:-}"
  if [ -z "$TOK" ] && [ "$TTY" = 1 ]; then
    echo
    echo "   Ab browser mein OmniRoute Dashboard mein ye karo:"
    echo "     1) Provider jodo (jis model/service ko use karna hai)"
    echo "     2) API Keys mein nayi key banao aur copy karo"
    echo
    tries=0
    while [ "$tries" -lt 3 ]; do
      printf '   API key paste karo (kuch dikhega nahi; Enter = baad mein): '
      read -rs TOK </dev/tty; echo
      [ -z "$TOK" ] && break
      code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' -H "Authorization: Bearer $TOK" "$OMNI/v1/models" 2>/dev/null)
      case "$code" in
        200) break;;
        401|403) warn "key galat lag rahi hai (HTTP $code). Dobara paste karo"; TOK="";;
        *) warn "key check nahi ho payi (HTTP $code), aage badhte hain"; break;;
      esac
      tries=$((tries+1))
    done
  fi
  if [ -n "$TOK" ]; then
    if write_settings "$TOK"; then ok "API key save ho gayi (chmod 600)"; KEYNEW=1
    else bad "key save nahi hui"; rm -f "$SET.new"; fi
  else
    warn "API key khali hai. Dashboard se key lo, phir: bash ~/c-termux/install.sh"
  fi
fi
if [ "$KEYNEW" = 1 ]; then
  info "naye key ke saath services dobara start ho rahi hain..."
  restart_services
  wait_http "$OMNI/v1/models" 90 && ok "services naye key ke saath chal rahi hain" || warn "OmniRoute dobara start hone mein der lag rahi hai"
fi

# ---------- 9. ECC plugin ----------
step "ECC plugin (agents)"
if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then ok "ECC pehle se enabled"
elif command -v claude >/dev/null 2>&1; then
  run "ECC marketplace add" $TO180 claude plugin marketplace add https://github.com/affaan-m/ECC
  run "ECC install" $TO180 claude plugin install ecc@ecc
  if jq -e '.enabledPlugins["ecc@ecc"]==true' "$SET" >/dev/null 2>&1; then ok "ECC install ho gaya"
  else warn "ECC auto-install nahi hua. 'c' kholo aur Claude Code mein ye 2 command chalao:"
       info "/plugin marketplace add https://github.com/affaan-m/ECC"; info "/plugin install ecc@ecc"; fi
else warn "claude nahi mila, ECC skip (pehle Claude Code install karo, phir bash install.sh)"; fi

# ---------- 10. Final status ----------
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
HAVEKEY=0
if have_token; then HAVEKEY=1; ok "$(printf '%-12s %s' 'API key' 'set hai')"
else warn "$(printf '%-12s %s' 'API key' 'khali (baad mein daalo)')"; fi

# models PASS hue ya nahi (c-panel ka verdict)
PASS=0
if [ "$HAVEKEY" = 1 ] && [ "$FAILS" -eq 0 ]; then
  info "Models ka test chal raha hai, PASS dhoondh raha hoon (max 2 min)..."
  for i in $(seq 1 24); do
    $TO20 c-panel 2>/dev/null | sed $'s/\033\\[[0-9;]*[A-Za-z]//g' | grep -q 'VERDICT: ALL OK' && { PASS=1; break; }
    sleep 5
  done
  if [ "$PASS" = 1 ]; then ok "c-panel: ALL OK (models PASS)"
  else warn "c-panel abhi ALL OK nahi. Dashboard mein provider/key check karo, 2 min baad: c-panel"; fi
fi

echo
printf '%sTime: %ss   Log: %s%s\n' "$D" "$((SECONDS-T0))" "$LOG" "$N"
if [ "$FAILS" -eq 0 ]; then
  printf '%sVERDICT: INSTALL OK%s' "$G$B" "$N"; [ "$WARNS" -gt 0 ] && printf '  (%d warning, upar ! dekho)' "$WARNS"; echo
  echo
  echo "  3D Office           -> $OFFICE"
  echo "  OmniRoute Dashboard -> $OMNI   (providers/keys yahan)"
  echo "  Roz ka use: c   |   Browser dobara: c-open   |   Status: c-panel   |   Sab band: c-stop"
  echo
  GO=0
  if [ "${C_NOSTART:-0}" = 1 ] || [ "$TTY" = 0 ]; then GO=0
  elif [ "$HAVEKEY" = 0 ]; then echo "Claude start nahi hua: API key nahi hai. Key lekar dobara chalao: bash ~/c-termux/install.sh"
  elif [ "$PASS" = 1 ]; then GO=1
  else
    printf 'Models abhi PASS nahi hue. Phir bhi Claude start karu? [y/N]: '; read -r yn </dev/tty
    case "$yn" in y|Y|yes|YES) GO=1;; esac
  fi
  if [ "$GO" = 1 ]; then
    echo "Sab ready hai. Claude start ho raha hai..."; sleep 2
    exec env C_NOOPEN=1 c </dev/tty
  fi
  [ "$PLAT" = termux ] && echo "Claude chalane ke liye: sirf  c  likho (ya Termux Exit karke dobara kholo)." || echo "Claude chalane ke liye: naya terminal kholo (ya: source $RC), phir  c"
  exit 0
else
  printf '%sVERDICT: %d PROBLEM%s  (upar ✘ wali lines dekho)\n' "$RD$B" "$FAILS" "$N"
  echo "Dobara try: bash install.sh      Log: $LOG"
  exit 1
fi
