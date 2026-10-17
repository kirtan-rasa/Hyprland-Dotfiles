# --- 1. Autostart ---
fastfetch

# --- 2. Powerlevel10k instant prompt ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- 3. PATH ---
export PATH="$HOME/.local/bin:$PATH"

# --- 4. Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# --- 5. Aliases ---
alias hyprconf='vim ~/.config/hypr/hyprland.conf'
alias sbtop='sudo -E btop --config ~/.config/btop/btop.conf'

# --- 6. P10k config ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
