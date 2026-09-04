# dotfiles

- [nvim](nvim) - neovim config (submodule)
- [herdr](herdr/config.toml) - terminal multiplexer (replaced tmux)
- [ghostty](ghostty/config.ghostty) - terminal emulator
- [starship](starship.toml) - shell prompt
- [waybar](waybar/) - status bar
- [fuzzel](fuzzel/fuzzel.ini) - app launcher + dmenu for every picker (replaced wofi)
- [lazygit](lazygit/config.yml) - git TUI
- [paso](paso/config.yaml) - task manager
- [wallpapers](wallpapers/) - wallpaper collection
- [hypridle](hypr/hypridle.conf) - idle daemon
- [hyprlock](hypr/hyprlock.conf) - lock screen
- [wlogout](wlogout/) - logout menu
- [btop](btop/btop.conf) - system monitor
- [zathura](zathura/zathurarc) - PDF viewer (VimTeX preview); needs `zathura-pdf-mupdf` backend + `texlive-basic texlive-latexextra texlive-binextra`
- [sync-remote](scripts/sync-remote.sh) - push this repo to geekom and pi (`-n` for a dry run)
- hyprcap 
- hyprpicker - color picker
- hyprshot - screenshot tool
- zoxide - smart cd
- swaync - notification daemon
- kanshi - monitor manager
- wtype - allows for some of the fancier keys

lazydocker:
``` bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

systemctl-tui:
``` bash
curl https://raw.githubusercontent.com/rgwood/systemctl-tui/master/install.sh | bash
```
