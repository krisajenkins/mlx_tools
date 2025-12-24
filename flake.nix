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

        mlx_chat = pkgs.writeShellApplication {
          name = "mlx_chat";
          runtimeInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
          text = ''
            cd ${self}
            uv run mlx_lm.chat --model mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit
          '';
        };

        mlx_generate = pkgs.writeShellApplication {
          name = "mlx_generate";
          runtimeInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
          text = ''
            cd ${self}
            uv run mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit "$@"
          '';
        };

      in
      {
        packages = {
          inherit mlx_chat mlx_generate;
          default = mlx_chat;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
        };
      });
}
