#!/bin/bash

set -e

NAME=$1
IMAGE=$2
REPLICA=${3:-2}
TP=${4:-16}
DP=${5:-1}


cat deploy_base.yaml|\
	sed "s#{NAME}#${NAME}#g" | \
	sed "s#{IMAGE}#"${IMAGE}"#g" | \
	sed "s#{REPLICA}#${REPLICA}#g"|\
	sed "s#{TP}#${TP}#g"|\
	sed "s#{DP}#${DP}#g" > .deploy_tmp.yaml

kubectl -n inference-system delete pods -l app=${NAME}-sglang --force

kubectl apply -f .deploy_tmp.yaml
rm -rf .deploy_tmp.yaml
