#!/bin/bash

set -e

SERVER_NAME=${SERVER_NAME:-"deepseek-r1-server"}
RANK=`hostname|awk -F- '{print $NF}'`
MASTER_ADDR="$SERVER_NAME-sglang.inference-system.svc.cluster.local"
MASTER_PORT=20000
WORLD_SIZE=${WORLD_SIZE:-4}

TP=${TP:-8}
DP=${DP:-1}
EP=${EP:-8}
MODEL_PATH=${MODEL_PATH:-"/models"}
ENABLE_MTP=${ENABLE_MTP:-0}
ENABLE_DEEPEP=${ENABLE_DEEPEP:-0}
MEM_FRACTION_STATIC=${MEM_FRACTION_STATIC:-0}
ATTENTION_BACKEND=${ATTENTION_BACKEND:-"fa3"}
KV_TRANSFER_DEVICE=${KV_TRANSFER_DEVICE:-"mlx5_0"}
COMPILE_OPTS=${COMPILE_OPTS:-"--enable-torch-compile --cuda-graph-max-bs 128 --torch-compile-max-bs 128"}

DISTRIBUTED_ARGS=(
    --tp-size $TP
    --attention-backend ${ATTENTION_BACKEND}
    --trust-remote-code
    --nnodes $WORLD_SIZE
    --node-rank $RANK
    --host 0.0.0.0
    --port 30000
)

if [ "$ENABLE_DEEPEP" -eq 1 ]; then
    DISTRIBUTED_ARGS+=(
      --enable-deepep
    )
fi

DISTRIBUTED_ARGS+=(
  --dist-init-addr $MASTER_ADDR:$MASTER_PORT
)
if [ "$ENABLE_DEEPEP" -eq 1 ]; then
  DISTRIBUTED_ARGS+=(
    --enable-deepep
--deepep-mode low_latency
  )
fi

if [[ "$DP" -gt 1 ]]; then
    DISTRIBUTED_ARGS+=(
      --enable-dp-attention
      --dp-size $DP
    )
fi

if [ "$ENABLE_MTP" -eq 1 ]; then
    MEM_FRACTION_STATIC=0.8
    DISTRIBUTED_ARGS+=(
        --speculative-algorithm EAGLE --speculative-draft-model-path /models/nextn --speculative-num-steps 3 --speculative-eagle-topk 2 --speculative-num-draft-tokens 2 --max-running-requests=512
    )
fi

mkdir -p /models/torch_compile_cache/
export TORCHINDUCTOR_CACHE_DIR=/models/torch_compile_cache/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/sgl-workspace/Mooncake/mooncake-common/etcd/
#export SGLANG_TORCH_COMPILE_MODE=default
python3 -m sglang.launch_server  --model-path=$MODEL_PATH ${DISTRIBUTED_ARGS[@]} --mem-fraction-static ${MEM_FRACTION_STATIC} --enable-metrics ${COMPILE_OPTS}
