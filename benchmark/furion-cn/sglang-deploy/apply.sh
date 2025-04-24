#!/bin/bash

set -e

NAME=$1
IMAGE=$2

# 默认值设置
PREFILL_REPLICA=2
PREFILL_TP=16
PREFILL_DP=4
DECODE_REPLICA=2
DECODE_TP=16
DECODE_DP=16
MAX_CONCURRENCIES=1024

# 解析命令行参数
while getopts "pr:pt:pd:dr:dt:dd:mc:h" opt; do
    case $opt in
        pr) PREFILL_REPLICA="$OPTARG";;
        pt) PREFILL_TP="$OPTARG";;
        pd) PREFILL_DP="$OPTARG";;
        dr) DECODE_REPLICA="$OPTARG";;
        dt) DECODE_TP="$OPTARG";;
        dd) DECODE_DP="$OPTARG";;
        mc) MAX_CONCURRENCIES="$OPTARG";;
        h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -pr PREFILL_REPLICA  设置预填充副本数 (默认: 2)"
            echo "  -pt PREFILL_TP       设置预填充TP值 (默认: 16)"
            echo "  -pd PREFILL_DP       设置预填充DP值 (默认: 4)"
            echo "  -dr DECODE_REPLICA   设置解码副本数 (默认: 2)"
            echo "  -dt DECODE_TP        设置解码TP值 (默认: 16)"
            echo "  -dd DECODE_DP        设置解码DP值 (默认: 16)"
            echo "  -mc  MAX_CONCURRENCIES 设置最大并发数 (默认: 1024)"
            echo "  -h                   显示帮助信息"
            exit 0
            ;;
        \?)
            echo "无效的选项: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "选项 -$OPTARG 需要参数." >&2
            exit 1
            ;;
    esac
done

# 显示配置信息
echo "使用以下配置:"
echo "PREFILL_REPLICA: $PREFILL_REPLICA"
echo "PREFILL_TP: $PREFILL_TP"
echo "PREFILL_DP: $PREFILL_DP"
echo "DECODE_REPLICA: $DECODE_REPLICA"
echo "DECODE_TP: $DECODE_TP"
echo "DECODE_DP: $DECODE_DP"
echo "MAX_CONCURRENCIES: $MAX_CONCURRENCIES"

if [ -z "$NAME" ] || [ -z "$IMAGE" ]; then
    echo "Usage: $0 <name> <image> [options]"
    exit 1
fi

PREFILL_PD_ROLE="prefill"
DECODE_PD_ROLE="decode"


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
        sed "s#{DECODE_PD_ROLE}#${DECODE_PD_ROLE}#g" > .deploy_tmp.yaml

kubectl -n inference-system delete pods -l app=${NAME}-prefill --force
kubectl -n inference-system delete pods -l app=${NAME}-decode --force

kubectl apply -f .deploy_tmp.yaml
rm -rf .deploy_tmp.yaml
