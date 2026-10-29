#!/data/data/com.termux/files/usr/bin/bash
S="$HOME/.c-state"; M="$S/m"; mkdir -p "$M"
ROOT="${1:?root}"; SET="$HOME/.claude/settings.json"; PIDF="$S/tester.pid"; MAIN=$$
if [ -z "${ONCE:-}" ]; then
  if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null && [ "$(cat "$PIDF")" != "$$" ]; then exit 0; fi
  echo $$ > "$PIDF"
fi
cleanup(){ [ "$BASHPID" = "$MAIN" ] || return 0; kill $(jobs -p) 2>/dev/null; [ -z "${ONCE:-}" ] && rm -f "$PIDF"; return 0; }
trap cleanup EXIT; trap 'exit 0' TERM INT HUP
umask 077
KEY=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN // .env.ANTHROPIC_API_KEY // empty' "$SET" 2>/dev/null)
HF="$S/hdr"; : > "$HF"
[ -n "$KEY" ] && printf 'x-api-key: %s\nAuthorization: Bearer %s\n' "$KEY" "$KEY" > "$HF"
PREF=$(jq -r '.env.ANTHROPIC_MODEL // .model // empty' "$SET" 2>/dev/null)
CODE=""; BODY=""; REASON=""; LAT=0
req(){ local o; o=$(curl -s -m "$1" -H @"$HF" -H 'content-type: application/json' -H 'anthropic-version: 2023-06-01' -w '\n%{http_code}' "$ROOT/v1/messages" -d "$2" 2>/dev/null); CODE=${o##*$'\n'}; BODY=${o%$'\n'*}; }
snip(){ printf '%s' "$BODY" | tr -d '\t\n\r' | cut -c1-80; }
probe(){
  local m="$1" b t0
  t0=$(date +%s%3N)
  b=$(jq -nc --arg m "$m" '{model:$m,max_tokens:1024,messages:[{role:"user",content:"Reply with the single word: ok"}]}')
  req 60 "$b"
  printf '%s' "$BODY" | jq -e '[.content[]?|select(.type=="text")|.text]|join("")|length>0' >/dev/null 2>&1 || { REASON="text http$CODE $(snip)"; return 1; }
  LAT=$(( $(date +%s%3N) - t0 ))
  b=$(jq -nc --arg m "$m" '{model:$m,max_tokens:1024,tools:[{name:"get_time",description:"Returns the current time",input_schema:{type:"object",properties:{}}}],tool_choice:{type:"any"},messages:[{role:"user",content:"Call the get_time tool now."}]}')
  req 60 "$b"
  printf '%s' "$BODY" | jq -e '[.content[]?|select(.type=="tool_use")]|length>0' >/dev/null 2>&1 || { REASON="tool http$CODE $(snip)"; return 1; }
  return 0
}
write_status(){
  local all="$S/all.$BASHPID" p f t
  cat "$M"/*.r > "$all" 2>/dev/null
  p=$(grep -c '^PASS' "$all"); f=$(grep -c '^FAIL' "$all")
  awk -F'\t' '$1=="PASS"{print $4"\t"$3}' "$all" | sort -n | cut -f2 > "$all.w"; mv "$all.w" "$S/working.txt"
  awk -F'\t' '$1=="FAIL"{print $3"  <- "$5}' "$all" | sort > "$all.f"; mv "$all.f" "$S/fails.txt"
  t=$(grep -c . "$S/models.txt" 2>/dev/null)
  echo "tested $((p+f))/${t:-0} | PASS $p | FAIL $f" > "$all.s"; mv "$all.s" "$S/status"; rm -f "$all"
}
due(){
  local f="$M/$1.r" st ts age
  [ -f "$f" ] || return 0
  IFS=$'\t' read -r st ts _ < "$f"; age=$(( $(date +%s) - ${ts:-0} ))
  if [ "$st" = PASS ]; then [ "$age" -ge 900 ]; else [ "$age" -ge 120 ]; fi
}
test_one(){
  local m="$1" h st
  h=$(printf %s "$m" | md5sum | cut -c1-16); REASON=""; LAT=0
  if probe "$m"; then st=PASS; REASON=ok; else st=FAIL; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$st" "$(date +%s)" "$m" "$LAT" "$(printf '%s' "$REASON" | tr -d '\t\n')" > "$M/$h.$BASHPID.tmp" && mv "$M/$h.$BASHPID.tmp" "$M/$h.r"
  write_status
}
while :; do
  list=$(curl -s -m 25 -H @"$HF" "$ROOT/v1/models" | jq -r '.data[]?.id' 2>/dev/null | sort -u \
    | grep -viE '(embed|whisper|tts|speech|transcri|rerank|moderation|dall-?e|image|imagen|flux|stable-diffusion|sdxl|video|veo|sora|audio|ocr|guard)')
  if [ -z "$list" ]; then echo "OmniRoute load ho raha hai / no models" > "$S/status"; [ -n "${ONCE:-}" ] && break; sleep 10; continue; fi
  printf '%s\n' "$list" > "$S/models.txt"
  { printf '%s\n' "$PREF"; cat "$M"/*.r 2>/dev/null | awk -F'\t' '$1=="PASS"{print $3}'; cat "$S/models.txt"; } | awk 'NF && !s[$0]++' | grep -Fxf "$S/models.txt" > "$S/order.txt"
  for f in "$M"/*.r; do [ -f "$f" ] || continue; mm=$(cut -f3 "$f"); grep -qxF -- "$mm" "$S/models.txt" || rm -f "$f"; done
  write_status
  while IFS= read -r m; do
    h=$(printf %s "$m" | md5sum | cut -c1-16)
    due "$h" || continue
    while [ "$(jobs -rp | wc -l)" -ge 6 ]; do sleep 0.3; done
    test_one "$m" &
  done < <(head -n "${LIMIT:-100000}" "$S/order.txt")
  wait; write_status
  [ -n "${ONCE:-}" ] && break
  sleep 20
done
