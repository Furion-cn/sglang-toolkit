#!/bin/bash

set -e

NAME=$1
IMAGE=$2

# 默认值设置
PREFILL_REPLICA=${PREFILL_REPLICA:-1}
PREFILL_TP=${PREFILL_TP:-8}
PREFILL_DP=${PREFILL_DP:-1}
DECODE_REPLICA=${DECODE_REPLICA:-1}
DECODE_TP=${DECODE_TP:-8}
DECODE_DP=${DECODE_DP:-1}
MAX_CONCURRENCIES=${MAX_CONCURRENCIES:-1024}
MODEL_PATH=${MODEL_PATH:-"/models/DeepSeek-R1-BF16"}

if [ "$PREFILL_TP" -ge 8 ]; then
    PREFILL_GPU=8
else
    PREFILL_GPU=$PREFILL_TP
fi
if [ "$DECODE_TP" -ge 8 ]; then
	DECODE_GPU=8
else
	DECODE_GPU=$DECODE_TP
fi

# 显示配置信息
echo "使用以下配置:"
echo "PREFILL_REPLICA: $PREFILL_REPLICA"
echo "PREFILL_TP: $PREFILL_TP"
echo "PREFILL_DP: $PREFILL_DP"
echo "DECODE_REPLICA: $DECODE_REPLICA"
echo "DECODE_TP: $DECODE_TP"
echo "DECODE_DP: $DECODE_DP"
echo "MAX_CONCURRENCIES: $MAX_CONCURRENCIES"
echo "PREFILL_GPU: $PREFILL_GPU"
echo "DECODE_GPU: $DECODE_GPU"

if [ -z "$NAME" ] || [ -z "$IMAGE" ]; then
    echo "Usage: $0 <name> <image> [options]"
    exit 1
fi

PREFILL_PD_ROLE="prefill"
DECODE_PD_ROLE="decode"
MINILB_PD_ROLE="minilb"


cat deploy_base.yaml|\
	sed "s#{NAME}#${NAME}#g" | \
	sed "s#{IMAGE}#"${IMAGE}"#g" | \
	sed "s#{MAX_CONCURRENCIES}#${MAX_CONCURRENCIES}#g" | \
	sed "s#{PREFILL_REPLICA}#${PREFILL_REPLICA}#g"|\
	sed "s#{PREFILL_TP}#${PREFILL_TP}#g"|\
	sed "s#{PREFILL_DP}#${PREFILL_DP}#g"|\
	sed "s#{PREFILL_PD_ROLE}#${PREFILL_PD_ROLE}#g"|\
	sed "s#{DECODE_REPLICA}#${DECODE_REPLICA}#g"|\
	sed "s#{DECODE_TP}#${DECODE_TP}#g"|\
	sed "s#{DECODE_DP}#${DECODE_DP}#g"|\
    sed "s#{MINILB_PD_ROLE}#${MINILB_PD_ROLE}#g"|\
	sed "s#{PREFILL_GPU}#${PREFILL_GPU}#g"|\
	sed "s#{DECODE_GPU}#${DECODE_GPU}#g"|\
	sed "s#{MODEL_PATH}#${MODEL_PATH}#g"|\
        sed "s#{DECODE_PD_ROLE}#${DECODE_PD_ROLE}#g" > .deploy_tmp.yaml

kubectl -n inference-system delete pods -l app=${NAME}-prefill --force
kubectl -n inference-system delete pods -l app=${NAME}-decode --force
kubectl -n inference-system delete pods -l app=${NAME}-minilb --force

kubectl apply -f .deploy_tmp.yaml
rm -rf .deploy_tmp.yaml
