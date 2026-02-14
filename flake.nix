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
        model = "mlx-community/Qwen3-32B-4bit";

        modelCacheDir = builtins.replaceStrings [ "/" ] [ "--" ] model;

        ensureModel = ''
          model_cache_dir="''${HF_HOME:-$HOME/.cache/huggingface}/hub/models--${modelCacheDir}"
          if [ ! -d "$model_cache_dir" ]; then
            echo "Downloading model ${model}..."
            uv run huggingface-cli download "${model}"
          fi
        '';

        mlx_chat = pkgs.writeShellApplication {
          name = "mlx_chat";
          runtimeInputs = with pkgs; [
            python313Packages.python
            python313Packages.uv
          ];
          text = ''
            mkdir -p "${cacheDir}"
            export UV_PROJECT_ENVIRONMENT="${cacheDir}/.venv"
            cd ${self}
            ${ensureModel}
            uv run mlx_lm.chat --model "${model}"
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
            cd ${self}
            ${ensureModel}
            if [ ! -t 0 ]; then
              prompt=$(cat)
              uv run mlx_lm.generate --model "${model}" --verbose False --max-tokens 4096 --prompt "$prompt" "$@"
            else
              uv run mlx_lm.generate --model "${model}" --verbose False --max-tokens 4096 "$@"
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
          default = mlx_chat;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            mlx_chat
            mlx_generate
          ];
        };
      });
}
