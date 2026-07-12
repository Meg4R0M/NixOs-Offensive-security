{ lib, config, ... }:
{
  imports = [
    ./cyber
    ./cyber/arsenal-plus.nix
    ./dev
    ./hardware
    ./misc
  ];
}
