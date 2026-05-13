#!/usr/bin/env bash
# Build the Reel Royale Unity engine into a Unity-as-a-Library iOS Xcode project.
#
# Outputs:
#   unity-build/ios/Unity-iPhone.xcodeproj   — the exported Xcode project
#   unity-build/ios/UnityFramework/          — UnityFramework target source
#
# Usage:
#   ./scripts/build-unity-ios.sh             # release build
#   ./scripts/build-unity-ios.sh --dev       # development build (Profiler, log)
#   ./scripts/build-unity-ios.sh --xcode     # also compile UnityFramework.framework via xcodebuild
#
# Exit codes:
#   0  success
#   1  Unity not found
#   2  Unity batch build failed
#   3  xcodebuild step failed (only when --xcode passed)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_PROJECT="$REPO_ROOT/unity-engine"
OUTPUT_DIR="$REPO_ROOT/unity-build/ios"
LOG_FILE="$REPO_ROOT/unity-build/unity-build.log"

DEV_FLAG=""
DO_XCODE=0
for arg in "$@"; do
    case "$arg" in
        --dev) DEV_FLAG="-devBuild" ;;
        --xcode) DO_XCODE=1 ;;
        *) echo "Unknown arg: $arg"; exit 64 ;;
    esac
done

# --- 1. Locate Unity --------------------------------------------------------
#
# Order of resolution:
#   1. $UNITY_PATH env var
#   2. ~/Applications/Unity/Hub/Editor/<version>/Unity.app
#   3. /Applications/Unity/Hub/Editor/<version>/Unity.app
# We prefer the newest Unity 6 LTS we find.

find_unity() {
    if [[ -n "${UNITY_PATH:-}" && -x "$UNITY_PATH" ]]; then
        echo "$UNITY_PATH"
        return 0
    fi
    local roots=(
        "$HOME/Applications/Unity/Hub/Editor"
        "/Applications/Unity/Hub/Editor"
    )
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        # Pick the latest 6.x install.
        local version
        version="$(ls "$root" 2>/dev/null | grep -E '^6\.' | sort -V | tail -1)"
        [[ -z "$version" ]] && continue
        local unity_bin="$root/$version/Unity.app/Contents/MacOS/Unity"
        if [[ -x "$unity_bin" ]]; then
            echo "$unity_bin"
            return 0
        fi
    done
    return 1
}

if ! UNITY_BIN="$(find_unity)"; then
    cat >&2 <<'EOF'
[reel-royale] Could not find Unity 6 Editor.

Install steps:
  1. Download Unity Hub:        https://unity.com/download
  2. In Hub > Installs > Add:   choose Unity 6 LTS (6000.x)
  3. During install, ENABLE:    iOS Build Support module
  4. Re-run this script.

Or set UNITY_PATH manually:
  export UNITY_PATH="/Applications/Unity/Hub/Editor/6000.0.x/Unity.app/Contents/MacOS/Unity"
EOF
    exit 1
fi

echo "[reel-royale] Using Unity: $UNITY_BIN"
echo "[reel-royale] Project:     $UNITY_PROJECT"
echo "[reel-royale] Output:      $OUTPUT_DIR"

mkdir -p "$REPO_ROOT/unity-build"

# --- 2. Run Unity batch build ----------------------------------------------

set +e
"$UNITY_BIN" \
    -batchmode \
    -nographics \
    -projectPath "$UNITY_PROJECT" \
    -executeMethod PokemonGo.Editor.iOSBuildPipeline.BuildForReelRoyale \
    -quit \
    -logFile "$LOG_FILE" \
    ${DEV_FLAG:+$DEV_FLAG}
UNITY_EXIT=$?
set -e

if [[ $UNITY_EXIT -ne 0 ]]; then
    echo "[reel-royale] Unity batch build failed (exit $UNITY_EXIT)." >&2
    echo "[reel-royale] Tail of log ($LOG_FILE):" >&2
    tail -n 60 "$LOG_FILE" >&2 || true
    exit 2
fi

if [[ ! -d "$OUTPUT_DIR/Unity-iPhone.xcodeproj" ]]; then
    echo "[reel-royale] Unity reported success but no Xcode project at $OUTPUT_DIR." >&2
    echo "[reel-royale] Tail of log ($LOG_FILE):" >&2
    tail -n 60 "$LOG_FILE" >&2 || true
    exit 2
fi

echo "[reel-royale] Unity export complete: $OUTPUT_DIR/Unity-iPhone.xcodeproj"

# --- 3. Optionally build UnityFramework.framework via xcodebuild -----------

if [[ $DO_XCODE -eq 1 ]]; then
    echo "[reel-royale] Compiling UnityFramework via xcodebuild..."
    DERIVED="$REPO_ROOT/unity-build/derived"
    rm -rf "$DERIVED"
    if ! xcodebuild \
        -project "$OUTPUT_DIR/Unity-iPhone.xcodeproj" \
        -target UnityFramework \
        -configuration Release \
        -sdk iphonesimulator \
        -derivedDataPath "$DERIVED" \
        ONLY_ACTIVE_ARCH=NO \
        build 2>&1 | tail -40; then
        echo "[reel-royale] xcodebuild failed for UnityFramework." >&2
        exit 3
    fi
    FRAMEWORK_OUT="$DERIVED/Build/Products/Release-iphonesimulator/UnityFramework.framework"
    if [[ ! -d "$FRAMEWORK_OUT" ]]; then
        echo "[reel-royale] UnityFramework.framework not produced where expected." >&2
        exit 3
    fi
    DEST="$REPO_ROOT/Frameworks/UnityFramework.framework"
    rm -rf "$DEST"
    mkdir -p "$(dirname "$DEST")"
    cp -R "$FRAMEWORK_OUT" "$DEST"
    echo "[reel-royale] Copied UnityFramework.framework → $DEST"
fi

echo "[reel-royale] Done."
