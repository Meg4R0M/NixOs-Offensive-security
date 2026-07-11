# Arsenal RF / embarqué — Humanix

Module : `modules/hardware/arsenal.nix` · Options : `humanix.hardware.*` · Activé dans `configuration.nix`.

> 1er jalon du namespace `humanix.*`. Le rename global `athena.* → humanix.*` viendra dans la vague flake.

## Toggles débrayables

| Option | Effet |
|---|---|
| `humanix.hardware.arsenal.enable` | Groupes user (`dialout`/`plugdev`/`uucp`/`input`/`wireshark`) + règles udev (accès devices **sans root**) + Wireshark |
| `humanix.hardware.sdr.enable` | SDR CLI : `rtl-sdr`, `hackrf`, `soapysdr-with-plugins`, `rtl_433`, `multimon-ng` |
| `humanix.hardware.sdr.gui.enable` | ⚠️ GUI SDR **lourdes** : `gqrx`, `gnuradio`, `urh`, `sdrangel` — opt-in (1er build long si hors cache) |
| `humanix.hardware.embedded.enable` | Flash/série : `esptool`, `avrdude`, `arduino-cli`, `platformio-core`, `picotool`, `openocd`, `dfu-util`, `tio`, `minicom`, `picocom`, `qFlipper` |

## Devices couverts (règles udev)

Série (FTDI / CH340 / CP210x / Arduino / SparkFun), **Flipper Zero** (VCP + DFU), **RP2040/Pico** (BOOTSEL), **Proxmark3**, **Crazyradio/nRF**, **ST-Link**. RTL-SDR / HackRF / OpenOCD apportent leurs propres règles via `services.udev.packages`.

## Après application

```bash
sudo nixos-rebuild switch -I nixos-config=$HOME/nixos/configuration.nix
```

- **Re-login** (ou reboot) requis pour les nouveaux groupes.
- **Débrancher/rebrancher** les devices pour (re)déclencher les règles udev.
- Vérifs : `groups | tr ' ' '\n' | grep -E 'dialout|plugdev|wireshark'` · `esptool version` · `tio --version` · `rtl_test` (RTL-SDR branché) · `qFlipper`.

## Reste MANUEL / hors-nixpkgs (vagues futures)

- **jackit** (nRF24 MouseJack) : **absent de nixpkgs** → overlay/dérivation custom à créer + firmware *nrf-research* à flasher sur la Crazyradio (tooling non-officiel, à documenter).
- **Firmwares externes** (à *flasher*, pas des paquets système) :
  - ESP32 **Marauder** / **M5 Cardputer** (Evil-M5Project) → via `esptool` / M5Burner-like.
  - Firmwares *nrf-research* (MouseJack).
- **Images dédiées** (carte SD séparée, **pas le host**) : Pwnagotchi, RaspiJack, RPi Zero rogue AP. Le host = supervision / tether BT/USB.
- **GUI SDR** : passer `humanix.hardware.sdr.gui.enable = true` quand prêt à encaisser le build.

## ⚖️ Rappel légal

Émission RF / WiFi / injection = **uniquement sur cibles autorisées** (labo, matériel possédé, mandat de test écrit). France : **LCEN** / **art. 323 CP** (intrusion) · réglementation **ARCEP** (émission RF). Usage : formation, R&D, audits mandatés, CTF, démo pédagogique.
