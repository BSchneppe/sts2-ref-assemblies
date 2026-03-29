# BSchneppe.Sts2.ReferenceAssemblies

[![NuGet](https://img.shields.io/nuget/v/BSchneppe.Sts2.ReferenceAssemblies.svg?style=flat-square)](https://www.nuget.org/packages/BSchneppe.Sts2.ReferenceAssemblies)

Reference-only stubs for Slay the Spire 2 mod development.

## Why?

Slay the Spire 2 mods require three game assemblies to compile:
- `sts2.dll`
- `0Harmony.dll`
- `GodotSharp.dll`

These DLLs only exist in local game installs and cannot be redistributed. This package provides **reference-only stubs** (type definitions with no implementation code) that allow mods to compile in CI environments without needing a full game installation.

## Usage

In your mod's `.csproj`, add a conditional reference that falls back to the NuGet package when the game is not installed locally:

```xml
<PropertyGroup>
  <!-- Define this in a Directory.Build.props or similar if needed -->
  <STS2GameDir Condition="'$(STS2GameDir)' == ''">C:/Program Files (x86)/Steam/steamapps/common/Slay the Spire 2/data/</STS2GameDir>
</PropertyGroup>

<ItemGroup>
  <!-- CI / no game install: use NuGet stubs -->
  <PackageReference Include="BSchneppe.Sts2.ReferenceAssemblies" Version="0.100.*"
                    Condition="!Exists('$(STS2GameDir)/sts2.dll')"
                    PrivateAssets="All" />
</ItemGroup>

<!-- Local dev: use real game DLLs (better IntelliSense, runtime debugging) -->
<ItemGroup Condition="Exists('$(STS2GameDir)/sts2.dll')">
  <Reference Include="sts2">
    <HintPath>$(STS2GameDir)/sts2.dll</HintPath>
    <Private>false</Private>
  </Reference>
  <Reference Include="0Harmony">
    <HintPath>$(STS2GameDir)/0Harmony.dll</HintPath>
    <Private>false</Private>
  </Reference>
  <Reference Include="GodotSharp">
    <HintPath>$(STS2GameDir)/GodotSharp.dll</HintPath>
    <Private>false</Private>
  </Reference>
</ItemGroup>
```

## CI/CD Example (GitHub Actions)

Since the NuGet package provides the stubs, your CI workflow doesn't need the game installed:

```yaml
name: Build Mod

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'
      - name: Restore dependencies
        run: dotnet restore
      - name: Build
        run: dotnet build -c Release --no-restore
```

## How to regenerate stubs (for maintainers)

1. Ensure you have the game installed.
2. Ensure you have the `dotnet` CLI installed. The generation script will automatically install the `refasmer` global tool if it's not found in `~/.dotnet/tools/refasmer`.
3. Run the generation script:
   ```bash
   ./scripts/generate-stubs.sh
   ```
   (If the game is in a non-standard location, set `STS2_GAME_DIR` first.)

4. Pack and publish:
   ```bash
   dotnet pack BSchneppe.Sts2.ReferenceAssemblies/BSchneppe.Sts2.ReferenceAssemblies.csproj -c Release
   ```

## Legal

These stubs contain only type signatures and no implementation logic. They are intended for compilation use only and do not contain copyrighted game code.
