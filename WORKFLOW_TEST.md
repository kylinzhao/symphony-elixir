---
tracker:
  kind: memory
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

lifecycle:
  enabled: true
  stages:
    - name: requirement_assessment
      display_name: Requirement Assessment
      agent_type: requirement_agent
      prompt_template: REQUIREMENT_ASSESSMENT.md
      initial_states: [pending]
      target_states: [in_progress]
      output_states: [design_ready, need_info]
      max_turns: 10
      confirmation_required: true

    - name: design_document
      display_name: Design Document
      agent_type: design_agent
      prompt_template: DESIGN_DOCUMENT.md
      initial_states: [design_ready]
      target_states: [in_progress]
      output_states: [dev_ready, design_revise]
      max_turns: 15
      confirmation_required: true

    - name: development
      display_name: Development
      agent_type: development_agent
      prompt_template: DEVELOPMENT.md
      initial_states: [dev_ready]
      target_states: [in_progress]
      output_states: [artifact_ready, dev_revise]
      max_turns: 20
      confirmation_required: false

    - name: artifact_confirmation
      display_name: Artifact Confirmation
      agent_type: confirmation_agent
      prompt_template: ARTIFACT_CONFIRMATION.md
      initial_states: [artifact_ready]
      target_states: [in_progress]
      output_states: [completed, need_fix]
      max_turns: 5
      confirmation_required: true

  confirmation_points:
    - requirement_assessment
    - design_document
    - artifact_confirmation

  stage_transitions:
    pending: requirement_assessment
    in_progress: requirement_assessment
    design_ready: design_document
    dev_ready: development
    artifact_ready: artifact_confirmation

agent:
  max_concurrent_agents: 5
  max_turns: 20

codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write

server:
  port: 4000
---
Symphony lifecycle automation test
