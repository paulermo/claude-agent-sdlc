#!/bin/bash
# Test transport: behaves like `ssh {host} {command}` but runs locally. The command runs under dash
# when available (a strict POSIX login shell, as on Debian), else bash; STUB_SHELL overrides.
shift
sh=${STUB_SHELL:-$(command -v dash || echo bash)}
exec "$sh" -c "$*"
