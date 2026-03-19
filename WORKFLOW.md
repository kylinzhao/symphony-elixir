---
tracker:
  kind: feishu
  app_token: J6NBbj3uEa3wlOsNxedcQWO9nPc
  table_id: tblJyNAWMLG1TanI
  active_states:
    - "\u5f85\u5904\u7406"
    - "\u9700\u6c42\u8bc4\u4f30\u4e2d"
    - "\u5f85\u8bbe\u8ba1\u786e\u8ba4"
    - "\u8bbe\u8ba1\u4e2d"
    - "\u5f85\u5f00\u53d1"
    - "\u5f00\u53d1\u4e2d"
    - "\u5f85\u4ea7\u7269\u786e\u8ba4"
    - "\u786e\u8ba4\u4e2d"
  terminal_states:
    - "\u5df2\u5b8c\u6210"
    - "\u5df2\u5173\u95ed"

lifecycle:
  enabled: true
  stages:
    - name: requirement_assessment
      display_name: "\u9700\u6c42\u8bc4\u4f30"
      initial_states:
        - "\u5f85\u5904\u7406"
      target_states:
        - "\u9700\u6c42\u8bc4\u4f30\u4e2d"
      output_states:
        - "\u5f85\u8bbe\u8ba1\u786e\u8ba4"
      max_turns: 10
    - name: design_document
      display_name: "\u8bbe\u8ba1\u6587\u6863"
      initial_states:
        - "\u5f85\u8bbe\u8ba1\u786e\u8ba4"
      target_states:
        - "\u8bbe\u8ba1\u4e2d"
      output_states:
        - "\u5f85\u5f00\u53d1"
      max_turns: 15
    - name: development
      display_name: "\u5f00\u53d1\u5b9e\u65bd"
      initial_states:
        - "\u5f85\u5f00\u53d1"
      target_states:
        - "\u5f00\u53d1\u4e2d"
      output_states:
        - "\u5f85\u4ea7\u7269\u786e\u8ba4"
      max_turns: 20
    - name: artifact_confirmation
      display_name: "\u4ea7\u7269\u786e\u8ba4"
      initial_states:
        - "\u5f85\u4ea7\u7269\u786e\u8ba4"
      target_states:
        - "\u786e\u8ba4\u4e2d"
      output_states:
        - "\u5df2\u5b8c\u6210"
      max_turns: 5
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

polling:
  interval_ms: 30000

workspace:
  root: ~/symphony-workspaces

agent:
  max_concurrent_agents: 1
  max_turns: 20

codex:
  model: gpt-5.1-codex-mini
  provider: openai
  command: codex app-server -c model="gpt-5.1-codex-mini"
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000
  read_timeout_ms: 300000
  stall_timeout_ms: 300000

server:
  port: 4000
---

# AI Agent Task Execution Guide

## Current Stage: Design Document Phase

Your task is to **complete the technical design document first**, then start coding.

## Workflow

1. **First**, write a detailed technical design document in `docs/design.md`, including:
   - Feature requirement analysis
   - Technology stack selection
   - File structure design
   - API interface definitions (if applicable)
   - Data structure design (if applicable)
   - UI/UX design concepts (if applicable)

2. **After the design document is completed and confirmed**, then start writing code

3. Reference the design document during implementation

## Current Task

**Task ID**: {{ issue.identifier }}
**Title**: {{ issue.title }}
**Description**:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided
{% endif %}

## Important Notes

- **First phase must output design document** `docs/design.md`
- Design document must include complete technical solution
- Use Chinese for output, do not use Superpowers Skills

---
