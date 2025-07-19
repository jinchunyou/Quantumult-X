#!/bin/bash

# GitHub 监控系统重启脚本
# 用于重启前后端服务

echo "🔄 正在重启 GitHub 监控系统..."

# 获取当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否存在 package.json
if [ ! -f "package.json" ]; then
    log_error "未找到 package.json 文件，请确保在项目根目录运行此脚本"
    exit 1
fi

# 停止现有进程
log_info "正在停止现有服务..."

# 查找并停止 npm run dev 进程
DEV_PIDS=$(pgrep -f "npm run dev" 2>/dev/null)
if [ ! -z "$DEV_PIDS" ]; then
    log_info "停止 npm run dev 进程: $DEV_PIDS"
    echo $DEV_PIDS | xargs kill -TERM 2>/dev/null
    sleep 2
    # 强制杀死仍在运行的进程
    echo $DEV_PIDS | xargs kill -KILL 2>/dev/null
fi

# 查找并停止 node 相关进程（端口 3000 和 3001）
NODE_PIDS_3000=$(lsof -ti:3000 2>/dev/null)
NODE_PIDS_3001=$(lsof -ti:3001 2>/dev/null)

if [ ! -z "$NODE_PIDS_3000" ]; then
    log_info "停止端口 3000 上的进程: $NODE_PIDS_3000"
    echo $NODE_PIDS_3000 | xargs kill -TERM 2>/dev/null
    sleep 1
    echo $NODE_PIDS_3000 | xargs kill -KILL 2>/dev/null
fi

if [ ! -z "$NODE_PIDS_3001" ]; then
    log_info "停止端口 3001 上的进程: $NODE_PIDS_3001"
    echo $NODE_PIDS_3001 | xargs kill -TERM 2>/dev/null
    sleep 1
    echo $NODE_PIDS_3001 | xargs kill -KILL 2>/dev/null
fi

# 等待进程完全停止
log_info "等待进程完全停止..."
sleep 3

# 检查依赖是否已安装
log_info "检查依赖安装状态..."

# 检查根目录依赖
if [ ! -d "node_modules" ]; then
    log_warn "根目录缺少 node_modules，正在安装依赖..."
    npm install
fi

# 检查服务端依赖
if [ ! -d "server/node_modules" ]; then
    log_warn "服务端缺少 node_modules，正在安装依赖..."
    cd server && npm install && cd ..
fi

# 检查客户端依赖
if [ ! -d "client/node_modules" ]; then
    log_warn "客户端缺少 node_modules，正在安装依赖..."
    cd client && npm install && cd ..
fi

# 启动服务
log_info "正在启动服务..."

# 启动开发服务器
npm run dev &
DEV_PID=$!

# 等待服务启动
log_info "等待服务启动..."
sleep 5

# 检查服务是否成功启动
check_service() {
    local url=$1
    local name=$2
    
    if curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        log_info "$name 启动成功: $url"
        return 0
    else
        log_error "$name 启动失败: $url"
        return 1
    fi
}

# 检查前端服务 (最多等待 30 秒)
FRONTEND_READY=false
for i in {1..6}; do
    if check_service "http://localhost:3000" "前端服务"; then
        FRONTEND_READY=true
        break
    fi
    log_info "等待前端服务启动... ($i/6)"
    sleep 5
done

# 检查后端服务
BACKEND_READY=false
for i in {1..6}; do
    if check_service "http://localhost:3001/api/status" "后端服务"; then
        BACKEND_READY=true
        break
    fi
    log_info "等待后端服务启动... ($i/6)"
    sleep 5
done

# 输出启动结果
echo ""
echo "=== 🚀 启动结果 ==="
if [ "$FRONTEND_READY" = true ]; then
    log_info "✅ 前端服务: http://localhost:3000"
else
    log_error "❌ 前端服务启动失败"
fi

if [ "$BACKEND_READY" = true ]; then
    log_info "✅ 后端服务: http://localhost:3001"
else
    log_error "❌ 后端服务启动失败"
fi

echo ""
if [ "$FRONTEND_READY" = true ] && [ "$BACKEND_READY" = true ]; then
    log_info "🎉 GitHub 监控系统重启成功！"
    log_info "📱 访问地址: http://localhost:3000"
    echo ""
    echo "💡 提示:"
    echo "   - 使用 Ctrl+C 停止服务"
    echo "   - 查看日志: tail -f server/logs/*.log (如果有日志文件)"
    echo "   - 重新运行此脚本: ./restart.sh"
else
    log_error "❌ 部分服务启动失败，请检查错误信息"
    exit 1
fi

# 保持脚本运行，等待用户中断
log_info "服务正在运行中，按 Ctrl+C 停止..."
wait $DEV_PID