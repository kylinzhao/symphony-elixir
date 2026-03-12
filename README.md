# Symphony Elixir

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/openai/symphony)
[![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-purple)](https://elixir-lang.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)

> [!WARNING]
> Symphony Elixir is prototype software intended for evaluation only and is presented as-is.
> We recommend implementing your own hardened version based on `SPEC.md`.

## 📖 Overview

Symphony Elixir is an intelligent task orchestration system built with Elixir/OTP that automates software development workflows by integrating with AI coding agents (OpenAI Codex) and project management platforms (Linear, Feishu/Lark).

### ✨ Key Features

- **Multi-Platform Integration**: Supports both Linear and Feishu/Lark as task trackers
- **AI-Powered Development**: Automatically launches OpenAI Codex agents to work on issues
- **Real-time Progress Tracking**: Monitors task progress with TASK_PLAN.json integration
- **State Persistence**: Cross-restart persistence for tokens, runtime, and task progress
- **Live Dashboard**: Phoenix LiveView-based observability dashboard with project preview
- **Intelligent Retry**: Automatic retry mechanism with exponential backoff
- **Workspace Management**: Automatic workspace creation and cleanup per issue
- **Concurrent Execution**: Configurable concurrent agent limits

## 🎯 What's New

### Recent Enhancements

- ✅ **Feishu/Lark Integration**: Full support for Feishu Bitable as task tracker
- ✅ **Progress Monitoring**: Real-time task progress tracking with automatic Feishu sync
- ✅ **State Persistence**: ETS-based storage for tokens, runtime, and progress
- ✅ **Project Preview**: One-click preview and folder access from dashboard
- ✅ **Auto-Completion**: Automatically marks tasks as "finished" when 100% complete

## 📸 Screenshot

![Symphony Elixir screenshot](../.github/media/elixir-screenshot.png)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Symphony Elixir                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────┐  │
│  │   Tracker    │    │ Orchestrator │    │  Dashboard  │  │
│  │  (Linear/    │───▶│   (GenServer) │───▶│ (LiveView)  │  │
│  │   Feishu)    │    │              │    │             │  │
│  └──────────────┘    └───────┬──────┘    └─────────────┘  │
│                              │                              │
│                              ▼                              │
│                     ┌──────────────────┐                    │
│                     │  Agent Runner   │                    │
│                     │  (Codex Client)  │                    │
│                     └────────┬─────────┘                    │
│                              │                              │
│                              ▼                              │
│  ┌──────────────────────────────────────────────────┐      │
│  │              Workspace (per issue)               │      │
│  │  ┌──────────────┐  ┌──────────────┐              │      │
│  │  │ TASK_PLAN.json│  │   Source     │              │      │
│  │  │              │  │   Code       │              │      │
│  │  └──────────────┘  └──────────────┘              │      │
│  └──────────────────────────────────────────────────┘      │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────┐  │
│  │ StateStore   │    │ProgressMonitor│    │ FeishuAdapter│  │
│  │   (ETS)      │───▶│   (GenServer) │───▶│  (Sync)     │  │
│  └──────────────┘    └──────────────┘    └─────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 How It Works

1. **Task Discovery**: Polls tracker (Linear/Feishu) for candidate issues
2. **Workspace Creation**: Creates isolated workspace per issue
3. **Agent Launch**: Starts Codex App Server in workspace
4. **Workflow Execution**: Sends workflow prompt to Codex
5. **Progress Tracking**: Monitors TASK_PLAN.json for progress updates
6. **State Sync**: Persists state and syncs progress to tracker
7. **Auto-Completion**: Marks task as finished when 100% complete
8. **Cleanup**: Removes workspace when issue reaches terminal state

## 📦 Installation

### Prerequisites

- **Elixir**: 1.18+ (recommended using [mise](https://mise.jdx.dev/))
- **Erlang/OTP**: 27+
- **OpenAI Codex**: [Install Codex CLI](https://developers.openai.com/codex/)
- **Tracker Account**: Linear or Feishu/Lark account

### Setup

```bash
# Clone repository
git clone https://github.com/openai/symphony
cd symphony/elixir

# Install dependencies
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
```

## ⚙️ Configuration

Create a `WORKFLOW.md` file in your repository root:

### For Linear

```yaml
---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "your-project-slug"
  active_states:
    - Backlog
    - In Progress
    - Rework
  terminal_states:
    - Done
    - Closed
    - Cancelled

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
```

### For Feishu/Lark

```yaml
---
tracker:
  kind: feishu
  app_token: YOUR_APP_TOKEN
  table_id: YOUR_TABLE_ID
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

server:
  port: 4000
```

## 🏃 Running

```bash
# Set environment variables
export LINEAR_API_KEY=your_linear_api_key
# OR
export FEISHU_APP_ID=your_feishu_app_id
export FEISHU_APP_SECRET=your_feishu_app_secret

# Start Symphony
./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW.md
```

### Optional Flags

- `--port PORT`: Enable Phoenix dashboard on specified port
- `--logs-root DIR`: Custom logs directory (default: `./log`)

## 📊 Web Dashboard

Once started with `--port`, access the dashboard at:

- **Dashboard**: http://127.0.0.1:4000/
- **API**: http://127.0.0.1:4000/api/v1/state

### Dashboard Features

- **Live Status**: Real-time agent status and token usage
- **Progress Tracking**: Task progress with percentage
- **Quick Actions**:
  - 👁️ Preview - Open project in browser
  - 📁 Folder - Open workspace in Finder
- **Rate Limits**: API quota monitoring
- **Retry Queue**: Backoff queue visualization

## 📁 Project Layout

```
lib/
├── symphony_elixir.ex          # Application entry point
├── symphony_elixir/
│   ├── orchestrator.ex         # Core orchestration logic
│   ├── agent_runner.ex         # Codex agent lifecycle
│   ├── state_store.ex          # State persistence (ETS)
│   ├── progress_monitor.ex     # Progress tracking & sync
│   ├── task_plan.ex            # TASK_PLAN.json parser
│   ├── feishu/                 # Feishu integration
│   │   ├── adapter.ex          # Feishu tracker adapter
│   │   └── client.ex          # Feishu API client
│   └── ...
├── symphony_elixir_web/        # Phoenix dashboard
│   ├── live/
│   │   └── dashboard_live.ex  # LiveView dashboard
│   └── controllers/
└── test/                       # ExUnit tests
```

## 🔄 Task Progress Tracking

Symphony supports automatic progress tracking through `TASK_PLAN.json`:

### Task Plan Format

```json
{
  "version": "1.0",
  "total_tasks": 5,
  "tasks": [
    {
      "id": 1,
      "name": "Create HTML structure",
      "status": "completed",
      "estimated_percentage": 15,
      "started_at": "2026-03-11T13:05:00Z",
      "completed_at": "2026-03-11T13:08:00Z"
    },
    {
      "id": 2,
      "name": "Implement core logic",
      "status": "in_progress",
      "estimated_percentage": 30,
      "started_at": "2026-03-11T13:13:00Z"
    }
  ]
}
```

### Progress Sync

- ProgressMonitor checks every 30 seconds
- Updates StateStore with progress
- Syncs to Feishu Bitable automatically
- Marks task as "finished" at 100%

## 🧪 Testing

```bash
# Unit tests
make all

# Full end-to-end test (requires real credentials)
cd elixir
export LINEAR_API_KEY=your_key
make e2e
```

## 🛠️ Development

### Hot Code Reloading

```bash
# In development, code changes take effect without restart
mix compile
# Symphony automatically reloads modules
```

### Adding New Trackers

1. Create adapter in `lib/symphony_elixir/<platform>/adapter.ex`
2. Implement `SymphonyElixir.Tracker` behavior
3. Add configuration schema
4. Update WORKFLOW.md documentation

## ❓ FAQ

### Why Elixir?

Elixir/BEAM/OTP provides:
- **Process Supervision**: Automatic restart and supervision trees
- **Concurrency**: Lightweight processes for parallel agents
- **Hot Reloading**: Update code without stopping agents
- **Fault Tolerance**: Let it crash philosophy with isolation
- **Ecosystem**: Mature libraries and tools

### What's the difference from the original Symphony?

This Elixir implementation adds:
- ✅ Feishu/Lark support
- ✅ Progress tracking with TASK_PLAN.json
- ✅ State persistence across restarts
- ✅ Live dashboard with preview
- ✅ Automatic completion detection
- ✅ Enhanced retry mechanism

### How do I set this up for my project?

1. Copy `WORKFLOW.md` to your repo
2. Configure tracker (Linear/Feishu)
3. Set up environment variables
4. Run Symphony
5. Access dashboard at http://127.0.0.1:4000/

Or use Codex:
```bash
codex
"I want to set up Symphony for my repo at https://github.com/user/repo"
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).

## 🙏 Acknowledgments

- OpenAI for Codex and GPT models
- The Elixir/Erlang community
- Linear and Feishu/Lark teams

---

**Note**: This is experimental software. Use at your own risk.
