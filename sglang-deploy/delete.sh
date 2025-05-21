#!/bin/bash

set -e

NAME=$1

cat deploy_base.yaml|sed "s#{NAME}#${NAME}#g" > .delete_tmp.yaml

kubectl delete -f .delete_tmp.yaml
rm -rf .delete_tmp.yaml
