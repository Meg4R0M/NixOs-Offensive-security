{ lib, config, ... }: {
  config = lib.mkIf (config.humanix.bootloader == "systemd") {
    # Bootloader
    boot.loader = {
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/efi";
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };
  };
}
