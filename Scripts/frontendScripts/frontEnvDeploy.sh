#!/usr/bin/env bash
set -euo pipefail

# Make sure our required dependencies are installed
sudo apt-get update -qq
sudo apt-get install -y -qq python3.11 python3-pip python3.11-venv git tmux > /dev/null