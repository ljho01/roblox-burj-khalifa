#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p dist
rojo build default.project.json --output dist/Build-the-Burj.rbxlx
