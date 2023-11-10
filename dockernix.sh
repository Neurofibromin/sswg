#! /bin/bash


wget https://nixos.org/nix/install > nixosinstall.sh
sh ./nixosinstall.sh --daemon
rm nixosinstall.sh
nix-channel --add https://nixos.org/channels/nixos-22.11 nixpkgs
nix-channel --update
export NIXPKGS_ALLOW_UNFREE=1
nix-env -iA nixpkgs.openvpn
nix-env -iA nixpkgs.docker
nix-env -iA nixpkgs.nextcloud25
nix-env -iA nixpkgs.veracrypt
cp startup.sh ~/startup.sh
echo run startup.sh on start
