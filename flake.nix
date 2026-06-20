{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {nixpkgs, ...}:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
      {
        devShells.${system} = rec {
          client = pkgs.mkShell {
            name = "olwr-client-devshell";
            packages = [
              pkgs.godotPackages_4_6.godot
            ];
          };
          default = client;
        };
      };
}
