# c-termux

Ek command `c` = **Claude Code + OmniRoute + ECC agents + 3D Office dashboard**.

- Background mein har model test hota hai (text + tool-call). Sirf **PASS** models use hote hain.
- Model fail ya token khatam ho to router agle PASS model par switch karta hai; FAIL models auto-retest hote hain.
- `c` chalate hi browser mein 2 page khulte hain:
  - **3D Office** `http://localhost:20130` : sab ECC agents ek office mein. Kaun **WORKING / IDLE / REST / STANDBY** hai, kaun sa model use ho raha hai, kitni baar, kitni der pehle. Mobile aur computer ke liye alag layout (auto).
  - **OmniRoute Dashboard** `http://localhost:20128` : providers / API keys yahan jodo.

---

## Setup: Mobile (Termux) — 1 command

Termux **F-Droid** wali lo (Play Store wali purani hai). Phir ye ek command paste karo:

```bash
pkg install -y git && git clone https://github.com/mrshadowsir/c-termux.git && cd c-termux && bash install.sh
```

Steps:
1. Command chalao. Poochhe to **OmniRoute API key** daalo (dashboard se; baad mein bhi daal sakte ho).
2. Termux ko **Exit** karke dobara kholo (autostart hook lagta hai).
3. Likho: `c`
4. Browser khulega: 3D Office + OmniRoute Dashboard. Dashboard mein providers/keys jodo.

Browser auto-open ke liye (ek baar): Android Settings > Apps > Termux > **"Display over other apps"** ON.
Behtar: `pkg install termux-api` + Play Store/F-Droid se **Termux:API** app. Nahi ho to `am start` fallback chalta hai.

Mobile par Office page chhota layout (scene upar, agents ki list neeche, swipe tabs) dikhata hai.

## Setup: Computer (Linux / WSL / macOS) — 1 command

```bash
git clone https://github.com/mrshadowsir/c-termux.git && cd c-termux && bash install.sh
```

Steps:
1. Command chalao (git, node 18+, tmux, jq khud install karta hai; apt/dnf/pacman/zypper/apk ya brew). Poochhe to OmniRoute key daalo.
2. Naya terminal kholo (ya `source ~/.bashrc`).
3. Likho: `c`
4. Browser mein 3D Office + OmniRoute Dashboard khulenge.

Computer par autostart nahi hota: `c` chalao to sab start, `c` band karo to sab band.
Computer par Office page bada layout dikhata hai (bada 3D scene + side mein agents/models/events).
Force karna ho: `http://localhost:20130/m` (mobile layout) ya `/d` (desktop layout).

> Linux aur WSL par test hua hai. macOS par best-effort (GNU coreutils chahiye, `brew` se aata hai), pura test nahi hua.
> Windows par seedha nahi: **WSL** use karo.

---

## Roz ka use

| Command | Kaam |
|---|---|
| `c` | Sab start + Claude Code (Ctrl-b 0 = Claude, Ctrl-b 1 = live models) + browser pages |
| `c-open` | 3D Office + OmniRoute browser mein dobara kholo (`c-open office`, `c-open omni`) |
| `c-panel` | Status ek nazar mein (`c-panel -w` live). Last line: `VERDICT: ALL OK` = sab theek |
| `c-stop` | Sab process band |

Auto-open band karna ho: `export C_NOOPEN=1`

## 3D Office mein kya dikhta hai

- Har agent ki ek desk. **Hara + glow + typing** = abhi kaam kar raha (pichhle 20 sec mein call), **peela** = idle (5 min tak), **neela-dhundhla** = rest, **kala** = standby (abhi tak call nahi).
- `MAIN` = aapka main Claude Code session, `QUICK` = chhote/fast kaam.
- Neeche server racks = PASS models (LED hara = abhi use mein).
- Agent par tap/click = list mein uski detail. List mein filter tabs + search.
- Upar chips: OmniRoute / Router / Tester / Health / ECC ka OK ya !! status.

## Security

- Token / API key repo mein nahi hai. `install.sh` use `~/.claude/settings.json` mein likhta hai (`chmod 600`), ya `C_TOKEN=... bash install.sh`.
- Office server sirf `127.0.0.1` par sunta hai (network par khula nahi).
- OmniRoute dashboard mein API key **zaroor require** karo.

## Dikkat aaye to

| Problem | Hal |
|---|---|
| `c: command not found` | Termux: Exit karke dobara kholo. Computer: naya terminal / `source ~/.bashrc` |
| Browser nahi khula | `c-open` ya seedha `http://localhost:20130` kholo |
| `c-panel` mein `!!` | Kuch der ruko (models test ho rahe hain). Phir bhi ho to `c-stop` phir `c` |
| Agents 0 / ECC `!!` | `bash install.sh` dobara (ECC plugin auto-install karta hai). Nahi to Claude Code mein: `/plugin marketplace add https://github.com/affaan-m/ECC` phir `/plugin install ecc@ecc` |
| `omniroute global install fail` | Koi dikkat nahi, `c` automatically `npx` se chalata hai |
| Models sab FAIL | OmniRoute dashboard mein provider/key jodo, phir 2 min ruko (auto-retest) |
