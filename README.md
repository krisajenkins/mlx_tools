# mlx_tools

A Nix flake for running local LLMs on Apple Silicon using [MLX](https://github.com/ml-explore/mlx). Provides ready-to-use commands for interactive chat and text generation, with no Python environment setup required. Models are downloaded automatically from Hugging Face on first use.

## Installation

```bash
nix profile install github:krisajenkins/mlx_tools
```

Or run directly without installing:

```bash
nix run github:krisajenkins/mlx_tools
```

## Usage

```bash
# Interactive chat
mlx_chat

# Single-shot text generation
mlx_generate --prompt "Explain monads in one paragraph"

# Pipe input from stdin
echo "Summarize this text" | mlx_generate

# Override default token limit (4096)
mlx_generate --prompt "Write a story" --max-tokens 8192
```

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- Nix with flakes enabled

## License

MIT

## Credits

Built on [mlx-lm](https://github.com/ml-explore/mlx-examples/tree/main/llms/mlx_lm) by Apple.
