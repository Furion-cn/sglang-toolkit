#!/bin/bash

# 设置环境变量
export MAX_CONCURRENCIES=1024

kubectl delete statefulset --all -n inference-system
# 记录日志的目录
LOG_DIR="/root/sglang-auto/benchmark/furion-cn/logs"
mkdir -p $LOG_DIR

DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/benchmark_${DATE}.log"

# 运行benchmark脚本并记录日志
cd /root/sglang-auto/benchmark/furion-cn
./auto_benchmark.sh >> $LOG_FILE 2>&1