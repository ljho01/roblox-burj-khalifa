#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh
python3 scripts/make_test_driver.py "$@"
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio --task RunScript --localPlaceFile "$PWD/dist/Build-the-Burj.rbxlx" --runScriptFile "$PWD/dist/smoke-driver.luau" --outputFile "$PWD/dist/smoke-result.log" --quitAfterExecution > "$PWD/dist/studio-smoke.log" 2>&1
rg 'BURJ_SMOKE_ALL_PASSED|BURJ_SMOKE_FAILED|BURJ_MULTIPLAYER_PASSED|BURJ_MULTIPLAYER_FAILED|BURJ_TEST_RESULT' dist/smoke-result.log dist/studio-smoke.log
rg -q 'BURJ_TEST_RESULT true' dist/smoke-result.log
