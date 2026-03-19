#!/bin/bash

# Symphony 飞书集成启动脚本

cd "$(dirname "$0")"

# 加载环境变量
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
  echo "✓ 环境变量已加载"
else
  echo "⚠️  警告: .env 文件不存在"
  echo "请先创建 .env 文件并配置飞书信息"
  exit 1
fi

# 检查必需的环境变量
if [ -z "$FEISHU_APP_TOKEN" ] || [ -z "$FEISHU_TABLE_ID" ]; then
  echo "⚠️  警告: FEISHU_APP_TOKEN 或 FEISHU_TABLE_ID 未设置"
  echo "请在 .env 文件中配置这些值"
  exit 1
fi

echo "飞书配置:"
echo "  APP_ID: ${FEISHU_APP_ID}"
echo "  APP_TOKEN: ${FEISHU_APP_TOKEN}"
echo "  TABLE_ID: ${FEISHU_TABLE_ID}"
echo ""

# 停止已运行的服务
pkill -f "symphony.*WORKFLOW" 2>/dev/null
sleep 1

# 启动服务
echo "启动 Symphony 服务..."
./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW_FEISHU_LIFECYCLE.md
