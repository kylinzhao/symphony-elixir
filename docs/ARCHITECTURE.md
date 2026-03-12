# Symphony Elixir Architecture

## 📐 System Architecture

Symphony Elixir is built on the Elixir/OTP platform, leveraging its powerful concurrency model, fault tolerance, and supervision trees to create a reliable task orchestration system.

## 🏛️ Core Components

### 1. Orchestrator (GenServer)

**Location**: `lib/symphony_elixir/orchestrator.ex`

**Responsibilities**:
- Manages the lifecycle of all agents
- Polls tracker for candidate issues
- Dispatches issues to available agent slots
- Implements retry logic with exponential backoff
- Maintains system state snapshot

**Key Functions**:
- `snapshot/2`: Returns current system state (agents, tokens, rate limits)
- `dispatch_issue/2`: Starts a new agent for an issue
- `choose_issues/3`: Selects which issues to work on
- `revalidate_issue_for_dispatch/2`: Rechecks issue state before dispatch

**State**:
```elixir
%{
  running: %{issue_id => metadata},      # Active agent sessions
  retry_attempts: %{issue_id => attempt}, # Issues in backoff
  claimed: MapSet,                        # Claimed issue IDs
  codex_totals: %{...},                  # Token usage stats
  config: %{...},                        # Current workflow config
}
```

### 2. Agent Runner

**Location**: `lib/symphony_elixir/agent_runner.ex`

**Responsibilities**:
- Spawns and manages Codex App Server processes
- Handles Codex session lifecycle
- Manages workspace isolation
- Implements turn timeout and stall detection
- Cleans up on agent completion

**Process Tree**:
```
Orchestrator (GenServer)
  └─ Agent Runner (Task)
      └─ Codex App Server (Port)
          └─ Workspace (File System)
```

### 3. StateStore (GenServer)

**Location**: `lib/symphony_elixir/state_store.ex`

**Responsibilities**:
- Persists state across restarts using ETS
- Stores global token statistics
- Stores per-issue progress
- Provides fast concurrent read access

**ETS Tables**:
```elixir
:symphony_state_store
  ├── {:global_tokens, %{input, output, total}}
  ├── {:global_runtime, seconds}
  ├── {:issue_stats, issue_id, stats}
  └── {:task_progress, issue_id, progress}
```

**API**:
- `get_global_tokens/0`: Retrieve token usage
- `update_global_tokens/3`: Increment token counters
- `get_task_progress/1`: Get issue progress
- `update_task_progress/2`: Update issue progress

### 4. ProgressMonitor (GenServer)

**Location**: `lib/symphony_elixir/progress_monitor.ex`

**Responsibilities**:
- Scans workspaces for TASK_PLAN.json files
- Calculates task completion percentage
- Syncs progress to Feishu Bitable
- Auto-marks tasks as "finished" at 100%

**Check Interval**: 30 seconds

**Flow**:
```
ProgressMonitor (every 30s)
  ├── Scan workspaces
  ├── Parse TASK_PLAN.json
  ├── Calculate percentage
  ├── Update StateStore
  └── Sync to Feishu
      ├── Update "进度" field
      └── Update "状态" to "finished" if 100%
```

### 5. TaskPlan Module

**Location**: `lib/symphony_elixir/task_plan.ex`

**Responsibilities**:
- Parses TASK_PLAN.json format
- Validates task structure
- Calculates completion percentage
- Identifies current task

**TASK_PLAN.json Format**:
```json
{
  "version": "1.0",
  "total_tasks": 5,
  "tasks": [
    {
      "id": 1,
      "name": "Task name",
      "status": "pending|in_progress|completed",
      "estimated_percentage": 20,
      "started_at": "ISO8601",
      "completed_at": "ISO8601"
    }
  ]
}
```

### 6. Feishu Adapter

**Location**: `lib/symphony_elixir/feishu/adapter.ex`

**Responsibilities**:
- Implements SymphonyElixir.Tracker behavior
- Fetches candidate issues from Feishu Bitable
- Updates issue progress and status
- Manages Feishu API authentication

**Key Functions**:
- `fetch_candidate_issues/1`: Get issues by state
- `update_issue_progress/3`: Update progress percentage
- `fetch_issues_by_states/2`: Batch fetch by states

### 7. Feishu Client

**Location**: `lib/symphony_elixir/feishu/client.ex`

**Responsibilities**:
- Low-level Feishu API calls
- Token management and refresh
- Request/response handling
- Error handling and retry

**API Endpoints**:
- `GET /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records`
- `POST /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records/{record_id}`
- `POST /open-apis/auth/v3/tenant_access_token/internal`

### 8. Web Dashboard (Phoenix LiveView)

**Location**: `lib/symphony_elixir_web/live/dashboard_live.ex`

**Responsibilities**:
- Real-time system observability
- Agent status display
- Token usage tracking
- Quick actions (Preview, Folder)
- Rate limit monitoring

**Routes**:
- `GET /`: Dashboard UI
- `GET /api/v1/state`: System state JSON
- `GET /api/v1/:issue_identifier`: Issue details
- `POST /api/v1/refresh`: Trigger state refresh

## 🔄 Data Flow

### Task Lifecycle

