#!/bin/sh

tailscale status --json | jq -r '.Peer[] | .DNSName + " A " + .TailAddr'
