echo "[ 1/5 ] Installing yay..."
sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

echo "[ 2/5 ] Installing packages through yay..."
yay -S --needed bat delta eza lazygit fzf curl go go-sqlcmd git-delta fd neovim openssh postgresql ripgrep rsync starship tealdeer television tmux zoxide zsh

echo "[ 3/5 ] Installing project toolchains..."
yay -S --needed dotnet-sdk aspnet-runtime jdk21-openjdk cmake sqlc goose golangci-lint sqruff-bin

echo "       Installing Rust, sqlx..."
yay -S --needed rustup
rustup default stable
cargo install sqlx-cli --no-default-features --features rustls,postgres

echo "       Installing LaTeX (VimTeX) toolchain..."
# texlive-binextra provides latexmk; zathura-pdf-mupdf is the PDF backend
# (zathura ships with no format plugins on Arch).
yay -S --needed texlive-basic texlive-latexextra texlive-binextra zathura zathura-pdf-mupdf

echo "[ 4/5 ] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

echo "[ 5/5 ] Installing Node..."

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash

\. "$HOME/.nvm/nvm.sh"

nvm install 24

echo "All done!"
echo "       Node Version:"
node -v # Should print "v24.18.0".
echo "       NPM Version:"
npm -v # Should print "11.16.0".
