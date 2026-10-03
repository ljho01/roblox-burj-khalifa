#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio --task RunScript --localPlaceFile "$PWD/dist/Build-the-Burj.rbxlx" --runScriptFile "$PWD/scripts/preview.studio.luau" --outputFile "$PWD/dist/preview.log" > "$PWD/dist/studio-preview.log" 2>&1
