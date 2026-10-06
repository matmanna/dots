# dots

Everything for my machines in one repo:

| Machine | OS | System config | Personal files (`~`) |
|---|---|---|---|
| clancy | Arch laptop | pacman, by hand | chezmoi (`home/`) |
| trench | NixOS on Contabo (k3s + Orchard) | Nix flake (`flake.nix`, `machines/trench`) | chezmoi (`home/`) |

## Layout

- `flake.nix`, `machines/`, `modules/`: NixOS system config. Deployed with
  deploy-rs: `nix run .#deploy -- .#trench` (rolls back automatically if the
  box stops answering).
- `secrets/`: agenix. Recipients in `secrets/secrets.nix`.
- `home/`: chezmoi source for per-user dotfiles on every machine
  (`.chezmoiroot` points chezmoi here). Host differences are templates keyed on
  `.chezmoi.hostname`; `home/.chezmoiignore` drops desktop-only configs on
  trench. On trench, system-wide zsh + oh-my-zsh comes from the flake, so the
  chezmoi `.zshrc` there only carries personal settings.

## Dotfiles day to day

    chezmoi edit ~/.zshrc     # edit the source, including templates
    chezmoi diff              # what apply would change
    chezmoi apply             # write it to $HOME
    chezmoi re-add            # pull edits made directly in $HOME back (non-templates)

New machine: `chezmoi init --apply <repo-url>`.
