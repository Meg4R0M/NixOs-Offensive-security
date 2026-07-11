# ─────────────────────────────────────────────────────────────────────────────
# Humanix · Arsenal RF / embarqué
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI : l'ADN Humanix, c'est « la bidouille est reine ». La machine doit
# être un poste de pilotage universel pour tout l'arsenal offensif RF/embarqué.
# Sans accès non-root aux devices (série/USB), rien n'est utilisable au quotidien.
#
# Ce module ajoute, de façon DÉBRAYABLE (options humanix.hardware.*) :
#   - les groupes user manquants (dialout/plugdev/uucp/input/wireshark)
#   - des règles udev centralisées (accès sans root aux devices)
#   - les toolchains de flash/série et les outils SDR
#
# 1er jalon du namespace `humanix.*` (le rename humanix.* -> humanix.* viendra
# dans la vague flake dédiée ; le code NEUF est déjà en humanix.*).
{ lib, pkgs, config, ... }:
let
  cfg = config.humanix.hardware;
  user = config.humanix.homeManagerUser;
in {
  options.humanix.hardware = {
    arsenal.enable = lib.mkEnableOption
      "l'arsenal RF/embarqué : groupes user + règles udev (accès devices sans root)";
    sdr = {
      enable = lib.mkEnableOption
        "les outils SDR en ligne de commande (rtl-sdr, hackrf, soapysdr, rtl_433, multimon-ng)";
      gui.enable = lib.mkEnableOption
        "les GUI SDR lourdes (gqrx, gnuradio, urh, sdrangel) — ⚠️ premier build potentiellement long";
    };
    embedded.enable = lib.mkEnableOption
      "les toolchains de flash/série embarqué + Flipper (esptool, avrdude, arduino-cli, picotool, openocd, tio, qflipper…)";
  };

  config = lib.mkMerge [

    # ── Fondation : groupes + règles udev + wireshark ────────────────────────
    (lib.mkIf cfg.arsenal.enable {
      # Accès série (dialout/uucp), USB générique (plugdev), HID (input),
      # capture réseau (wireshark, groupe créé par programs.wireshark).
      users.users.${user}.extraGroups = [ "dialout" "plugdev" "uucp" "input" "wireshark" ];
      programs.wireshark.enable = true;

      # Règles pour les devices qui n'embarquent PAS leurs propres règles udev.
      # (RTL-SDR/HackRF/OpenOCD fournissent les leurs via services.udev.packages
      #  sous humanix.hardware.sdr/embedded.)
      # TAG+="uaccess" => accès à la session active via logind (méthode moderne),
      # + GROUP dialout/plugdev en filet pour les sessions non-logind.
      services.udev.extraRules = ''
        # ── Série / TTL (Arduino, ESP32, M5, T-Embed, badges) → dialout ──
        # FTDI
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", MODE="0660", GROUP="dialout", TAG+="uaccess"
        # CH340 / CH341 (WCH)
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1a86", MODE="0660", GROUP="dialout", TAG+="uaccess"
        # CP210x (Silicon Labs / ESP32 / T-Embed / T-Dongle)
        SUBSYSTEM=="usb", ATTRS{idVendor}=="10c4", MODE="0660", GROUP="dialout", TAG+="uaccess"
        # Arduino officiel
        SUBSYSTEM=="usb", ATTRS{idVendor}=="2341", MODE="0660", GROUP="dialout", TAG+="uaccess"
        # SparkFun
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1b4f", MODE="0660", GROUP="dialout", TAG+="uaccess"

        # ── Flipper Zero (STM32 VCP) ──
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0660", GROUP="dialout", TAG+="uaccess"
        # DFU STM32 (Flipper recovery, bluepill)
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0660", GROUP="plugdev", TAG+="uaccess"

        # ── RP2040 / Pi Pico (BOOTSEL mass-storage + picoprobe/CMSIS-DAP) ──
        SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0660", GROUP="plugdev", TAG+="uaccess"

        # ── Proxmark3 (RDV4 / autres) ──
        SUBSYSTEM=="usb", ATTRS{idVendor}=="9ac4", MODE="0660", GROUP="plugdev", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="502d", MODE="0660", GROUP="plugdev", TAG+="uaccess"

        # ── Crazyradio PA / nRF (MouseJack, jackit) ──
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1915", MODE="0660", GROUP="plugdev", TAG+="uaccess"

        # ── ST-Link v2 / v2.1 (SWD/JTAG) ──
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="0660", GROUP="plugdev", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      '';
    })

    # ── SDR — CLI (léger, majoritairement en cache binaire) ──────────────────
    (lib.mkIf cfg.sdr.enable {
      environment.systemPackages = with pkgs; [
        rtl-sdr hackrf soapysdr-with-plugins rtl_433 multimon-ng
      ];
      # Ces paquets fournissent leurs propres règles udev.
      services.udev.packages = with pkgs; [ rtl-sdr hackrf ];
    })

    # ── SDR — GUI (lourd, opt-in) ────────────────────────────────────────────
    (lib.mkIf cfg.sdr.gui.enable {
      environment.systemPackages = with pkgs; [ gqrx gnuradio urh sdrangel ];
    })

    # ── Embarqué — flash / série / Flipper ───────────────────────────────────
    (lib.mkIf cfg.embedded.enable {
      environment.systemPackages = with pkgs; [
        esptool avrdude arduino-cli platformio-core picotool openocd dfu-util
        tio minicom picocom
        qFlipper
      ];
      services.udev.packages = with pkgs; [ openocd ];
    })
  ];
}
