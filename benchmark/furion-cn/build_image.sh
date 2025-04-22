#!/bin/bash

set -e

# 设置工作目录
REPO_URL="https://github.com/Furion-cn/sglang.git"
BRANCH="main"
IMAGE_PREFIX="sealos.hub:5000/furion-sglang"

# # 获取脚本所在目录的绝对路径
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 克隆或更新代码
if [ -d "sglang" ]; then
    echo "Updating existing repository..."
    cd sglang
    git fetch origin
    git checkout ${BRANCH}
    git pull origin ${BRANCH}
    cd ..
else
    echo "Cloning repository..."
    git clone -b ${BRANCH} ${REPO_URL} sglang
fi

# 获取最新commit id
cd sglang
COMMIT_ID=$(git rev-parse --short=6 HEAD)
DATE=$(date +%Y%m%d-%H%M%S)
TAG="${DATE}-${COMMIT_ID}-auto"
FULL_IMAGE_NAME="${IMAGE_PREFIX}:${TAG}"
cd ..

echo "Building image: ${FULL_IMAGE_NAME}"

# # 复制必要的文件到构建目录
# cp -r ${SCRIPT_DIR}/autobench.py .
# mkdir -p scripts
# cp -r ${SCRIPT_DIR}/scripts/* scripts/

# 构建镜像
docker build -t ${FULL_IMAGE_NAME} -f Dockerfile .

# 推送镜像
echo "Pushing image to registry..."
docker push ${FULL_IMAGE_NAME}

# 输出镜像信息到文件
echo "Writing image info to file..."
echo "FURION_SGLANG_IMAGE=${FULL_IMAGE_NAME}" > image_info_${TAG}.txt

echo "Build completed successfully!"
echo "Image: ${FULL_IMAGE_NAME}"
echo "Image info saved to: image_info_${TAG}.txt"

# 清理工作目录（可选，取消注释以启用）
# cd ../..
# rm -rf ${WORK_DIR} 