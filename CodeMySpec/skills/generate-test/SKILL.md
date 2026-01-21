---
name: generate-test
description: Generate component tests from spec using agent task session
user-invocable: true
allowed-tools: Bash(mix cli *), Read
argument-hint: [ModuleName]
---

!`MIX_ENV=cli mix cli start-agent-task -e ${CLAUDE_SESSION_ID} -t component_test -m $ARGUMENTS`
