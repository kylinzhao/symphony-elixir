#!/bin/bash

# Symphony 生命周期自动化 - 快速启动和验证脚本

echo "🚀 Symphony 生命周期自动化 - 快速启动和验证"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 步骤 1: 检查环境
echo -e "${YELLOW}📋 步骤 1: 检查环境${NC}"
echo ""

echo "检查 Elixir 版本..."
if elixir --version | grep -q "Elixir 1\.[18-9]"; then
    echo -e "${GREEN}✓ Elixir 版本正确${NC}"
else
    echo -e "${RED}✗ Elixir 版本不满足要求 (需要 1.18+)${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤 2: 安装依赖
echo -e "${YELLOW}📦 步骤 2: 安装依赖${NC}"
echo ""

mix deps.get
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 依赖安装成功${NC}"
else
    echo -e "${RED}✗ 依赖安装失败${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤 3: 编译项目
echo -e "${YELLOW}🔨 步骤 3: 编译项目${NC}"
echo ""

mix compile
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 编译成功${NC}"
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤 4: 运行测试
echo -e "${YELLOW}🧪 步骤 4: 运行测试${NC}"
echo ""

mix test test/lifecycle/ --no-start
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过${NC}"
else
    echo -e "${RED}✗ 测试失败${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤 5: 启动服务
echo -e "${YELLOW}🚀 步骤 5: 启动服务${NC}"
echo ""

echo "启动命令："
echo ""
echo "  ./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW_TEST.md"
echo ""
echo -e "${YELLOW}请在新的终端窗口中执行上述命令来启动服务${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 步骤 6: 验证说明
echo -e "${YELLOW}✅ 验证步骤${NC}"
echo ""

cat << 'VERIFY'
服务启动后，可以进行以下验证：

1. 检查服务状态：
   curl http://127.0.0.1:4000/api/v1/state

2. 访问 Dashboard：
   在浏览器中打开 http://127.0.0.1:4000/

3. 在 IEx 控制台中测试：

   # 检查生命周期配置
   SymphonyElixir.Config.settings!().lifecycle
   
   # 测试阶段判断
   SymphonyElixir.Lifecycle.StageStateMachine.determine_stage("待处理")
   
   # 测试确认点检查
   SymphonyElixir.Lifecycle.StageStateMachine.requires_confirmation?("requirement_assessment")
   
   # 测试阶段转换
   SymphonyElixir.Lifecycle.StageStateMachine.transition_to_next_stage(
     "test-001",
     "requirement_assessment",
     :approved
   )
VERIFY

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ 环境检查完成！系统已准备就绪。${NC}"
echo ""
echo "详细说明请查看 VERIFICATION_GUIDE.md"
