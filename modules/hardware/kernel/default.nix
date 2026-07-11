{ lib, pkgs, config, ... }: {
  config = lib.mkIf config.athena.baseConfiguration {
    # If change kernel, remember to run 'sudo nixos-rebuild boot' and 'sudo reboot'
    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages; # LTS Kernel
      kernelModules = [ "rtl8821cu" ];
      # Pilote de fréquence AMD moderne (EPP) : meilleure efficacité/autonomie
      # sur Ryzen AI 300, en tandem avec power-profiles-daemon.
      kernelParams = [ "amd_pstate=active" ];
      # KMS précoce pour l'iGPU Radeon : boot plus propre (pas de changement
      # de mode, Plymouth correct).
      initrd.kernelModules = [ "amdgpu" ];
      loader.grub.useOSProber = true;
      extraModulePackages = with config.boot.kernelPackages; [ vmware ]; /*vmware needed to install VMware Workstation software*/
    };
  };
}
