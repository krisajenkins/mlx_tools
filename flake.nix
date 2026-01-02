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

        cacheDir = "\${XDG_CACHE_HOME:-$HOME/.cache}/mlx_tools";

        mlx_chat = pkgs.writeShellApplication {
          name = "mlx_chat";
          runtimeInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
          text = ''
            mkdir -p "${cacheDir}"
            export UV_PROJECT_ENVIRONMENT="${cacheDir}/.venv"
            export HF_HUB_DISABLE_PROGRESS_BARS=1
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
            mkdir -p "${cacheDir}"
            export UV_PROJECT_ENVIRONMENT="${cacheDir}/.venv"
            export HF_HUB_DISABLE_PROGRESS_BARS=1
            cd ${self}
            if [ ! -t 0 ]; then
              prompt=$(cat)
              uv run mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit --verbose False --prompt "$prompt" "$@"
            else
              uv run mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit --verbose False "$@"
            fi
          '';
        };

        mlx_tools = pkgs.symlinkJoin {
          name = "mlx_tools";
          paths = [ mlx_chat mlx_generate ];
        };

      in
      {
        packages = {
          inherit mlx_chat mlx_generate mlx_tools;
          default = mlx_tools;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
        };
      });
}
