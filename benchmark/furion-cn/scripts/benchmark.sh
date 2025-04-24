#!/bin/bash

set -e

num_prompts_per_concurrency=3
input_seq_len=4383
output_seq_len=1210
# max_concurrencies=(1 2 4 8 16 32 64 128 256 512 1024 2048 3072 4096)

# 支持多个并发数，用逗号分隔，例如：MAX_CONCURRENCIES="4,8,16"
max_concurrencies=(${MAX_CONCURRENCIES:-16})

# 如果环境变量包含逗号，则转换为数组
if [[ $MAX_CONCURRENCIES == *","* ]]; then
    IFS=',' read -ra max_concurrencies <<< "$MAX_CONCURRENCIES"
fi

for max_concurrency in ${max_concurrencies[@]};do
    echo benchmark on max_concurrency $max_concurrency!
    let num_prompts=${num_prompts_per_concurrency}*${max_concurrency}
    python3 -m sglang.bench_serving --backend sglang --dataset-name random --num-prompts ${num_prompts} --random-input ${input_seq_len} --random-output ${output_seq_len} --max-concurrency ${max_concurrency} --dataset-path /models/ShareGPT_V3_unfiltered_cleaned_split.json
done
