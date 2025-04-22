#!/usr/bin/env python3
import subprocess
import time
import datetime
import sys
import os
import socket
import signal
import requests

def run_command(cmd):
    """运行命令并返回输出"""
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()

def wait_for_service_ready():
    """等待服务就绪"""
    start_time = time.time()
    timeout = 600  # 10分钟超时
    health_url = "http://localhost:30000/health"
    
    while True:
        # 检查是否超时
        if time.time() - start_time > timeout:
            print("等待服务就绪超时(10分钟)")
            return False
            
        try:
            response = requests.get(health_url, timeout=5)
            if response.status_code == 200:
                print("服务已就绪!")
                return True
        except Exception as e:
            print(f"服务未就绪: {str(e)}")
        
        print("等待服务就绪中...")
        time.sleep(10)

def run_benchmark(server_name):
    """运行基准测试并收集结果"""
    benchmark_cmd = "bash sglang-ci/scripts/benchmark.sh"
    print(f"Running benchmark: {benchmark_cmd}")
    returncode, stdout, stderr = run_command(benchmark_cmd)
    
    # 保存结果
    date_str = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    results_dir = "/data/benchmark/results"
    os.makedirs(results_dir, exist_ok=True)
    result_file = f"{results_dir}/benchmark_result_{server_name}_{date_str}.txt"
    
    with open(result_file, 'w') as f:
        f.write(f"Server Name: {server_name}\n")
        f.write(f"Timestamp: {date_str}\n")
        f.write(f"Pod: {socket.gethostname()}\n")
        f.write("=== Benchmark Results ===\n")
        f.write(stdout)
        if stderr:
            f.write("\n=== Errors ===\n")
            f.write(stderr)
    
    print(f"Results saved to {result_file}")

    # 发送消息到飞书机器人
    feishu_webhook = "https://open.feishu.cn/open-apis/bot/v2/hook/b0016b3c-4f7e-456a-8257-e8372ad74326"
    message = {
        "msg_type": "text",
        "content": {
            "text": f"基准测试完成\n服务器: {server_name}\n时间: {date_str}\n结果文件: {result_file}\n\n测试结果:\n{stdout}"
        }
    }
    try:
        response = requests.post(feishu_webhook, json=message)
        if response.status_code == 200:
            print("飞书消息发送成功")
        else:
            print(f"飞书消息发送失败: {response.status_code}")
    except Exception as e:
        print(f"飞书消息发送异常: {str(e)}")

    return returncode == 0

def run_service(timeout_hours=1):
    """运行服务一段时间后自动退出"""
    def timeout_handler(signum, frame):
        print(f"Service timeout after {timeout_hours} hour(s), exiting...")
        sys.exit(0)
    
    # 设置定时器
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(int(timeout_hours * 3600))  # 转换小时为秒
    
    # 运行服务
    print(f"Starting service, will exit after {timeout_hours} hour(s)")
    process = subprocess.Popen("/scripts/entrypoint.sh", shell=True, stdout=sys.stdout, stderr=sys.stderr)
    return process.wait() == 0

def main():
    server_name = os.environ.get("SERVER_NAME")
    hostname = os.environ.get("HOSTNAME")
    
    print(f"Starting autobench for server: {server_name}")
    print(f"Current pod: {hostname}")
    
    if hostname == f"{server_name}-prefill-0":
        print("Running as primary benchmark pod")
        # 1. 启动服务
        service_process = subprocess.Popen("/scripts/entrypoint.sh", shell=True)
        
        # 2. 等待服务就绪
        if not wait_for_service_ready():
            print("Failed to get service ready")
            service_process.terminate()
            sys.exit(1)
        
        # 3. 运行benchmark
        if not run_benchmark(server_name):
            print("Benchmark failed")
            service_process.terminate()
            sys.exit(1)
        
        # 4. 完成后退出
        print("Benchmark completed successfully")
        service_process.terminate()
        sys.exit(0)
    else:
        print("Running as service pod")
        # 运行服务并设置超时
        if not run_service(timeout_hours=1):
            print("Service failed")
            sys.exit(1)

if __name__ == "__main__":
    main()
