{ lib, pkgs, config, ... }: {
  config = lib.mkIf config.athena.baseConfiguration {
    # If change kernel, remember to run 'sudo nixos-rebuild boot' and 'sudo reboot'
    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages; # LTS Kernel
      kernelModules = [ "rtl8821cu" ];
      # Pilote de fréquence AMD moderne (EPP) : meilleure efficacité/autonomie
      # sur Ryzen AI 300, en tandem avec power-profiles-daemon.
      kernelParams = [ "amd_pstate=active" ];
      # NB : amdgpu N'EST PAS chargé en initrd (contrairement à l'intuition
      # "KMS précoce"). Sur ce combo simpledrm(EFI)->amdgpu, le charger en
      # initrd déclenche « Console: switching to dummy device » PENDANT le
      # déchiffrement LUKS -> écran muet, prompt & Plymouth invisibles (ESC
      # requis). On laisse simpledrm gérer tout le stage 1 (Plymouth y rend
      # correctement) ; amdgpu charge en stage 2, sans aucune perte.
      initrd.kernelModules = [ ];
      loader.grub.useOSProber = true;
      extraModulePackages = with config.boot.kernelPackages; [ vmware ]; /*vmware needed to install VMware Workstation software*/
    };
  };
}
