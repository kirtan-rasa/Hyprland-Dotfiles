#!/usr/bin/env bash

DIR="$HOME/Pictures/wallpapers"

SELECTED=$(
  find "$DIR" -type f \
    \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) |
    sort |
    fzf \
      --delimiter='/' \
      --with-nth=-1 \
      --preview='
        kitty +kitten icat \
          --clear \
          --transfer-mode=memory \
          "{}"
      ' \
      --preview-window=right:60%
)

[ -z "$SELECTED" ] && exit

awww img "$SELECTED"
