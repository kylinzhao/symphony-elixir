---
tracker:
  kind: feishu
  app_token: YOUR_FEISHU_APP_TOKEN
  table_id: YOUR_FEISHU_TABLE_ID
  active_states:
    - pending
    - in_process
  terminal_states:
    - finished
    - closed

polling:
  interval_ms: 30000

workspace:
  root: ~/symphony-workspaces

agent:
  max_concurrent_agents: 3
  max_turns: 20

codex:
  command: codex app-server
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

## Current Task

**Task ID**: {{ issue.identifier }}
**Title**: {{ issue.title }}
**Description**:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided
{% endif %}

---

## Execution Requirements

### Step 1: Generate Task Plan (Required)

Before starting to code, you MUST create a `TASK_PLAN.json` file in the workspace.

**Task Plan Format**:

```json
{
  "version": "1.0",
  "total_tasks": 5,
  "tasks": [
    {
      "id": 1,
      "name": "Create HTML structure",
      "status": "pending",
      "estimated_percentage": 15
    },
    {
      "id": 2,
      "name": "Implement core logic",
      "status": "pending",
      "estimated_percentage": 30
    },
    {
      "id": 3,
      "name": "Add styles and interactions",
      "status": "pending",
      "estimated_percentage": 25
    },
    {
      "id": 4,
      "name": "Testing and debugging",
      "status": "pending",
      "estimated_percentage": 20
    },
    {
      "id": 5,
      "name": "Optimization and documentation",
      "status": "pending",
      "estimated_percentage": 10
    }
  ],
  "created_at": "2026-03-11T13:00:00Z"
}
```

**Requirements**:
- Break down the task into 3-10 sub-tasks
- Each task should have a clear name
- `estimated_percentage` indicates the task's share of total work (should sum to 100)
- Initial status for all tasks should be `"pending"`

### Step 2: Execute Tasks One by One and Update Progress

Follow the task plan and complete tasks sequentially:

**When starting a task**:
1. Update the task's `status` to `"in_progress"` in `TASK_PLAN.json`
2. Add `started_at` timestamp

```json
{
  "id": 1,
  "name": "Create HTML structure",
  "status": "in_progress",
  "started_at": "2026-03-11T13:05:00Z"
}
```

**When completing a task**:
1. Update `status` to `"completed"`
2. Add `completed_at` timestamp

```json
{
  "id": 1,
  "name": "Create HTML structure",
  "status": "completed",
  "started_at": "2026-03-11T13:05:00Z",
  "completed_at": "2026-03-11T13:08:00Z"
}
```

### Step 3: After All Tasks Complete

When all tasks are marked as `"completed"`:
1. Ensure all code is committed
2. Perform final testing
3. System will automatically update task status to `finished`

---

## Progress Marking Example

Add progress comments in your code:

```javascript
// TASK: 1/5 (15%) - Creating HTML structure
<!DOCTYPE html>
<html>
<head>
  <title>Calculator</title>
</head>
<body>
  <!-- Calculator interface -->
</body>
</html>
```

---

## Important Reminders

- **Workspace path**: Current working directory
- **Maximum 20 turns** to complete the entire task
- **Each turn should have clear output**
- **MUST create `TASK_PLAN.json` first**, do not skip directly to coding
- **Update progress in real-time** so the system can track your work
- **Update `TASK_PLAN.json` after completing each task**

---

## Success Criteria

A successful task should include:
1. Complete task plan (`TASK_PLAN.json`)
2. All sub-tasks completed (`status: "completed"`)
3. Runnable code
4. Basic testing or demonstration

---

**Now start executing the task! First, create the `TASK_PLAN.json` file.**
