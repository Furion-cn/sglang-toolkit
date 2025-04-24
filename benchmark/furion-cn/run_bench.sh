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
}

# 确保在脚本退出时执行cleanup
trap cleanup EXIT
# 同时捕获中断信号
trap "exit" SIGINT SIGTERM

echo "Starting benchmark with:"
echo "Server name: ${SERVER_NAME}"
echo "Image: ${FURION_SGLANG_IMAGE}"

# 1. 部署服务
echo "Deploying service..."
bash apply.sh ${SERVER_NAME} ${FURION_SGLANG_IMAGE}

# 2. 等待prefill pod完成并退出
echo "Waiting for prefill pod to complete..."
START_TIME=$(date +%s)
TIMEOUT=$((60 * 60))  # 60分钟超时时间（秒）

while true; do
    # 检查是否超时
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
        echo "Error: Timeout after 60 minutes waiting for prefill pod"
        exit 1
    fi
    
    # 检查pod状态
    POD_STATUS=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$POD_STATUS" == "NotFound" ]; then
        echo "Error: Prefill pod not found"
        exit 1
    elif [ "$POD_STATUS" == "Failed" ]; then
        echo "Error: Prefill pod failed"
        exit 1
    elif [ "$POD_STATUS" == "Pending" ]; then
        # Pod还在等待调度，获取更详细的Pending原因
        PENDING_REASON=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].reason}' 2>/dev/null || echo "Unknown")
        echo "Pod is pending, reason: ${PENDING_REASON}"
        sleep 30
        continue
    fi

    if [ "$POD_STATUS" == "Running" ] || [ "$POD_STATUS" == "Succeeded" ]; then
        RESTART_COUNT=$(kubectl get pod ${SERVER_NAME}-prefill-0 --namespace=inference-system -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

        # 确保变量是数字
        if [[ ! "$RESTART_COUNT" =~ ^[0-9]+$ ]]; then
            echo "Warning: Invalid RESTART_COUNT value: '${RESTART_COUNT}'"
            RESTART_COUNT=0
        fi

        if [ -n "$RESTART_COUNT" ] && [ "$RESTART_COUNT" -ge 1 ]; then
            echo "Error: Pod has been restarted ${RESTART_COUNT} times, indicating issues"
            exit 0
        elif [ "$POD_STATUS" == "Succeeded" ]; then
            echo "Prefill pod completed successfully"
            break
        fi
    fi
    
    echo "Prefill pod status: ${POD_STATUS}, waiting..."
    sleep 30
done

echo "Benchmark run completed!"
echo "Check benchmark_results directory for test results."