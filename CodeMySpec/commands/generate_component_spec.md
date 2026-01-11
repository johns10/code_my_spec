---
description: Generate a component specification using agent task session
allowed-tools: Bash(CodeMySpec/scripts/*), Read
argument-hint: [ModuleName]
hooks:
  Stop:
    - matcher: "*"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/evaluate_agent_task.sh"
---

!`CodeMySpec/scripts/start_agent_task.sh component_spec $ARGUMENTS`
