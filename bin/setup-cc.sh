#!/bin/bash

NPM_PACKAGES="${HOME}/.npm-packages"

mkdir -p "${NPM_PACKAGES}"
npm config set prefix "${NPM_PACKAGES}"

PATH="${NPM_PACKAGES}/bin:${PATH}"

npm install -g @anthropic-ai/claude-code


claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $(<~/.github_pat)"

#claude mcp add --transport sse linear https://mcp.linear.app/sse
#claude mcp add --transport http figma-dev-mode-mcp-server http://127.0.0.1:3845/mcp



