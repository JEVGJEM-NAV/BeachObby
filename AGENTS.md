# Beach Obby — Codex Instructions

## Project

Roblox game written in Luau.

MVP:
- Scene 1: hot beach, jumping across sun loungers.
- Scene 2: water crossing using inflatable rings.
- Scene 3: circular island with rotating lasers.
- Finish: climb a giant palm tree.
- Optional collectible coins.
- Timer continues after player death.
- One checkpoint at the beginning of each scene.
- Hazards return the player to the latest checkpoint.

## Workflow

- Luau source files are edited in VS Code through Roblox Script Sync.
- Use Roblox Studio MCP to inspect the game tree, create or configure Roblox instances, and run tests.
- Do not edit Script Sync-managed script source directly in Roblox Studio.
- Before changing anything, inspect the existing files and game tree.
- Make one small, testable change at a time.
- Do not add features outside the requested task.
- Do not add decorative assets during the technical prototype.
- Never delete existing objects or files unless explicitly requested.

## Architecture

- The server is authoritative for checkpoints, coins, timer state, hazards, and finishing.
- The client is responsible only for interface presentation and local visual effects.
- Shared code and RemoteEvents belong in ReplicatedStorage.
- Server code belongs in ServerScriptService.
- Client code belongs in StarterPlayerScripts or StarterGui.
- Reuse common systems; do not create separate death logic for every hazard.
- Use strict Luau where practical.
- Use clear English names for files, instances, functions, and variables.

## Testing

After every implementation task:

1. Run the game through Roblox Studio MCP when available.
2. Check the Output window for errors and warnings.
3. Report exactly what was changed.
4. Report what was tested and whether it passed.
5. Stop and ask before starting the next feature.