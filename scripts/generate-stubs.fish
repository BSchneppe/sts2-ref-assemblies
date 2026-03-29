#!/usr/bin/env fish

# Function to detect the game directory
function detect_game_dir
    if set -q STS2_GAME_DIR
        if test -d "$STS2_GAME_DIR"
            echo "$STS2_GAME_DIR"
            return 0
        end
    end

    set -l home_dir "$HOME"
    set -l steam_common "$home_dir/Library/Application Support/Steam/steamapps/common"
    
    switch (uname)
        case Darwin
            set -l base "$steam_common/Slay the Spire 2/SlayTheSpire2.app/Contents/Resources"
            if test -d "$base/data_sts2_macos_arm64"
                echo "$base/data_sts2_macos_arm64"
                return 0
            else if test -d "$base/data_sts2_macos_x86_64"
                echo "$base/data_sts2_macos_x86_64"
                return 0
            end
        case Linux
            set -l base "$home_dir/.steam/steam/steamapps/common/Slay the Spire 2"
            if test -d "$base/data_sts2_linuxbsd_x86_64"
                echo "$base/data_sts2_linuxbsd_x86_64"
                return 0
            else if test -d "$base/data"
                echo "$base/data"
                return 0
            end
        case '*'
            set -l base "/c/Program Files (x86)/Steam/steamapps/common/Slay the Spire 2"
            if test -d "$base/data"
                echo "$base/data"
                return 0
            end
    end

    return 1
end

# Main execution
set -l game_dir (detect_game_dir)
if test $status -ne 0
    echo "Error: Could not find Slay the Spire 2 installation."
    echo "Please set the STS2_GAME_DIR environment variable to the 'data' directory."
    exit 1
end

set -gx STS2_GAME_DIR "$game_dir"
echo "Found game data at: $STS2_GAME_DIR"

# Detect version from release_info.json (parent dir of data)
set -l release_info (dirname "$STS2_GAME_DIR")/release_info.json
set -l game_version ""

if test -f "$release_info"
    set game_version (grep '"version":' "$release_info" | sed -E 's/.*"v([^"]+)".*/\1/')
    echo "Detected Game Version: $game_version"
    
    # Update .csproj version
    set -l csproj "BSchneppe.Sts2.ReferenceAssemblies/BSchneppe.Sts2.ReferenceAssemblies.csproj"
    if test -f "$csproj"
        sed -i '' -E "s|<Version>[^<]+</Version>|<Version>$game_version</Version>|" "$csproj"
        echo "Updated $csproj to version $game_version"
    end
else
    echo "Warning: release_info.json not found. Version in .csproj will not be updated."
end

# Ensure refasmer is installed
set -l refasmer_path "$HOME/.dotnet/tools/refasmer"
if not test -f "$refasmer_path"
    echo "refasmer not found at $refasmer_path. Installing..."
    # Using 'command , dotnet' to support the nix-style dotnet if needed
    if type -q ","
        , dotnet tool install -g JetBrains.Refasmer.CliTool
    else
        dotnet tool install -g JetBrains.Refasmer.CliTool
    end
end

# Generate stubs
set -l dlls sts2.dll 0Harmony.dll GodotSharp.dll
set -l output_dir "BSchneppe.Sts2.ReferenceAssemblies/ref/net9.0"
mkdir -p "$output_dir"

for dll in $dlls
    set -l input_path "$STS2_GAME_DIR/$dll"
    if not test -f "$input_path"
        echo "Warning: $dll not found in $STS2_GAME_DIR. Skipping..."
        continue
    end
    
    echo "Generating stub for $dll..."
    eval "$refasmer_path -v --omit-non-api-members true -o \"$output_dir/$dll\" \"$input_path\""
end

echo "Stub generation complete!"

# Git automation
if test -d .git; and test -n "$game_version"
    echo "Checking for changes to stage..."
    git add BSchneppe.Sts2.ReferenceAssemblies/BSchneppe.Sts2.ReferenceAssemblies.csproj "$output_dir"/*.dll
    
    if git diff --cached --quiet
        echo "No changes detected in stubs. Skipping commit/tag."
    else
        echo "Committing and tagging version v$game_version..."
        git commit -m "Update stubs to game version $game_version"
        git tag "v$game_version"
        echo "Successfully committed and tagged v$game_version."
        echo "Run 'git push origin main --tags' to trigger the NuGet release."
    end
end
