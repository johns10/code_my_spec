#!/bin/bash
# Helper script to run tmux integration tests inside tmux
# Usage: ./test_in_tmux.sh test/path/to/test.exs:123

set -e

if [ -n "$TMUX" ]; then
    # Already inside tmux, just run the tests
    mix test "$@" --include tmux_integration
else
    # Not in tmux, create a session and run tests
    tmux new-session -d -s test-run "mix test $* --include tmux_integration" \; attach -t test-run
fi
