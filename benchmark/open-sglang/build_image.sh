#!/bin/bash

set -e

# 设置工作目录
REPO_URL="git@github.com:sgl-project/sglang.git"
BRANCH="main"
TAG="v0.4.5"
IMAGE_PREFIX="sealos.hub:5000/open-sglang"

# 解析命令行参数
USE_MAIN=0
while getopts "m" opt; do
  case $opt in
    m)
      USE_MAIN=1
      ;;
    \?)
      echo "无效的选项: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# 删除已存在的仓库
rm -rf sglang

# 克隆代码
echo "Cloning repository..."
if [ $USE_MAIN -eq 1 ]; then
    echo "使用main分支构建..."
    git clone -b ${BRANCH} ${REPO_URL} sglang
else
    echo "使用tag ${TAG}构建..."
    git clone -b ${TAG} ${REPO_URL} sglang
fi

# 获取最新commit id
cd sglang
# COMMIT_ID=$(git rev-parse --short=6 HEAD)
DATE=$(date +%Y%m%d-%H%M%S)
if [ $USE_MAIN -eq 1 ]; then
    TAG="${BRANCH}-${DATE}-auto"
else
    TAG="${TAG}-auto"
fi
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
rm -rf sglang