#!/usr/bin/env bash

# Exit on error
set -e

# Support overriding the game directory
if [ -z "$STS2_GAME_DIR" ]; then
    echo "Searching for Slay the Spire 2 install..."
    
    # Common Steam paths
    case "$(uname)" in
        Darwin)
            # macOS - check both arm64 and x86_64
            BASE_PATH="$HOME/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/SlayTheSpire2.app/Contents/Resources"
            if [ -d "$BASE_PATH/data_sts2_macos_arm64" ]; then
                STS2_GAME_DIR="$BASE_PATH/data_sts2_macos_arm64"
            elif [ -d "$BASE_PATH/data_sts2_macos_x86_64" ]; then
                STS2_GAME_DIR="$BASE_PATH/data_sts2_macos_x86_64"
            fi
            ;;
        Linux)
            # Linux - check common locations
            BASE_PATH="$HOME/.steam/steam/steamapps/common/Slay the Spire 2"
            if [ -d "$BASE_PATH/data_sts2_linuxbsd_x86_64" ]; then
                STS2_GAME_DIR="$BASE_PATH/data_sts2_linuxbsd_x86_64"
            elif [ -d "$BASE_PATH/data" ]; then
                STS2_GAME_DIR="$BASE_PATH/data"
            fi
            ;;
        *)
            # Windows (Git Bash/WSL) - check common C: drive location
            # Note: This is a bit simplified for script, users might need to set STS2_GAME_DIR
            BASE_PATH="/c/Program Files (x86)/Steam/steamapps/common/Slay the Spire 2"
            if [ -d "$BASE_PATH/data" ]; then
                STS2_GAME_DIR="$BASE_PATH/data"
            fi
            ;;
    esac
fi

if [ -z "$STS2_GAME_DIR" ] || [ ! -d "$STS2_GAME_DIR" ]; then
    echo "Error: Could not find Slay the Spire 2 installation."
    echo "Please set the STS2_GAME_DIR environment variable to the 'data' directory containing sts2.dll."
    exit 1
fi

echo "Found game data at: $STS2_GAME_DIR"

# Require release type parameter
if [ $# -lt 1 ]; then
    echo "Usage: $0 <release|beta> [beta-suffix]"
    exit 1
fi
RELEASE_TYPE="$1"
BETA_SUFFIX="$2"
# Detect version from release_info.json (parent dir of data)
RELEASE_INFO="$(dirname "$STS2_GAME_DIR")/release_info.json"
if [ -f "$RELEASE_INFO" ]; then
    GAME_VERSION=$(grep '"version":' "$RELEASE_INFO" | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ "$RELEASE_TYPE" = "beta" ] && [ -n "$BETA_SUFFIX" ]; then
        GAME_VERSION="$GAME_VERSION-beta-$BETA_SUFFIX"
    fi
    echo "Detected Game Version: $GAME_VERSION"
    
    # Update .csproj version
    sed -i '' -E "s|<Version>[^<]+</Version>|<Version>$GAME_VERSION</Version>|" BSchneppe.Sts2.ReferenceAssemblies.csproj
    else
    echo "Warning: release_info.json not found. Version in .csproj will not be updated."
    fi

    # Ensure refasmer is installed
    REFASMER="$HOME/.dotnet/tools/refasmer"
    if [ ! -f "$REFASMER" ]; then
    echo "refasmer not found at $REFASMER. Installing JetBrains.Refasmer.CliTool..."
    , dotnet tool install -g JetBrains.Refasmer.CliTool
    fi

    # DLLs to stub
    DLLS=("sts2.dll" "0Harmony.dll" "GodotSharp.dll")

    # Output directory (relative to project root)
    OUTPUT_DIR="ref/net9.0"
    mkdir -p "$OUTPUT_DIR"

    for dll in "${DLLS[@]}"; do
    INPUT_PATH="$STS2_GAME_DIR/$dll"
    if [ ! -f "$INPUT_PATH" ]; then
        echo "Warning: $dll not found in $STS2_GAME_DIR. Skipping..."
        continue
    fi

    echo "Generating stub for $dll..."
    "$REFASMER" -v --omit-non-api-members true -o "$OUTPUT_DIR/$dll" "$INPUT_PATH"
    done

    echo "Stub generation complete! Files located in $OUTPUT_DIR"

    # Git automation
    if [ -d ".git" ] && [ -n "$GAME_VERSION" ]; then
    echo "Staging changes for version $GAME_VERSION..."
    git add BSchneppe.Sts2.ReferenceAssemblies.csproj "$OUTPUT_DIR"/*.dll
    
    if git diff --cached --quiet; then
        echo "No changes detected in stubs. Skipping commit/tag."
    else
        echo "Committing and tagging version v$GAME_VERSION..."
        git commit -m "Update stubs to game version $GAME_VERSION"
        git tag "v$GAME_VERSION"
        echo "Successfully committed and tagged v$GAME_VERSION."
        echo "Run 'git push origin main --tags' to trigger the NuGet release."
    fi
fi