```
┌─────────────────┐
│  Feishu Bitable │
│   (pending)     │
└────────┬────────┘
         │
         │ 1. Poll
         ▼
┌─────────────────┐
│  Orchestrator   │
│                 │
│ • Choose issue  │
│ • Validate      │
└────────┬────────┘
         │
         │ 2. Dispatch
         ▼
┌─────────────────┐
│  Agent Runner   │
│                 │
│ • Create workspace
│ • Start Codex   │
└────────┬────────┘
         │
         │ 3. Execute
         ▼
┌─────────────────┐
│  Codex Agent    │
│                 │
│ • Generate code │
│ • Update TASK_PLAN
│ • Complete work │
└────────┬────────┘
         │
         │ 4. Monitor
         ▼
┌─────────────────┐
│ ProgressMonitor │
│                 │
│ • Check progress│
│ • Update StateStore
│ • Sync to Feishu│
└────────┬────────┘
         │
         │ 5. Complete
         ▼
┌─────────────────┐
│  Feishu Bitable │
│   (finished)    │
└─────────────────┘
```

### State Persistence Flow

```
Agent Execution
    │
    ├──► Token Usage ──► StateStore.update_global_tokens/3
    │                        └──► ETS table: {:global_tokens, ...}
    │
    ├──► Task Progress ─► TaskPlan.get_progress_summary/1
    │                        └──► Calculate percentage
    │                        └──► StateStore.update_task_progress/2
    │                        └──► ETS table: {:task_progress, issue_id, ...}
    │
    └──► Feishu Sync ──► FeishuAdapter.update_issue_progress/3
                            └──► Update "进度" field
                            └──► Update "状态" to "finished" (if 100%)
```

## 🔐 Security Model

### Credential Management

- **Environment Variables**: All credentials via env vars
- **No Hardcoded Secrets**: Never commit API keys
- **Token Refresh**: Automatic Feishu token refresh

### Isolation

- **Workspace Isolation**: Each issue in separate directory
- **Process Isolation**: Separate Codex App Server per agent
- **Sandbox Policies**: Configurable Codex sandbox

### Audit Trail

- **Token Accounting**: Track all token usage
- **Session Logging**: Log Codex session events
- **Error Tracking**: Store retry errors

## 🚀 Scalability

### Concurrency

- **Max Concurrent Agents**: Configurable (default: 3)
- **Per-Agent Turn Limit**: Prevents infinite loops
- **Timeout Protection**: Turn, stall, and read timeouts

### Resource Limits

- **Memory**: ETS in-memory storage
- **Disk**: Workspace per issue (cleanup on terminal)
- **Network**: Connection pooling and timeouts

## 🔄 Supervision Tree

```
SymphonyElixir.Supervisor
├── SymphonyElixir.PubSub (Phoenix.PubSub)
├── SymphonyElixir.TaskSupervisor (Task.Supervisor)
├── SymphonyElixir.WorkflowStore
├── SymphonyElixir.StateStore (GenServer)
├── SymphonyElixir.ProgressMonitor (GenServer)
├── SymphonyElixir.Orchestrator (GenServer)
│   └── SymphonyElixir.AgentRunnerSupervisor
│       └── Agent Runner Tasks
│           └── Codex App Server Processes
├── SymphonyElixir.HttpServer
│   └── SymphonyElixirWeb.Endpoint
│       ├── SymphonyElixirWeb.DashboardLive
│       └── SymphonyElixirWeb.ObservabilityApiController
└── SymphonyElixir.StatusDashboard (GenServer)
```

## 📊 Monitoring

### Metrics Collected

- **Agent Status**: Running, queued, retrying
- **Token Usage**: Input, output, total per agent
- **Runtime**: Agent uptime
- **Rate Limits**: Codex API quota
- **Progress**: Task completion percentage

### Dashboard Features

- **Live Updates**: Phoenix LiveView real-time updates
- **Quick Actions**: Preview, folder access
- **Visual Indicators**: Status badges, progress bars
- **JSON API**: Programmatic access

## 🛠️ Extension Points

### Adding New Trackers

1. Implement `SymphonyElixir.Tracker` behavior
2. Add configuration schema
3. Implement required callbacks:
   - `fetch_candidate_issues/1`
   - `fetch_issues_by_states/2`
   - `update_issue_progress/3`

### Adding Webhooks

1. Extend adapter with webhook client
2. Add webhook configuration
3. Call webhook on state transitions

### Custom Progress Formats

1. Extend `TaskPlan` module
2. Add parser for custom format
3. Update ProgressMonitor to use new parser

## 🔧 Configuration Schema

See `lib/symphony_elixir/config/schema.ex` for full configuration schema.

**Key Sections**:
- `tracker`: Platform integration config
- `workspace`: File system paths
- `agent`: Concurrency and limits
- `codex`: AI agent configuration
- `server`: HTTP server config
- `polling`: Poll intervals

## 📝 Error Handling

### Retry Strategy

- **Exponential Backoff**: Base 2, max 10 attempts
- **Jitter**: Random delay to prevent thundering herd
- **Max Backoff**: 32 minutes

### Error Categories

- **Transient Errors**: Retry (network, API rate limits)
- **Permanent Errors**: Fail fast (invalid config, auth)
- **Agent Errors**: Retry with backoff

## 🚦 Fail-Safe Mechanisms

1. **Process Supervision**: Automatic restart on crash
2. **Circuit Breaker**: Stop polling on repeated failures
3. **Timeout Protection**: All operations have timeouts
4. **State Validation**: Validate all external data
5. **Graceful Degradation**: Continue on non-critical failures

---

**Last Updated**: 2026-03-12
