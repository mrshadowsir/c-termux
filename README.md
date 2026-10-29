# c-termux

Ek command `c` = **Claude Code + OmniRoute + ECC agents**.

- Background mein har model test hota hai (text + tool-call). Sirf **PASS** models use hote hain.
- Model fail ya token khatam ho to router agle PASS model par switch karta hai. FAIL models auto-retest hote hain.
- **OmniRoute Dashboard** `http://localhost:20128`: yahan providers / API keys jodo.

> Har command ek **copy box** mein hai. Copy icon dabao, Termux/terminal mein **paste** karo, Enter dabao.

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

## Ek hi installer: kya kya khud hota hai

`install.sh` ek hi file hai. Naya install ho ya update, command wahi hai (dobara chalana safe hai):

1. **System check:** platform, storage, internet.
2. **Packages:** `git jq tmux nodejs curl` pehle check hote hain. Naya version ho to update, na ho to install.
3. **Claude Code + OmniRoute:** version compare hota hai. Latest ho to skip, purana ho to update.
4. **Scripts + settings** install.
5. **Services start** ho jati hain aur **browser mein OmniRoute dashboard khulta hai**.
6. **API key:** aap OmniRoute dashboard mein provider jodkar key banate ho. Installer key maangta hai, check karta hai (galat ho to dobara poochta hai), save karta hai aur services naye key ke saath restart karta hai.
7. **ECC** plugin apne aap install/setup.
8. **Final check:** `c-panel` mein models PASS dikhein to **Claude khud start ho jata hai**.

---

## A. Phone (Termux)

> Termux **F-Droid** wali lo. Play Store wali purani hai aur kaam nahi karti.

Termux kholo, ye ek command paste karo:

```
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
```

Phir:
1. Browser mein OmniRoute khulega. Wahan **provider jodo** aur **API key banao**.
2. Termux mein key paste karo (likhte waqt kuch dikhta nahi, ye normal hai).
3. Baaki sab khud hoga. Aakhir mein Claude start ho jayega.

Key pehle se command mein dena ho (phir kuch poochhega nahi):

```
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | C_TOKEN=apni_key_yahan bash
```

Purana command (`setup.sh` wala) bhi chalta hai, wo bhi yahi installer chalata hai.

**Browser na khule to (ek baar):** Android Settings > Apps > Termux > **Display over other apps** ON karo. Ya link haath se kholo: `http://localhost:20128`.

### Manual tareeka (agar upar wali command na chale)

```
pkg update -y && pkg install -y git curl
```
```
git clone https://github.com/mrshadowsir/c-termux.git
```
```
cd c-termux && bash install.sh
```

Script padhke chalana ho to chalane se pehle `cat install.sh` se dekh lo.

---

## B. Windows PC (WSL)

> Windows par seedha nahi chalta. **WSL** (Ubuntu) chahiye.

1. PowerShell ko "Run as administrator" se kholo:

```
wsl --install
```

2. PC restart karo, Start menu se **Ubuntu** kholo (pehli baar naya username/password banao, ye Ubuntu ka login hai, GitHub ka nahi).
3. Ubuntu mein:

```
sudo apt update && sudo apt install -y git curl
```
```
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
```

---

## C. Linux PC

```
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
```

Computer par autostart nahi hota: `c` chalao to sab start, `c` band karo to sab band.

---

## D. Mac

> Pehle **Homebrew** (`brew`) chahiye. Mac par best-effort support hai, pura test nahi hua.

```
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
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

`c-panel` ki last line `VERDICT: ALL OK` ho to sab theek hai.

**Update karna ho (packages + Claude Code + OmniRoute + c-termux):**

```
cd ~/c-termux && bash install.sh
```

Options (command ke aage lagao):

| Option | Kaam |
|---|---|
| `C_TOKEN=key` | API key pehle se do |
| `C_SKIP_UPDATE=1` | update check skip (tez) |
| `C_NOOPEN=1` | browser mat kholo |
| `C_NOSTART=1` | end mein Claude start mat karo |

Misal: `C_SKIP_UPDATE=1 bash ~/c-termux/install.sh`

---

## Security

- Token / API key repo mein nahi hai. `install.sh` use `~/.claude/settings.json` mein likhta hai (`chmod 600`).
- OmniRoute dashboard mein API key **zaroor require** karo.
- Apni API key kisi ko share mat karo, na hi GitHub par daalo.

---

## Phone mein `[Process completed (signal 9)]` aaye to

Android Termux ko background mein band kar deta hai. Ye script se nahi hat sakta, settings badalni padti hain:

1. Android Settings > Apps > Termux > Battery > **Allow background power usage** (Restrict nahi).
2. Termux ki notification mein **Acquire wakelock** dabao (script bhi koshish karta hai).
3. Android 12+: Developer options > **Disable child process restrictions** ON.

Tester ab halka chalta hai (ek saath 3 model, FAIL 20 min baad dobara test). Badalna ho: `C_PAR=2`, `C_FAIL_RETEST=3600`.

---

## F. Dikkat aaye to

Poora log: `~/.c-state/install.log`

**Packages install nahi hue (ABORT):**

```
termux-change-repo
```

Koi mirror chuno (arrow keys + Space, phir OK), phir `cd ~/c-termux && bash install.sh`.

**`c: command not found`:** Termux Exit karke dobara kholo, ya `source ~/.bashrc`.

**Browser nahi khula:** `c-open`, ya seedha `http://localhost:20128` kholo. Termux mein "Display over other apps" ON karo.

**API key galat bataya:** OmniRoute dashboard mein key dobara copy karo, phir `cd ~/c-termux && bash install.sh`.

**`claude native binary not installed`:** Termux par naya Claude Code nahi chalta. Installer apne aap `2.1.112` laga deta hai. Haath se: `npm i -g @anthropic-ai/claude-code@2.1.112`. Doosra version: `C_CLAUDE_VER=x.y.z bash ~/c-termux/install.sh`.

**Claude start nahi hua (models PASS nahi):** Dashboard (`http://localhost:20128`) mein provider/key jodo, 2 min ruko (auto-retest hota hai), phir `c-panel` dekho, phir `c`.

**`c-panel` mein `!!`:** Kuch der ruko. Phir bhi ho to `c-stop` aur `c`.

**Agents 0 ya ECC `!!`:** `cd ~/c-termux && bash install.sh`. Nahi ho to Claude Code ke andar:

```
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin install ecc@ecc
```

**`omniroute global install fail`:** Koi dikkat nahi, `c` automatically `npx` se chalata hai.

**Permission denied:** `chmod +x ~/c-termux/install.sh && bash ~/c-termux/install.sh`
