# c-termux

Ek command `c` = **Claude Code + OmniRoute + ECC agents + 3D Office dashboard**.

- Background mein har model test hota hai (text + tool-call). Sirf **PASS** models use hote hain.
- Model fail ya token khatam ho to router agle PASS model par switch karta hai. FAIL models auto-retest hote hain.
- `c` chalate hi browser mein 2 page khulte hain:
  - **3D Office** `http://localhost:20130` : sab agents ek office mein (WORKING / IDLE / REST / STANDBY).
  - **OmniRoute Dashboard** `http://localhost:20128` : yahan providers / API keys jodo.

> **Kaise padhein:** Har command ek **copy box** mein hai. Box ke kone mein **copy icon** dabao, phir Termux ya terminal mein **paste** karke Enter dabao. Sirf apne section ki commands chalao.

---

## Kaunsa section mujhe chahiye?

| Main kahan install kar raha hoon | Section |
|---|---|
| Android phone (Termux) | [A. Phone (Termux)](#a-phone-termux) |
| Windows PC | [B. Windows PC (WSL)](#b-windows-pc-wsl) |
| Linux PC / Ubuntu | [C. Linux PC](#c-linux-pc) |
| Mac | [D. Mac](#d-mac) |
| Install ho gaya, roz ka use | [E. Roz ka use](#e-roz-ka-use) |
| Kuch kaam nahi kar raha | [F. Dikkat aaye to](#f-dikkat-aaye-to) |

---

## A. Phone (Termux)

> Termux **F-Droid** wali lo. Play Store wali purani hai aur kaam nahi karti.

**Step 1: Termux kholo aur packages update karo** (sabse pehle, yahi step sabse zaroori hai)

```bash
pkg update -y
```

Agar beech mein `Y/I/N` poochhe to `Y` likh kar Enter dabao.

**Step 2: Zaroori packages install karo**

```bash
pkg install -y git jq tmux nodejs curl procps coreutils
```

**Step 3: Check karo ki sab install hue** (3 versions dikhne chahiye)

```bash
jq --version && tmux -V && node -v
```

**Step 4: Repo download karo aur installer chalao**

```bash
git clone https://github.com/mrshadowsir/c-termux.git
```

```bash
cd c-termux && bash install.sh
```

**Step 5: API key**

Jab `OmniRoute API key` poochhe, key paste karo. Abhi nahi hai to sirf Enter dabao, baad mein bhi daal sakte ho. Key likhte waqt kuch dikhta nahi, ye normal hai.

**Step 6: Termux ko Exit karke dobara kholo**

```bash
exit
```

**Step 7: Start karo**

```bash
c
```

Browser mein 3D Office aur OmniRoute Dashboard khulenge. Dashboard mein providers/keys jodo.

**Browser auto-open ke liye (ek baar):** Android Settings > Apps > Termux > **Display over other apps** ON karo.
Behtar: `pkg install termux-api` aur F-Droid se **Termux:API** app install karo.

---

## B. Windows PC (WSL)

> Windows par seedha nahi chalta. **WSL** (Ubuntu) chahiye.

**Step 1: PowerShell ko "Run as administrator" se kholo aur WSL install karo**

```powershell
wsl --install
```

**Step 2: PC restart karo**, phir Start menu se **Ubuntu** kholo (pehli baar apna naya username/password banana padega. Ye Ubuntu ka login hai, GitHub ka nahi).

**Step 3: Ubuntu mein packages update karo**

```bash
sudo apt update && sudo apt install -y git curl
```

**Step 4: Repo download karo aur installer chalao**

```bash
git clone https://github.com/mrshadowsir/c-termux.git
```

```bash
cd c-termux && bash install.sh
```

**Step 5: Ubuntu band karke dobara kholo, phir:**

```bash
c
```

---

## C. Linux PC

**Step 1: Repo download karo aur installer chalao** (git, node 18+, tmux, jq khud install hote hain)

```bash
git clone https://github.com/mrshadowsir/c-termux.git
```

```bash
cd c-termux && bash install.sh
```

**Step 2: Naya terminal kholo, phir:**

```bash
c
```

Computer par autostart nahi hota: `c` chalao to sab start, `c` band karo to sab band.

---

## D. Mac

> Pehle **Homebrew** (`brew`) install hona chahiye. Mac par best-effort support hai, pura test nahi hua.

**Step 1: Repo download karo aur installer chalao**

```bash
git clone https://github.com/mrshadowsir/c-termux.git
```

```bash
cd c-termux && bash install.sh
```

**Step 2: Naya terminal kholo, phir:**

```bash
c
```

---

## E. Roz ka use

| Kaam | Command |
|---|---|
| Sab start + Claude Code + browser | `c` |
| Browser pages dobara kholo | `c-open` |
| Status ek nazar mein | `c-panel` |
| Live status | `c-panel -w` |
| Sab band karo | `c-stop` |

Start karo:

```bash
c
```

Browser pages dobara kholo (`c-open office` ya `c-open omni` bhi chalta hai):

```bash
c-open
```

Status dekho. Last line `VERDICT: ALL OK` ho to sab theek hai:

```bash
c-panel
```

Sab band karo:

```bash
c-stop
```

Auto-open band karna ho:

```bash
export C_NOOPEN=1
```

**API key baad mein daalni ho:**

```bash
C_TOKEN=apni_key_yahan bash ~/c-termux/install.sh
```

**Naya version update karna ho:**

```bash
cd ~/c-termux && git pull && bash install.sh
```

---

## 3D Office mein kya dikhta hai

- Har agent ki ek desk. **Hara + glow + typing** = abhi kaam kar raha (pichhle 20 sec mein call), **peela** = idle (5 min tak), **neela-dhundhla** = rest, **kala** = standby (abhi tak call nahi).
- `MAIN` = aapka main Claude Code session, `QUICK` = chhote/fast kaam.
- Neeche server racks = PASS models (LED hara = abhi use mein).
- Agent par tap/click = list mein uski detail. List mein filter tabs + search.
- Upar chips: OmniRoute / Router / Tester / Health / ECC ka OK ya `!!` status.
- Layout force karna ho: `http://localhost:20130/m` (mobile) ya `/d` (desktop).

---

## Security

- Token / API key repo mein nahi hai. `install.sh` use `~/.claude/settings.json` mein likhta hai (`chmod 600`).
- Office server sirf `127.0.0.1` par sunta hai (network par khula nahi).
- OmniRoute dashboard mein API key **zaroor require** karo.
- Apni API key kisi ko share mat karo, na hi GitHub par daalo.

---

## F. Dikkat aaye to

### `jq` / `tmux` / `node` install nahi hua (ABORT message)

Packages ki list purani hai. Ye 3 commands ek ek karke chalao:

```bash
pkg update -y
```

```bash
pkg install -y git jq tmux nodejs curl procps coreutils
```

```bash
cd ~/c-termux && bash install.sh
```

Agar `Unable to locate package` ya mirror error aaye:

```bash
termux-change-repo
```

Arrow keys aur Space se koi ek mirror chuno, OK dabao, phir upar ki 3 commands dobara chalao.

### `git clone` ke time Username/Password poochhe

URL galat type hua hoga. Ctrl + C dabao, phir purana folder hatao aur URL **copy-paste** karo:

```bash
cd ~ && rm -rf c-termux
```

```bash
git clone https://github.com/mrshadowsir/c-termux.git
```

### `c: command not found`

Termux: Exit karke dobara kholo. Computer: naya terminal kholo, ya:

```bash
source ~/.bashrc
```

### Browser nahi khula

```bash
c-open
```

Ya seedha browser mein `http://localhost:20130` kholo.

### `c-panel` mein `!!` dikhe

Kuch der ruko (models test ho rahe hain). Phir bhi ho to:

```bash
c-stop
```

```bash
c
```

### Agents 0 ya ECC `!!`

Installer dobara chalao (ECC plugin auto-install karta hai):

```bash
cd ~/c-termux && bash install.sh
```

Nahi ho to Claude Code ke andar ye 2 commands chalao:

```
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin install ecc@ecc
```

### `omniroute global install fail`

Koi dikkat nahi, `c` automatically `npx` se chalata hai.

### Sab models FAIL

OmniRoute dashboard (`http://localhost:20128`) mein provider/key jodo, phir 2 min ruko (auto-retest hota hai).

### Phone mein "Permission denied" ya script nahi chali

```bash
chmod +x ~/c-termux/install.sh && bash ~/c-termux/install.sh
```
