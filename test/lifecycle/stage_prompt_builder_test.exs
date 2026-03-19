defmodule SymphonyElixir.Lifecycle.StagePromptBuilderTest do
  use ExUnit.Case

  alias SymphonyElixir.Lifecycle.StagePromptBuilder

  describe "build_stage_prompt/3" do
    test "builds prompt from template file" do
      issue = %{
        identifier: "TEST-1",
        title: "Test Issue",
        description: "Test Description",
        state: "待处理"
      }

      stage = %{
        "name" => "requirement_assessment",
        "display_name" => "需求评估"
      }

      assert {:ok, prompt} = StagePromptBuilder.build_stage_prompt(issue, stage, "REQUIREMENT_ASSESSMENT.md")
      assert is_binary(prompt)
      assert String.contains?(prompt, "需求评估")
    end

    test "returns error for non-existent template" do
      issue = %{identifier: "TEST-1", title: "Test", description: "Test", state: "待处理"}
      stage = %{"name" => "test"}

      assert {:ok, _prompt} = StagePromptBuilder.build_stage_prompt(issue, stage, "NON_EXISTENT.md")
    end
  end

  describe "templates_dir/0" do
    test "returns templates directory path" do
      dir = StagePromptBuilder.templates_dir()
      assert is_binary(dir)
      assert String.contains?(dir, "templates")
    end
  end
end
