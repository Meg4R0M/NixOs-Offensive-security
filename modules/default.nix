{ lib, config, ... }:
{
  imports = [
    ./cyber
    ./cyber/arsenal-plus.nix
    ./cyber/pentest-helpers.nix
    ./cyber/lab-container.nix
    ./cyber/jupyter-pentest.nix
    ./cyber/hexstrike.nix
    ./cyber/defectdojo.nix
    ./dev
    ./hardware
    ./misc
    ./security
  ];
}
