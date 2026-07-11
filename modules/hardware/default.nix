{ lib, pkgs, config, ... }: {
  imports = [
    ./arsenal.nix
    ./kernel-cachyos.nix
    ./bluetooth
    ./kernel
    ./network
    ./sound
    ./virtualization
  ];

  config = lib.mkIf config.athena.baseConfiguration {
    # KDE complains if power management is disabled (to be precise, if
    # there is no power management backend such as upower).
    # On laisse l'infra activée mais SANS forcer un governor : amd_pstate
    # (cf. modules/hardware/kernel) + power-profiles-daemon gèrent la montée
    # en fréquence dynamiquement (meilleure autonomie sur ce portable AMD).
    powerManagement.enable = true;

    services = {
      hardware.bolt.enable = true;
      printing.enable = false;
      timesyncd.enable = lib.mkDefault true;
      libinput.enable = true;
      # Gestion d'énergie dynamique (intègre le curseur perf/équilibré/éco
      # de GNOME). Remplace le cpuFreqGovernor=performance forcé.
      power-profiles-daemon.enable = true;
      # Mises à jour firmware/BIOS via LVFS (HP OmniBook supporté).
      fwupd.enable = true;
    };

    zramSwap.enable = true;
    hardware = {
      cpu.amd.updateMicrocode = true;
      bluetooth.enable = true;
      #enableAllFirmware = true; # Need allowUnfree = true
      enableRedistributableFirmware = true;
      # Convertible 2-in-1 : accéléromètre/gyro pour la rotation auto de
      # l'écran + capteur de luminosité (via iio-sensor-proxy).
      sensor.iio.enable = true;
      graphics = {
        enable = true;
        # Décodage vidéo matériel. Le driver VAAPI AMD (radeonsi) vient déjà
        # de Mesa ; on ajoute le pont VDPAU<->VAAPI en complément.
        extraPackages = with pkgs; [ libvdpau-va-gl ];
      };
    };

    # vainfo pour vérifier l'accélération vidéo.
    environment.systemPackages = with pkgs; [ libva-utils ];
  };
}
