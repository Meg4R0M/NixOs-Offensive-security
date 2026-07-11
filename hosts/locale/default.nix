{ lib, config, pkgs, ... }: {
  config = lib.mkIf config.athena.baseLocale {
    # Set your time zone.
    time.timeZone = "Europe/Paris";

    # Select internationalisation properties.
    i18n.defaultLocale = "fr_FR.UTF-8";

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
      packages = with pkgs; [ terminus_font ];
      keyMap = "fr";
    };

    # Configure keymap in X11
    services.xserver = {
      exportConfiguration = true;
      xkb = {
        layout = "fr";
        variant = "oss";
      };
    };
  };
}
