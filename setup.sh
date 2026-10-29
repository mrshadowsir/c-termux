#!/usr/bin/env bash
# Purana command chalta rahega. Ab sab kuch install.sh mein hai (install + update + setup).
#   curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/setup.sh | bash
set -u
command -v curl >/dev/null 2>&1 || { command -v apt-get >/dev/null 2>&1 && apt-get install -y curl; }
curl -fsSL https://raw.githubusercontent.com/mrshadowsir/c-termux/main/install.sh | bash
