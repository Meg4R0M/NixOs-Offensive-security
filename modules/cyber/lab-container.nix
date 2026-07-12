# Humanix · Conteneur pentest jetable (repris de redcode-labs/RedNix container.nix).
# Un systemd-nspawn déclaratif, réseau privé + ports forwardés, GUI remontée vers
# l'hôte. Idéal CTF/lab (arsenal isolé du système hôte).
# Débrayable : humanix.lab.container.enable (défaut OFF — construit un système).
#   Usage : sudo machinectl start humanix-lab ; sudo machinectl shell humanix-lab
{ lib, config, ... }:
let
  cfg = config.humanix.lab.container;
  inherit (lib) mkEnableOption mkIf;
in {
  options.humanix.lab.container.enable =
    mkEnableOption "conteneur pentest jetable 'humanix-lab' (réseau privé, arsenal isolé)";

  config = mkIf cfg.enable {
    containers.humanix-lab = {
      autoStart = false;
      privateNetwork = true;
      hostAddress = "10.66.0.1";
      localAddress = "10.66.0.2";
      # Ports du conteneur remontés sur l'hôte.
      forwardPorts = [
        { protocol = "tcp"; hostPort = 2222; containerPort = 22; }
        { protocol = "tcp"; hostPort = 8888; containerPort = 80; }
      ];
      config = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
          nmap netexec ffuf nuclei feroxbuster gobuster seclists tmux
        ];
        # Remonte les GUI (burp, wireshark…) vers le serveur X de l'hôte.
        environment.sessionVariables.DISPLAY = "10.66.0.1:0";
        networking.firewall.enable = false;
        system.stateVersion = "24.05";
      };
    };
    # NAT pour que le conteneur sorte sur Internet via l'hôte.
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-humanix-lab" ];
    };
  };
}
