{ lib, config, pkgs, ... }: {
  config = lib.mkIf (config.humanix.displayManager == "ly") {
    services.displayManager.ly = {
      enable = true;
      settings = {
          animation = "matrix";
          brightness_down_key = "null";
          brightness_up_key = "null";
          hide_version_string = true;
      };
    };
  };
}
