{ lib, config, ... }: {
  config = lib.mkIf config.humanix.baseConfiguration {
    networking.networkmanager.enable = true;
    services.vnstat.enable = true;
    users.users.${config.humanix.homeManagerUser} = {
      extraGroups = [ "networkmanager" ];
    };
  };
}
