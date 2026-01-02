# Knowledge Distillation with MLX

A practical guide to training a small, fast local model using a larger model's outputs.

## Overview

Knowledge distillation lets you create a cheap, specialised model by:

1. Using a powerful "teacher" model to generate training examples
2. Fine-tuning a small "student" model on those examples

The result is a model that runs fast on your Mac while performing well on your specific task.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4)
- At least 8GB unified memory (16GB+ recommended)
- This project set up with `nix develop`

## Step 1: Choose Your Models

### Teacher Model (generates training data)

Use the most capable model you have access to:

- **API-based**: Claude, GPT-4, Gemini (best quality, costs money)
- **Local large model**: Llama 70B, Qwen 72B (needs 64GB+ RAM)

### Student Model (what you'll fine-tune)

Choose based on your hardware:

| RAM   | Recommended Student Model                  |
| ----- | ------------------------------------------ |
| 8GB   | `mlx-community/Qwen2.5-1.5B-Instruct-4bit` |
| 16GB  | `mlx-community/Qwen2.5-7B-Instruct-4bit`   |
| 32GB+ | `mlx-community/Qwen2.5-14B-Instruct-4bit`  |

## Step 2: Define Your Task

Distillation works best for **narrow, well-defined tasks**. Examples:

- Summarising technical documentation
- Extracting structured data from text
- Translating domain-specific jargon
- Classifying support tickets
- Generating code in a specific framework

Write down:

1. What the input looks like
2. What the output should look like
3. 5-10 example input/output pairs (for prompting the teacher)

## Step 3: Generate Training Data

### Option A: Using an API (recommended for quality)

Create a script to generate examples. Here's a template:

```bash
#!/usr/bin/env bash
# generate_training_data.sh

TASK_PROMPT="You are an expert at summarising technical documentation.
Given a technical document, produce a 2-3 sentence summary focusing on
what problem it solves and how to use it.

Document:
"

# Process each input file
for file in inputs/*.txt; do
    content=$(cat "$file")

    # Using Claude API (install: pip install anthropic)
    response=$(python3 << EOF
import anthropic
client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    messages=[{"role": "user", "content": """${TASK_PROMPT}${content}"""}]
)
print(message.content[0].text)
EOF
)

    # Append to training data as JSONL
    jq -n --arg prompt "$content" --arg completion "$response" \
        '{prompt: $prompt, completion: $completion}' >> training_data.jsonl

    echo "Processed: $file"
    sleep 1  # Rate limiting
done
```

### Option B: Using a Local Teacher Model

If you have enough RAM for a large local model:

```bash
#!/usr/bin/env bash
# generate_with_local_model.sh

MODEL="mlx-community/Llama-3.3-70B-Instruct-4bit"

for file in inputs/*.txt; do
    content=$(cat "$file")

    response=$(uv run mlx_lm.generate \
        --model "$MODEL" \
        --prompt "Summarise this document:\n\n$content" \
        --max-tokens 256)

    jq -n --arg prompt "$content" --arg completion "$response" \
        '{prompt: $prompt, completion: $completion}' >> training_data.jsonl
done
```

### Training Data Format

Your `training_data.jsonl` should look like:

```json
{"prompt": "Your input text here...", "completion": "The expected output..."}
{"prompt": "Another input...", "completion": "Another output..."}
```

### How Much Data?

| Task Complexity       | Examples Needed |
| --------------------- | --------------- |
| Simple classification | 100-500         |
| Text transformation   | 500-2000        |
| Complex generation    | 2000-10000      |

More data generally helps, but quality matters more than quantity.

## Step 4: Prepare Training Data

Split your data into training and validation sets:

```bash
# Shuffle and split (90% train, 10% validation)
shuf training_data.jsonl > shuffled.jsonl
total=$(wc -l < shuffled.jsonl)
train_size=$((total * 9 / 10))

head -n "$train_size" shuffled.jsonl > train.jsonl
tail -n +"$((train_size + 1))" shuffled.jsonl > valid.jsonl

# Create data directory structure
mkdir -p data
mv train.jsonl valid.jsonl data/

rm shuffled.jsonl
```

## Step 5: Fine-Tune the Student Model

Run LoRA fine-tuning:

```bash
uv run mlx_lm.lora \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --train \
    --data ./data \
    --iters 1000 \
    --batch-size 4 \
    --lora-rank 8 \
    --learning-rate 1e-5 \
    --adapter-path ./adapters
```

