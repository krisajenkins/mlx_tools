# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Nix flake providing a packaged interface to MLX-LM for running local LLMs on Apple Silicon.

## Commands

```bash
nix run                     # Interactive chat (default, runs mlx_chat)
nix run .#mlx_chat          # Interactive chat with Qwen2.5-7B-Instruct-Uncensored-4bit
nix run .#mlx_generate -- --prompt "Hello"  # Single-shot text generation
nix build                   # Build the default package (mlx_chat)
nix flake check             # Validate the flake
```

## Architecture

The flake exports packages built with `writeShellApplication`:

- `mlx_chat` (default) - interactive chat via `mlx_lm.chat`
- `mlx_generate` - single-shot generation via `mlx_lm.generate`, accepts args

Each package bundles Python 3.13 and uv as runtime inputs, then runs the appropriate mlx_lm command against the flake source where `pyproject.toml` lives. Python dependencies (mlx-lm) are managed by uv via `pyproject.toml` and `uv.lock`.

To add new commands/models: create additional `writeShellApplication` packages following the existing pattern in `flake.nix`.

## Notes

- Apple Silicon only (MLX does not work on Intel Macs)
- Models download from Hugging Face's `mlx-community` on first use
- This is a jj (Jujutsu) repository
