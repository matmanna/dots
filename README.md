# ⚙️ My Dotfiles

Everything I use to develop programming projects, manage my productivity, communicate effectively, and navigate my machine. Take what you want and ignore what you don't.

![dotfiles](https://github.com/user-attachments/assets/a3db50ba-8d0e-4c0f-a614-dc2175748698)

## 📖 Table of Contents

- [Setup Instructions]
- Config Overviews
  - [Neovim Config](#-neovim) (Text Editing)
  - [Wezterm Config](#-wezterm) (Terminal Emulation)
  - [Raycast Config] (Application Launching)
  - [Beeper Config] (Social/messaging management)
  - [Thunderbird] (Email client)
  - [Logseq Config] (Note-taking)
  - [LibreOffice] (Document/spreadsheet/slideshow editing)
- [Usage (Keyboard Shortcuts)]
- [Demos](#-demo)

## 👁️ Config Overview(s)

### 🧑‍💻 Development

#### ⌨️ Neovim

A fairly minimal kickstart.nvim configuration with added flair. A cozy 📦 Gruvbox theme with a 😺 snazzy tabby-based navigation bar, 💥 stylish noice notifications, 💽 streamlined Neogit VCS control, and a ⏲️ customized lualine with wakatime

Designed for developing:

- full-stack web applications (React, Svelte, Node) with tools such as Prettier and ESLint
- mobile apps using flutter (config for this is still WIP)
- this very config (with Lua)

#### 🌀 WezTerm

Focused on compatibility with the neovim theme, terminal emulation features a 🗓️ statusbar, ☀️ compatibility with device UI mode, 🌫️ transparent terminal, and 💾 support for persistent,🖥️ workspace-based multiplexing.

🪟 Additionally, as a convenience for windows users, Git Bash, Powershell, WSL, and CMD are all configured as shell options in the Wezterm Launch menu.

### 🚀 Productivity

#### 🎯 Zen

#### 🪵 Logseq

#### ⌨️ Raycast

#### 📄 LibreOffice

### 💬 Communication

#### 🗣️ Beeper

#### 🐦‍⬛ Thunderbird

## 📸 Demo

![image](https://github.com/user-attachments/assets/297c3e10-f4e0-43c5-bab1-23afa6476d16)

## 🚀 Usage

The stuff you actually need to know to use this config for yourself.

### 🔗 Necessary Symlinks

- `wezterm/wezterm.lua` in this repo --> `C:\Users\user\.wezterm.lua`

### ⌨️ Keybinds

**Wezterm:**

Key constants - LEADER=`CTRL+A`

- Pane Management:
  | keybind | description |
  ***
  | `CTRL+ALT+H` | Opens new (default shell) pane to the right |
  | `CTRL+ALT+SHIFT+H` | Opens new selectable-shell pane to right |
  | `CTRL+ALT+V` | Opens new (default shell) pane below |
  | `CTRL+ALT+SHIFT+V` | Opens new selectable-shell pane below |
  | `LEADER+H` | Pane-navigates left |
  | `LEADER+J` | Pane-navigates down |
  | `LEADER+K` | Pane-navigates up |
  | `LEADER+L` | Pane-navigates right |
  | `CTRL+9` | Select panes by letter overlay |
  | `LEADER+R` | Resize active pain pane using vim HJKL |
  | `CTRL+W` | Close active pane |
  | `CTRL+SHIFT+W` | Close tab |
- Appearance
  | keybind | description |
  ***
  | `CTRL+ALT+SHIFT+O` | Toggles window transparency |
- Projects/Workspaces
  | keybind | description |
  ***
  | `LEADER+P` | Select project |
- Core functions
  | keybind | description |
  ***
  | `CTRL+SHIFT+P` | Open command palette |
  | `CTRL+SHIFT+L` | Shows debug overlay |
  | `CTRL+ALT+SHIFT+H` | Opens new selectable-shell pane to right |

**Neovim:**

## 🙌 Acknowledgements

- [@Wez](https://github.com/wez) (Wez Furlong) for his awesome terminal emulator/multiplexor!
- [@TJDevries](https://github.com/tjdevries) and the contributors of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) for the Neovim config starting point
- [@alexpls](https://github.com/alexpls) (Alex Plescan) for his WezTerm configuration guide blog [post](https://alexplescan.com/posts/2024/08/10/wezterm/#configuring-appearance)
- [@oscariquelme01](https://github.com/oscariquelme01) (Oscar Riquelme Jato) for Wezterm workspace saving/persistence

## ⚒️ Tasks

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
- [ ] create terminal
- [ ] svelte dev

## 📝 Notes to Self

- `CTRL+SHIFT+L` Opens the Wezterm Logs
- `C:\Users\{user}\.local\share` is where wezterm workspace JSON is stored
