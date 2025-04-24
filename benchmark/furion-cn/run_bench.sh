#!/bin/bash

set -e

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <furion-sglang-image>"
    exit 1
fi

# 从环境变量读取配置，如果未设置则使用默认值
PREFILL_REPLICA=${PREFILL_REPLICA:-2}
PREFILL_TP=${PREFILL_TP:-16}
PREFILL_DP=${PREFILL_DP:-4}
DECODE_REPLICA=${DECODE_REPLICA:-2}
DECODE_TP=${DECODE_TP:-16}
DECODE_DP=${DECODE_DP:-16}
MAX_CONCURRENCIES=${MAX_CONCURRENCIES:-1024}

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
bash apply.sh ${SERVER_NAME} ${FURION_SGLANG_IMAGE} -pr ${PREFILL_REPLICA} -pt ${PREFILL_TP} -pd ${PREFILL_DP} -dr ${DECODE_REPLICA} -dt ${DECODE_TP} -dd ${DECODE_DP} -mc ${MAX_CONCURRENCIES}

# 2. 等待prefill pod完成并退出
echo "Waiting for prefill pod to complete..."
while true; do
    # 检查pod状态
    POD_STATUS=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    # 检查重启次数
    RESTART_COUNT=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    if [ "$POD_STATUS" == "NotFound" ]; then
        echo "Error: Prefill pod not found"
        exit 1
    elif [ "$POD_STATUS" == "Failed" ]; then
        echo "Error: Prefill pod failed"
        exit 1
    elif [ "$RESTART_COUNT" != "0" ]; then
        echo "Error: Pod has been restarted ${RESTART_COUNT} times, indicating issues"
        exit 1
    elif [ "$POD_STATUS" == "Succeeded" ]; then
        echo "Prefill pod completed successfully"
        break
    fi
    
    echo "Prefill pod status: ${POD_STATUS}, restart count: ${RESTART_COUNT}, waiting..."
    sleep 10
done

echo "Benchmark run completed!"
echo "Check benchmark_results directory for test results." 