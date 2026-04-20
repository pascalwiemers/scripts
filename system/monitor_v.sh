#!/bin/bash

# Check if the tmux session already exists
tmux has-session -t monitoring_h 2>/dev/null

if [ $? != 0 ]; then
  # Start a new tmux session and detach it immediately
  tmux new-session -d -s monitoring_h

  # Split the window vertically (top/bottom)
  tmux split-window -v

  # Start btm in the first pane (pane 0)
  tmux send-keys -t monitoring_h:0.0 'btop' C-m

  # Start nvtop in the second pane (pane 1)
  tmux send-keys -t monitoring_h:0.1 'nvtop' C-m
fi

# Attach the session to the current terminal
tmux attach-session -t monitoring_h
