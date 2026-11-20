#!/usr/bin/env bash
set -euo pipefail

echo "==> [1/5] Atualizando listas de pacotes e instalando utilitários..."
sudo apt update
sudo apt install -y \
  sway swaybg swayidle swaylock waybar wofi dunst foot imv ranger \
  brightnessctl grim slurp wl-clipboard xwayland

echo "==> [2/5] Criando diretórios e copiando configurações padrão..."
mkdir -p ~/.config/sway ~/.config/waybar ~/.config/foot ~/.config/ranger

if [ ! -f ~/.config/sway/config ]; then
  if [ -f /etc/sway/config ]; then
    cp /etc/sway/config ~/.config/sway/config
  else
    echo "ERRO: Arquivo base /etc/sway/config não encontrado." >&2
    exit 1
  fi
fi

if ls /etc/xdg/waybar/* >/dev/null 2>&1; then
  cp -n /etc/xdg/waybar/* ~/.config/waybar/
fi

if [ -f /etc/xdg/foot/foot.ini ]; then
  cp -n /etc/xdg/foot/foot.ini ~/.config/foot/foot.ini
fi

ranger --copy-config=all || true

echo "==> [3/5] Ajustando configuração base do Sway (~/.config/sway/config)..."
SWAY_CFG="$HOME/.config/sway/config"
cp "$SWAY_CFG" "${SWAY_CFG}.bak.$(date +%Y%m%d_%H%M%S)"

# Define terminal foot e lançador wofi se existirem as linhas padrão
sed -i 's/^set \$term .*/set \$term foot/' "$SWAY_CFG"
sed -i 's/^set \$menu .*/set \$menu wofi --show drun/' "$SWAY_CFG"

# Garante que o bloco bar use waybar caso exista um bloco bar padrão simples
if grep -q "^bar {" "$SWAY_CFG" && ! grep -q "swaybar_command waybar" "$SWAY_CFG"; then
  python3 - "$SWAY_CFG" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
content = re.sub(
    r"(?ms)^bar\s*\{.*?\n\}",
    "bar {\n    swaybar_command waybar\n}",
    content,
    count=1
)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
fi

# Bloco personalizado adicionado apenas uma vez
MARKER="# === CONFIGURACAO PERSONALIZADA SWAY + RANGER ==="
if ! grep -q "$MARKER" "$SWAY_CFG"; then
  cat >> "$SWAY_CFG" <<'EOF'

# === CONFIGURACAO PERSONALIZADA SWAY + RANGER ===

# Teclado ABNT2 (mude para xkb_layout us / xkb_variant intl se usar teclado US)
input "type:keyboard" {
    xkb_layout br
    xkb_variant abnt2
}

# Notificações e bloqueio/suspensão por inatividade
exec dunst
exec swayidle -w \
     timeout 300 'swaylock -f -c 000000' \
     timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
     before-sleep 'swaylock -f -c 000000'

# Gerenciador de arquivos ranger no terminal foot
bindsym $mod+e exec $term -e ranger

# Captura de tela (Print = tela inteira / Shift+Print = região)
bindsym Print exec sh -c 'grim ~/"$(date +%Y-%m-%d_%H-%M-%S).png"'
bindsym Shift+Print exec sh -c 'grim -g "$(slurp)" ~/"$(date +%Y-%m-%d_%H-%M-%S).png"'

# Controle de brilho de tela
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
EOF
fi

echo "==> [4/5] Ajustando configuração inicial do ranger (~/.config/ranger/rc.conf)..."
RANGER_CFG="$HOME/.config/ranger/rc.conf"
if [ -f "$RANGER_CFG" ]; then
  sed -i 's/^set preview_images .*/set preview_images true/' "$RANGER_CFG"
fi

echo "==> [5/5] Validando sintaxe da configuração do Sway..."
sway -C -c "$SWAY_CFG"

echo ""
echo "Tudo pronto! Resumo do que foi feito:"
echo " - Pacotes instalados e configs copiadas para ~/.config/"
echo " - Backup do Sway criado em ~/.config/sway/config.bak.*"
echo " - Teclado no Sway configurado para br (abnt2)"
echo " - Atalho \$mod+e configurado para abrir o ranger no foot"
echo ""
echo "Dica: para ajustar também o teclado no TTY, rode: sudo dpkg-reconfigure keyboard-configuration"
echo "Para iniciar o Sway agora, digite: sway"
