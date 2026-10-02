#!/bin/bash
set -euo pipefail
unity_editor=${UNITY_EDITOR:-/Applications/Unity/Hub/Editor/6000.3.25f1/Unity.app/Contents/MacOS/Unity}
unity_project=$(cd "$(dirname "$0")/.." && pwd)
verification_dir=${SCROLL_SEEKER_RESULTS:-"$unity_project/TestResults"}
mkdir -p "$verification_dir"
"$unity_editor" -batchmode -nographics -projectPath "$unity_project" -executeMethod ScrollSeeker.Editor.ProjectBuilder.Prepare -quit -logFile "$verification_dir/prepare.log"
"$unity_editor" -batchmode -nographics -projectPath "$unity_project" -runTests -testPlatform EditMode -testResults "$verification_dir/editmode.xml" -logFile "$verification_dir/editmode.log"
"$unity_editor" -batchmode -nographics -projectPath "$unity_project" -runTests -testPlatform PlayMode -testResults "$verification_dir/playmode.xml" -logFile "$verification_dir/playmode.log"
"$unity_editor" -batchmode -projectPath "$unity_project" -executeMethod ScrollSeeker.Editor.ProjectBuilder.BuildMac -quit -logFile "$verification_dir/build.log"
