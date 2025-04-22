#!/bin/bash

set -e

NAME=$1
IMAGE=$2
PREFILL_REPLICA=${3:-2}
PREFILL_TP=${4:-16}
PREFILL_DP=${5:-4}
PREFILL_PD_ROLE="prefill"
DECODE_REPLICA=${6:-2}
DECODE_TP=${7:-16}
DECODE_DP=${8:-16}
DECODE_PD_ROLE="decode"


cat deploy_base.yaml|\
	sed "s#{NAME}#${NAME}#g" | \
	sed "s#{IMAGE}#"${IMAGE}"#g" | \
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
