{ lib, config, ... }: {
  config = lib.mkIf (config.humanix.bootloader == "grub") {
    # Bootloader
    boot.loader = {
      grub = {
        enable = true;
        device = "/dev/nvme0n1";
        enableCryptodisk = true;
        configurationLimit = 5;
      };
    };
  };
}
