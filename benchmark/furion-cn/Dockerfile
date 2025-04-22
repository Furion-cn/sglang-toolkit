FROM ccr.ccs.tencentyun.com/furion/sglang:v0.2.0 

ARG HTTP_PROXY
ARG HTTPS_PROXY

COPY sglang sglang
COPY scripts /scripts
COPY autobench.py /scripts/autobench.py

ENV PYTHONPATH /sgl-workspace/Mooncake/build/mooncake-integration/
ENV LD_LIBRARY_PATH /usr/local/cuda/compat/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/sgl-workspace/Mooncake/build/mooncake-common/etcd/

RUN cd sglang && pip install -e "python[all]" --find-links https://flashinfer.ai/whl/cu124/torch2.5/flashinfer-python -i https://mirrors.aliyun.com/pypi/simple

# 确保脚本有执行权限
RUN chmod +x /scripts/autobench.py

# 修改入口点为 autobench.py
ENTRYPOINT ["python3", "/scripts/autobench.py"]
