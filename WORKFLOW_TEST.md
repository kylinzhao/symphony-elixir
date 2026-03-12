---
tracker:
  kind: feishu
  app_token: YOUR_FEISHU_APP_TOKEN
  table_id: YOUR_FEISHU_TABLE_ID
  active_states:
    - pending
    - in_progress
  terminal_states:
    - completed
    - closed

polling:
  interval_ms: 30000

workspace:
  root: ~/symphony-workspaces

agent:
  max_concurrent_agents: 1
  max_turns: 20

codex:
  command: claude
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000
  read_timeout_ms: 5000
  stall_timeout_ms: 300000

server:
  port: 4000
---
