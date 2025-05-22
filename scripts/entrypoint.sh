#!/bin/bash

set -e

SERVER_NAME=${SERVER_NAME:-"deepseek-r1-server"}
RANK=`hostname|awk -F- '{print $NF}'`
MASTER_ADDR="$SERVER_NAME-decode.inference-system.svc.cluster.local"
MASTER_PORT=20000
WORLD_SIZE=${WORLD_SIZE:-4}


TP=${TP:-8}
DP=${DP:-1}
EP=${EP:-8}
MODEL_PATH=${MODEL_PATH:-"/models"}
ENABLE_MTP=${ENABLE_MTP:-0}
ENABLE_DEEPEP=${ENABLE_DEEPEP:-0}
MEM_FRACTION_STATIC=${MEM_FRACTION_STATIC:-0}
ATTENTION_BACKEND=${ATTENTION_BACKEND:-"flashinfer"}
KV_TRANSFER_DEVICE=${KV_TRANSFER_DEVICE:-"mlx5_0"}
COMPILE_OPTS=${COMPILE_OPTS:-"--enable-torch-compile --cuda-graph-max-bs 128 --torch-compile-max-bs 128"}
DISABLE_OVERLAP_SCHEDULE=${DISABLE_OVERLAP_SCHEDULE:-0}
ENABLE_MOE_DENSE_DP=${ENABLE_MOE_DENSE_DP:-0}
DISABLE_RADIX_CACHE=${DISABLE_RADIX_CACHE:-0}

DISTRIBUTED_ARGS=(
    --tp-size $TP
    --attention-backend ${ATTENTION_BACKEND}
    --trust-remote-code
    --nnodes $WORLD_SIZE
    --node-rank $RANK
    --host 0.0.0.0
    --port 30000
)

# if [ "$ENABLE_DEEPEP" -eq 1 ]; then
#     DISTRIBUTED_ARGS+=(
#       --enable-deepep
#     )
# fi

if [ "$PD_ROLE" = "prefill" ];then
   DISTRIBUTED_ARGS+=(
     --disaggregation-mode prefill
     --dist-init-addr "$SERVER_NAME-prefill-0.$SERVER_NAME-prefill.inference-system.svc.cluster.local:$MASTER_PORT"
     --disaggregation-ib-device $KV_TRANSFER_DEVICE
     --disable-cuda-graph
     --chunked-prefill-size -1
   )
   if [ "$ENABLE_DEEPEP" -eq 1 ]; then
      DISTRIBUTED_ARGS+=(
        --deepep-mode normal
        --enable-deepep-moe
      )
   fi
elif [ "$PD_ROLE" = "decode" ];then
   DISTRIBUTED_ARGS+=(
     --disaggregation-mode decode
     --dist-init-addr "$SERVER_NAME-decode-0.$SERVER_NAME-decode.inference-system.svc.cluster.local:$MASTER_PORT"
     --disaggregation-ib-device $KV_TRANSFER_DEVICE
     --chunked-prefill-size -1
   )
   if [ "$ENABLE_DEEPEP" -eq 1 ]; then
      DISTRIBUTED_ARGS+=(
        --enable-deepep-moe
        --deepep-mode low_latency
      )
   fi    
else
   DISTRIBUTED_ARGS+=(
     --dist-init-addr $MASTER_ADDR:$MASTER_PORT
   )
   if [ "$ENABLE_DEEPEP" -eq 1 ]; then
      DISTRIBUTED_ARGS+=(
        --enable-deepep
	      --deepep-mode low_latency
      )
   fi
fi

if [ "$DISABLE_RADIX_CACHE" -eq 1 ]; then
    DISTRIBUTED_ARGS+=(
        --disable-radix-cache
    )
fi

if [ "$DISABLE_OVERLAP_SCHEDULE" -eq 1 ]; then
    DISTRIBUTED_ARGS+=(
        --disable-overlap-schedule
    )
fi

if [[ "$DP" -gt 1 ]]; then
    DISTRIBUTED_ARGS+=(
      --enable-dp-attention
      --dp-size $DP
    )
fi

if [[ "$DP" -gt 1 && "$ENABLE_MOE_DENSE_DP" -eq 1 ]]; then
    DISTRIBUTED_ARGS+=(
        --moe-dense-tp-size 1
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

if [ "$PD_ROLE" = "minilb" ];then
    python3 -m sglang.srt.disaggregation.mini_lb --prefill "http://$SERVER_NAME-prefill-0.$SERVER_NAME-prefill.inference-system.svc.cluster.local:30000" --decode "http://$SERVER_NAME-decode-0.$SERVER_NAME-decode.inference-system.svc.cluster.local:30000" --port 8000 --host 0.0.0.0
else
    python3 -m sglang.launch_server  --model-path=$MODEL_PATH ${DISTRIBUTED_ARGS[@]} --mem-fraction-static ${MEM_FRACTION_STATIC} --enable-metrics ${COMPILE_OPTS}
fi
