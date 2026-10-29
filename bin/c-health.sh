#!/data/data/com.termux/files/usr/bin/bash
H="$HOME"; S="$H/.c-state"; RP=20129; PIDF="$S/health.pid"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null && [ "$(cat "$PIDF")" != "$$" ]; then exit 0; fi
echo $$ > "$PIDF"; trap 'rm -f "$PIDF"' EXIT
killtree(){ local p; for p in $(pgrep -P "$1" 2>/dev/null); do killtree "$p"; done; kill "$1" 2>/dev/null; }
shutdown(){
  kill "${TPP:-0}" 2>/dev/null
  for n in tester router omni; do [ -f "$S/$n.pid" ] && killtree "$(cat "$S/$n.pid")"; rm -f "$S/$n.pid"; done
  pkill -f c-tester.sh 2>/dev/null; pkill -f "$S/router.js" 2>/dev/null; pkill -f "$S/office.js" 2>/dev/null
  pkill -f omniroute 2>/dev/null; sleep 1; pkill -9 -f omniroute 2>/dev/null
  rm -f "$S/active" "$S/tiers.txt" "$S/health.txt"; exit 0
}
agents_check(){
  local AD ok=0 bad=0 nn f fm n de
  AD=$(ls -d "$H/.claude/plugins/cache/ecc/ecc/"*/agents 2>/dev/null | sort -V | tail -1)
  [ -z "$AD" ] && AD=$(ls -d "$H/.claude/plugins/marketplaces/ecc/agents" 2>/dev/null | head -1)
  nn=$(mktemp)
  if [ -n "$AD" ]; then for f in "$AD"/*.md; do [ -f "$f" ] || continue
    fm=$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$f")
    n=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"'")
    de=$(printf '%s\n' "$fm" | grep -c '^description:')
    if [ -n "$n" ] && [ "$de" -gt 0 ]; then ok=$((ok+1)); echo "$n" >> "$nn"; else bad=$((bad+1)); fi
  done; fi
  agok=$ok; agbad=$bad; agdup=$(sort "$nn" | uniq -d | grep -c .); rm -f "$nn"
  plug=$(jq -r '.enabledPlugins["ecc@ecc"] // false' "$H/.claude/settings.json" 2>/dev/null)
}
tierprobe(){
  local t r m o=""
  for t in best mid fast; do
    r=$(curl -s -m 45 "http://127.0.0.1:$RP/v1/messages" -H 'content-type: application/json' -d "{\"model\":\"c-$t\",\"max_tokens\":32,\"messages\":[{\"role\":\"user\",\"content\":\"Say ok\"}]}")
    m=$(printf %s "$r" | jq -r 'select(.type=="message") | .model // empty' 2>/dev/null)
    if [ -n "$m" ]; then o="$o$t=OK($m) "; else o="$o$t=WAIT "; fi
  done
  echo "$o" > "$S/tiers.tmp" && mv "$S/tiers.tmp" "$S/tiers.txt"
}
agok=0; agbad=0; agdup=0; plug=false; ag_t=0; tp_t=0; TPP=0
while :; do
  a=0; for f in "$S/clients"/*; do [ -e "$f" ] || continue; if kill -0 "$(basename "$f")" 2>/dev/null; then a=1; else rm -f "$f"; fi; done
  [ "$a" = 0 ] && shutdown
  now=$(date +%s)
  [ $((now-ag_t)) -ge 600 ] && { agents_check; ag_t=$now; }
  iv=180; { [ ! -f "$S/tiers.txt" ] || grep -q WAIT "$S/tiers.txt"; } && iv=20
  if [ $((now-tp_t)) -ge $iv ] && ! kill -0 "$TPP" 2>/dev/null; then tierprobe & TPP=$!; tp_t=$now; fi
  printf 'agok=%s\nagbad=%s\nagdup=%s\nplug=%s\n' "$agok" "$agbad" "$agdup" "$plug" > "$S/health.tmp" && mv "$S/health.tmp" "$S/health.txt"
  sleep 5
done
