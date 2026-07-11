{ lib, config, ... }: {
  config = lib.mkIf (config.athena.bootloader == "grub") {
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