### Key Parameters

| Parameter         | Description       | Guidance                                      |
| ----------------- | ----------------- | --------------------------------------------- |
| `--iters`         | Training steps    | Start with 500-1000, increase if underfitting |
| `--batch-size`    | Examples per step | Lower if you run out of memory                |
| `--lora-rank`     | Adapter capacity  | 8-16 for simple tasks, 32-64 for complex      |
| `--learning-rate` | How fast to learn | 1e-5 to 1e-4, lower if loss spikes            |

### Monitor Training

Watch the loss values. Good training looks like:

```
Iter 100: train loss 2.45, val loss 2.51
Iter 200: train loss 1.82, val loss 1.89
Iter 300: train loss 1.34, val loss 1.45
...
```

Warning signs:

- **Val loss increasing while train loss decreases**: Overfitting, stop early or get more data
- **Loss not decreasing**: Learning rate too low, or data quality issues
- **Loss oscillating wildly**: Learning rate too high

## Step 6: Test Your Model

Test with the adapter:

```bash
uv run mlx_lm.generate \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --adapter-path ./adapters \
    --prompt "Your test input here..."
```

Or start an interactive chat:

```bash
uv run mlx_lm.chat \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --adapter-path ./adapters
```

## Step 7: Fuse the Adapter (Optional)

For faster inference, merge the adapter into the base model:

```bash
uv run mlx_lm.fuse \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --adapter-path ./adapters \
    --save-path ./my-distilled-model
```

Now you can use it directly:

```bash
uv run mlx_lm.chat --model ./my-distilled-model
```

## Step 8: Iterate and Improve

If results aren't good enough:

1. **Analyse failures**: Look at examples where the model fails
2. **Add targeted data**: Generate more examples for failure cases
3. **Adjust prompts**: Sometimes rephrasing inputs helps
4. **Try a larger student**: Move up one model size
5. **Increase LoRA rank**: Gives the adapter more capacity

## Complete Example: Code Review Bot

Here's a full worked example for a code review assistant:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Create input corpus (collect Python files to review)
mkdir -p inputs
find ~/projects -name "*.py" -size -10k | head -200 | while read f; do
    cp "$f" "inputs/$(basename "$f" .py)_$(date +%s%N).py"
done

# 2. Generate training data using Claude
mkdir -p data
for file in inputs/*.py; do
    code=$(cat "$file")

    review=$(python3 << EOF
import anthropic
client = anthropic.Anthropic()
message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    messages=[{"role": "user", "content": """Review this Python code.
Focus on bugs, security issues, and major style problems.
Be concise - just list the issues found, or say "No issues found."

\`\`\`python
${code}
\`\`\`"""}]
)
print(message.content[0].text)
EOF
)

    jq -n --arg prompt "$code" --arg completion "$review" \
        '{prompt: $prompt, completion: $completion}' >> data/all.jsonl

    sleep 1
done

# 3. Split data
cd data
shuf all.jsonl > shuffled.jsonl
head -n 180 shuffled.jsonl > train.jsonl
tail -n 20 shuffled.jsonl > valid.jsonl
cd ..

# 4. Fine-tune
uv run mlx_lm.lora \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --train \
    --data ./data \
    --iters 500 \
    --batch-size 2 \
    --lora-rank 16 \
    --adapter-path ./code-review-adapter

# 5. Test it
echo "Testing the model..."
uv run mlx_lm.generate \
    --model mlx-community/Qwen2.5-7B-Instruct-4bit \
    --adapter-path ./code-review-adapter \
    --prompt "def login(user, pw):
    query = f'SELECT * FROM users WHERE name={user} AND pass={pw}'
    return db.execute(query)"
```

## Legal Considerations

Before distilling:

1. **Check model licenses**: Some prohibit using outputs for training
2. **API Terms of Service**: OpenAI, Anthropic, etc. have specific rules
3. **Open models are safest**: Llama, Qwen, Mistral generally permit this

When in doubt, use open-weight models as teachers.

## Further Reading

- [LoRA Paper](https://arxiv.org/abs/2106.09685) - The technique behind efficient fine-tuning
- [MLX Documentation](https://ml-explore.github.io/mlx/) - Apple's ML framework
- [mlx-lm GitHub](https://github.com/ml-explore/mlx-examples/tree/main/llms/mlx_lm) - Source and examples
