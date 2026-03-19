---
tracker:
  kind: feishu
  app_token: $FEISHU_APP_TOKEN
  table_id: $FEISHU_TABLE_ID
  active_states:
    - "\u5f85\u5904\u7406"
    - "\u9700\u6c42\u8bc4\u4f30\u4e2d"
    - "\u8bbe\u8ba1\u4e2d"
    - "\u5f00\u53d1\u4e2d"
    - "\u786e\u8ba4\u4e2d"
  terminal_states:
    - "\u5df2\u5b8c\u6210"
    - "\u5df2\u5173\u95ed"

lifecycle:
  enabled: true
  stages:
    - name: requirement_assessment
      display_name: Requirement Assessment
      agent_type: requirement_agent
      prompt_template: REQUIREMENT_ASSESSMENT.md
      initial_states: ["\u5f85\u5904\u7406"]
      target_states: ["\u9700\u6c42\u8bc4\u4f30\u4e2d"]
      output_states: ["\u5f85\u8bbe\u8ba1\u786e\u8ba4", "\u9700\u6c42\u9700\u8865\u5145"]
      max_turns: 10
      confirmation_required: true

    - name: design_document
      display_name: Design Document
      agent_type: design_agent
      prompt_template: DESIGN_DOCUMENT.md
      initial_states: ["\u5f85\u8bbe\u8ba1\u786e\u8ba4"]
      target_states: ["\u8bbe\u8ba1\u4e2d"]
      output_states: ["\u5f85\u5f00\u53d1", "\u8bbe\u8ba1\u9700\u4fee\u6539"]
      max_turns: 15
      confirmation_required: true

    - name: development
      display_name: Development
      agent_type: development_agent
      prompt_template: DEVELOPMENT.md
      initial_states: ["\u5f85\u5f00\u53d1"]
      target_states: ["\u5f00\u53d1\u4e2d"]
      output_states: ["\u5f85\u4ea7\u7269\u786e\u8ba4", "\u5f00\u53d1\u9700\u4fee\u6539"]
      max_turns: 20
      confirmation_required: false

    - name: artifact_confirmation
      display_name: Artifact Confirmation
      agent_type: confirmation_agent
      prompt_template: ARTIFACT_CONFIRMATION.md
      initial_states: ["\u5f85\u4ea7\u7269\u786e\u8ba4"]
      target_states: ["\u786e\u8ba4\u4e2d"]
      output_states: ["\u5df2\u5b8c\u6210", "\u9700\u4fee\u6539"]
      max_turns: 5
      confirmation_required: true

  confirmation_points:
    - requirement_assessment
    - design_document
    - artifact_confirmation

  stage_transitions:
    "\u5f85\u5904\u7406": requirement_assessment
    "\u9700\u6c42\u8bc4\u4f30\u4e2d": requirement_assessment
    "\u5f85\u8bbe\u8ba1\u786e\u8ba4": design_document
    "\u8bbe\u8ba1\u4e2d": design_document
    "\u5f85\u5f00\u53d1": development
    "\u5f00\u53d1\u4e2d": development
    "\u5f85\u4ea7\u7269\u786e\u8ba4": artifact_confirmation
    "\u786e\u8ba4\u4e2d": artifact_confirmation
    "\u9700\u6c42\u9700\u8865\u5145": requirement_assessment
    "\u8bbe\u8ba1\u9700\u4fee\u6539": design_document
    "\u5f00\u53d1\u9700\u4fee\u6539": development
    "\u9700\u4fee\u6539": artifact_confirmation

polling:
  interval_ms: 30000

workspace:
  root: ~/symphony-workspaces

agent:
  max_concurrent_agents: 2
  max_turns: 20

codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  model: gpt-5.4-mini
  provider: anthropic

server:
  port: 4000
  host: 127.0.0.1
---
