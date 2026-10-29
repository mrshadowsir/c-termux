#!/data/data/com.termux/files/usr/bin/bash
S="$HOME/.c-state"; M="$S/m"
G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; D=$'\e[2m'; B=$'\e[1m'; N=$'\e[0m'
bar(){ local v=${1:-0} t=${2:-0} w=${3:-10} f; [ "$t" -gt 0 ] || t=1; f=$((v*w/t)); [ "$f" -gt "$w" ] && f=$w
  printf '%*s' "$f" '' | tr ' ' '#'; printf '%*s' "$((w-f))" '' | tr ' ' '.'; }
render(){
  local W now nowms all tot p f nxt agok=0 agbad=0 agdup=0 plug=false
  W=$(tput cols 2>/dev/null); W=${W:-48}; [ "$W" -lt 30 ] && W=30
  now=$(date +%s); nowms=$(date +%s%3N)
  all=$(cat "$M"/*.r 2>/dev/null)
  tot=$(grep -c . "$S/models.txt" 2>/dev/null); tot=${tot:-0}
  p=$(printf '%s\n' "$all" | grep -c '^PASS'); f=$(printf '%s\n' "$all" | grep -c '^FAIL')
  nxt=$(printf '%s\n' "$all" | awk -F'\t' -v n="$now" '$1=="FAIL"{d=$2+120-n; if(m==""||d<m)m=d} END{print (m==""?0:(m<0?0:m))}')
  [ -f "$S/health.txt" ] && . "$S/health.txt"
  echo "${B}${C}c LIVE${N} $(date +%H:%M:%S)  ${D}Ctrl-b 0 = Claude${N}"
  echo "Tested $((p+f))/$tot [$(bar $((p+f)) $tot 14)]"
  echo "${G}PASS $p${N}  ${R}FAIL $f${N}  retest ${nxt}s  ECC $agok ok/$agbad bad"
  echo "${Y}NOW${N} $(cat "$S/active" 2>/dev/null || echo waiting)"
  echo "${B}-- PASS (T tier, ms, uses, err) --${N}"
  if [ -s "$S/stats.json" ]; then
    jq -r --argjson now "$nowms" '.models|to_entries|sort_by([-(.value.n//0),(.value.lat//9999)])|.[:12][]|[(if ($now-(.value.t//0))<30000 and (.value.t//0)>0 then "*" else "." end),(["","F","M","B"][.value.s//2]),.key,(.value.lat//0),(.value.n//0),(.value.e//0)]|@tsv' "$S/stats.json" 2>/dev/null \
    | awk -F'\t' -v nw=$((W-19)) -v g="$G" -v n="$N" '{fmt=sprintf("%%s%%s%%s %%s %%-%ds %%5d %%3d %%2d\n",nw); c=($1=="*")?g:""; printf fmt,c,$1,n,$2,substr($3,1,nw),$4,$5,$6}'
    [ "$p" -gt 12 ] && echo "${D}  +$((p-12)) aur PASS models${N}"
  else head -12 "$S/working.txt" 2>/dev/null; fi
  echo "${B}-- FAIL reasons --${N}"
  printf '%s\n' "$all" | awk -F'\t' '$1=="FAIL"{r=tolower($5); c="other";
    if(r~/not available|not found|unknown model|no provider|no credential|not supported|does not exist|no active|disabled/)c="not-available";
    else if(r~/rate.?limit|too many|quota|exhaust|credit|insufficient|billing|http ?429|http ?402/)c="limit/quota";
    else if(r~/http ?40[13]|api key|unauthor|forbidden/)c="auth";
    else if(r~/^tool/)c="no-tool-call";
    else if(r~/timeout|http000|econn|socket|reset|aborted/)c="timeout/net";
    else if(r~/http ?5|overload/)c="server-err";
    else if(r~/^runtime|stream/)c="runtime";
    else if(r~/http ?400/)c="bad-request"; n[c]++}
    END{for(c in n)print n[c]"\t"c}' | sort -rn | head -6 | while IFS=$'\t' read -r n c; do printf '%-13s %4s %s\n' "$c" "$n" "$(bar "$n" "$f" 10)"; done
  echo "${B}-- Agents -> model --${N}"
  jq -r --argjson now "$nowms" '.agents//{}|to_entries|sort_by(-(.value.t//0))|.[:6][]|[.key,.value.m,(.value.n//0),((($now-(.value.t//0))/1000)|floor)]|@tsv' "$S/stats.json" 2>/dev/null \
    | awk -F'\t' -v w="$W" '{printf "%-16s> %s (%sx %ss)\n", substr($1,1,15), substr($2,1,w-34), $3, $4}'
  echo "${B}-- Events --${N}"
  tail -5 "$S/router.log" 2>/dev/null | cut -c1-$((W-1)) | sed -e "s/ +PASS/ ${G}+PASS${N}/" -e "s/ -DROP/ ${R}-DROP${N}/" -e "s/ FAIL / ${R}FAIL${N} /"
}
while :; do out=$(render); printf '\e[H\e[J%s\n' "$out"; [ -n "${ONCE:-}" ] && break; sleep 3; done
