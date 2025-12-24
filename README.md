> My M2 mac has fancy neural chip stuff, but I don’t feel I’m making any use of it. I’m a technical user, I happily use Ollama. Give me some ideas to make the most of this fancy hardward?

You're right that the Neural Engine often sits underutilised! Here are some ways to actually put it to work:

## Local LLMs via MLX

Ollama is great, but Apple's MLX framework is specifically optimised for Apple Silicon and can leverage the Neural Engine more effectively. Check out mlx-lm for running quantised models—you'll often get better tokens/sec than with llama.cpp backends.

```sh
pip install mlx-lm
mlx_lm.generate --model mlx-community/Mistral-7B-Instruct-v0.3-4bit --prompt "Hello"
```
