#!/bin/bash
# Test transport: behaves like `ssh {host} {command}` but runs locally.
shift
exec bash -c "$*"
