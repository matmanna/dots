# ⚙️ My Dotfiles

Everything I use to develop projects that could be considered either, _a) 🗑️ junk_ or _b) ✨ beautifully-crafted experiences valuing simplicity and openness,_ depending on your perspective.

This config mostly focuses on providing the tools I use to:

- Develop full-stack web applications (React, Svelte, Node) with tools such as Prettier and ESLint
- Develop mobile apps using flutter (config for this is still WIP)
- Develop this very config (with Lua)

## 📖 Table of Contents

- [Neovim Config](#-neovim) (Text Editor)
- [Wezterm Config](#-wezterm) (Terminal Emulator)
- [Demo](#-demo)

## Config Overview(s)

### ⌨️ Neovim

A fairly minimal kickstart.nvim configuration with added flair. A cozy 📦 Gruvbox theme with a 😺 snazzy tabby-based navigation bar, 💥 stylish noice notifications, 💽 streamlined Neogit VCS control, and a ⏲️ customized lualine with wakatime.

### 🌀 WezTerm

Focused on compatibility with the neovim theme, terminal emulation features a 🗓️ statusbar, ☀️ compatibility with device UI mode, 🌫️ transparent terminal, and 💾 support for persistent,🖥️  workspace-based multiplexing.

🪟 Additionally, as a convenience for windows users, Git Bash, Powershell, WSL, and CMD are all configured as shell options in the Wezterm Launch menu.

## 📸 Demo

![image](https://github.com/user-attachments/assets/297c3e10-f4e0-43c5-bab1-23afa6476d16)

## 🙌 Acknowledgements

- [@Wez](https://github.com/wez) (Wez Furlong) for his awesome terminal emulator/multiplexor!
- [@TJDevries](https://github.com/tjdevries) and the contributors of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) for the Neovim config starting point
- [@alexpls](https://github.com/alexpls) (Alex Plescan) for his WezTerm configuration guide blog [post](https://alexplescan.com/posts/2024/08/10/wezterm/#configuring-appearance)
- [@oscariquelme01](https://github.com/oscariquelme01) (Oscar Riquelme Jato) for Wezterm workspace saving/persistence

## Tasks

- [ ] fix keymaps and keymap hint UI (nvim)
  - [ ] command autocomplete
- [x] add copilot.nvim/avante
- [ ] harpoon.nvim
- [ ] toggleterm (nvim)
- [ ] auto-size workspaces (wezterm)
  - [ ] also auto-cd alternative workspace panes
- [ ] demo video
- [ ] inspect TS types better
- [ ] python dev
- [x] git bash, msys64, windows cmd, powershell
- [ ] svelte dev
