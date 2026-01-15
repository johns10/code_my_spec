---
description: Generate component implementation from spec using agent task session
allowed-tools: Bash(mix cli *), Read
argument-hint: [ModuleName]
hooks:
  Stop:
    - matcher: "*"
      hooks:
        - type: command
          command: "MIX_ENV=cli mix cli evaluate-agent-task"
---

!`MIX_ENV=cli mix cli start-agent-task -t component_code -m $ARGUMENTS`
