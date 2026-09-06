#!/bin/bash

wget -qO- https://github.com | tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null

chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://github.com stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install gh -y
