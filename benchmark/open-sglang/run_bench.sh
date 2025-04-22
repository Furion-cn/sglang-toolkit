#!/bin/bash

set -e

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <furion-sglang-image>"
    exit 1
fi

cd sglang-deploy

FURION_SGLANG_IMAGE=$1
DATE=$(date +%Y%m%d)
SERVER_NAME="furion-sglang-autobench-${DATE}"

cleanup() {
    echo "Cleaning up..."
    bash delete.sh ${SERVER_NAME}
    exit 1
}

trap cleanup SIGINT SIGTERM

echo "Starting benchmark with:"
echo "Server name: ${SERVER_NAME}"
echo "Image: ${FURION_SGLANG_IMAGE}"

# 1. 部署服务
echo "Deploying service..."
bash apply.sh ${SERVER_NAME} ${FURION_SGLANG_IMAGE}

# 2. 等待prefill pod完成并退出
echo "Waiting for prefill pod to complete..."
while true; do
    # 检查pod状态
    POD_STATUS=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$POD_STATUS" == "NotFound" ]; then
        echo "Error: Prefill pod not found"
        exit 1
    elif [ "$POD_STATUS" == "Failed" ]; then
        echo "Error: Prefill pod failed"
        exit 1
    elif [ "$POD_STATUS" == "Succeeded" ]; then
        echo "Prefill pod completed successfully"
        break
    fi
    
    echo "Prefill pod status: ${POD_STATUS}, waiting..."
    sleep 10
done

# 3. 删除服务
echo "Benchmark completed, cleaning up..."
bash delete.sh ${SERVER_NAME}

echo "Benchmark run completed!"
echo "Check benchmark_results directory for test results." 