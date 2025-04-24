#!/bin/bash

# 设置错误处理
set -e

STATEFULSETS=$(kubectl get statefulset -n inference-system | grep autobench | awk '{print $1}' || true)
if [ ! -z "$STATEFULSETS" ]; then
    echo "Deleting statefulsets: $STATEFULSETS"
    echo "$STATEFULSETS" | xargs kubectl delete statefulset -n inference-system
fi

SERVICES=$(kubectl get service -n inference-system | grep autobench | awk '{print $1}' || true)
if [ ! -z "$SERVICES" ]; then
    echo "Deleting services: $SERVICES"
    echo "$SERVICES" | xargs kubectl delete service -n inference-system
fi

echo "Cleanup completed"
