#!/bin/bash

# Symphony Elixir Startup Script
#
# Usage:
#   export FEISHU_APP_ID=your_app_id
#   export FEISHU_APP_SECRET=your_app_secret
#   ./start_symphony.sh

if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ]; then
  echo "Error: Please set environment variables:"
  echo "  export FEISHU_APP_ID=your_app_id"
  echo "  export FEISHU_APP_SECRET=your_app_secret"
  exit 1
fi

./bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails --port 4000 WORKFLOW.md "$@"
