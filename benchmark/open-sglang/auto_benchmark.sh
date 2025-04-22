#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


set -e

echo "=== Step 1: Building Image ==="
# 运行构建镜像脚本
cd ${SCRIPT_DIR}
bash build_image.sh

# 获取最新构建的镜像信息
LATEST_IMAGE_INFO=$(ls -t image_info_*.txt | head -n1)
if [ -z "${LATEST_IMAGE_INFO}" ]; then
    echo "Error: No image info file found"
    exit 1
fi

FURION_SGLANG_IMAGE=$(cat ${LATEST_IMAGE_INFO} | cut -d'=' -f2)
echo "Latest built image: ${FURION_SGLANG_IMAGE}"

echo "=== Step 2: Running Benchmark ==="
# 运行基准测试脚本
bash run_bench.sh ${FURION_SGLANG_IMAGE}

echo "=== All Steps Completed ==="
echo "Image: ${FURION_SGLANG_IMAGE}"
echo "Check benchmark_results directory for test results."