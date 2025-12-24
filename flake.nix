{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

      in
      {
        packages = { };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
        };
      });
}
