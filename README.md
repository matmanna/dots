# dots

my machines, in one place.

> [!caution]
> these change and break often. read before you copy.

## machines

- `trench` — nixos vps on contabo. k3s + [orchard](https://docs.orchard.my) at `orchard.matm.icu`
- `clancy` — arch laptop, niri
- `torchbearer` — retired windows box, archived

## structure

```
flake.nix         nixos config + deploy-rs
machines/trench/  trench's system: k3s, orchard, users
modules/nixos/    shared bits: zsh, tailscale, fail2ban, backups
secrets/          agenix, encrypted
dotfiles/         dotfiles for every machine (chezmoi)
archive/          old configs
```

## usage

```bash
# deploy trench
nix develop
deploy .#trench

# dotfiles
chezmoi init --apply matmanna/dots
chezmoi update
```

> [!warning]
> secrets are encrypted with agenix to my keys. swap in your own before using.

## credits

- [taciturnaxolotl/dots](https://github.com/taciturnaxolotl/dots) — layout, agenix, deploy-rs, fail2ban
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) + [disko](https://github.com/nix-community/disko)
- [chezmoi](https://chezmoi.io)
