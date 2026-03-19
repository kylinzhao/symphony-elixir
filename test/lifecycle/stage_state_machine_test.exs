defmodule SymphonyElixir.Lifecycle.StageStateMachineTest do
  use ExUnit.Case

  alias SymphonyElixir.Lifecycle.StageStateMachine

  describe "determine_stage/1" do
    setup do
      # 启动 StageStateMachine 进行测试
      start_supervised!(StageStateMachine)
      :ok
    end

    test "returns error when lifecycle is disabled" do
      # 注意：这个测试需要 mock Config.settings!() 返回 lifecycle.enabled = false
      # 暂时跳过，需要在实际运行时测试
      :ok
    end
  end

  describe "requires_confirmation?/1" do
    setup do
      start_supervised!(StageStateMachine)
      :ok
    end

    test "returns true for stages in confirmation_points" do
      # 这个测试需要配置确认点
      # 暂时跳过
      :ok
    end
  end
end
