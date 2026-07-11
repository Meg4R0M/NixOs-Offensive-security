# Boot & Login « cinéma » — Humanix

## Login — greetd + tuigreet
Module : `modules/dms/greetd/default.nix`. Activé par `athena.displayManager = "greetd"` (dans `configuration.nix`).

- Login **100 % console**, thème vert phosphore / rouge, horloge, greeting « ACCÈS RESTREINT ».
- Sessions proposées : **niri / hyprland / gnome** (lues dans `wayland-sessions` + `xsessions`, enregistrées par `programs.niri.enable` etc.).
- **Repli SDDM** : remettre `dmanager = "sddm";` dans `configuration.nix` (1 ligne) + rebuild.
- Rattrapage : si le login graphique casse, `Ctrl+Alt+F2` → shell texte.

## Boot — Plymouth
Module : `modules/design/plymouth.nix` + `modules/design/plymouth/{humanix.script,humanix.plymouth}`. Toggle : `humanix.aesthetic.plymouth.enable`.

- Logo **HUMANIX** vert phosphore + barre de progression texte + ligne de statut, fond noir.
- `boot.kernelParams = [ "quiet" "splash" ]` (retirer `"quiet"` pour retrouver le dmesg brut).
- La cible plymouth de **Stylix est désactivée** (sinon conflit `boot.plymouth.theme`).
- Risque boot : **faible** — un échec plymouth = boot en mode texte, jamais bloquant.

## ⚠️ Tester AVANT de switcher (recommandé, cf méthode §2.5)
```bash
# VM générée par `nixos-rebuild build-vm` :
./result/bin/run-Humanix-vm
```
Dans la VM : vérifier que **tuigreet s'affiche**, choisir une session (niri/hyprland/gnome) et se connecter avec tes identifiants. Quitter = fermer la fenêtre QEMU.
> Note : le splash Plymouth peut ne pas s'afficher en VM (console virtuelle) ; il se voit sur la vraie machine.

## Appliquer sur la vraie machine
```bash
sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix
```
Filets de sécurité :
- **Rollback** : au boot, menu systemd-boot → génération précédente.
- **Repli SDDM** : `dmanager = "sddm"` + rebuild.
- **TTY** : `Ctrl+Alt+F2`.

## À affiner (vagues futures)
- tuigreet : bannière **ASCII multi-ligne** (le greeting actuel est un one-liner).
- Plymouth : vrai **défilement « dmesg » scénarisé** + glitch + logo ASCII plus riche.
- **MOTD** hacker au shell + fastfetch au login.
