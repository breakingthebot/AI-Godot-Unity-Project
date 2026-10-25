# Ashen Pantheon — Godot 4 & Unity 6 Dual-Engine Pixel-Art Dungeon Crawler & MCP Studio

A playable 16-bit dark-fantasy 2D Top-Down Pixel-Art Dungeon Crawler RPG built in Godot 4.4.1 alongside a synchronized Unity 6 (C#) character pipeline, 1,000-match Monte Carlo combat balance simulator, and a bi-directional Model Context Protocol (MCP) & UDP live telemetry server.

## Stack
- **Godot 4.4.1 (GDScript)**: Playable 5-room procedural dungeon crawler (`godot_project/scripts/arena_controller.gd`), procedural 25-sprite pixel-art generator (`godot_project/scripts/sprite_art_generator.gd`), real-time `AudioStreamGenerator` retro SFX synthesizer (`godot_project/scripts/procedural_sfx.gd`), interactive RPG Character Sheet HUD (`godot_project/scripts/character_sheet_hud.gd`), Tactical Utility AI Auto-Pilot (`[P]`), and Multi-Phase Boss encounters.
- **Unity 6 (C#)**: Strongly-typed `JsonUtility` character data loader (`unity_project/Assets/Scripts/CharacterLoader.cs`) and headless `-batchmode` verification bridge (`unity_project/Assets/Scripts/Editor/UnityBatchmodeBridge.cs`).
- **Python 3.11+ (MCP & Simulation)**: 9-tool Dual-Engine Stdio MCP Server (`src/godot_mcp_server.py`), 1,000-match Monte Carlo Combat Balance Simulator (`src/combat_simulator.py`), and JSON Schema Draft-07 character definitions (`data/`).

## Setup & Environment
1. Copy `.env.example` to `.env` and optionally set `GODOT_BIN` and `UNITY_EDITOR_BIN` if not on your system `PATH`.
2. Create and activate a Python virtual environment for MCP & combat simulation tests:
   ```bash
   python -m venv .venv
   # Windows: .venv\Scripts\activate | macOS/Linux: source .venv/bin/activate
   pip install -r requirements.txt
   ```

## Usage
- **Launch the Playable Godot 4 Pixel-Art Dungeon Crawler**:
  ```bash
  godot --path godot_project
  ```
  - **Controls**: `[Tab]` Switch Character Sheet / 2D Dungeon Arena | `[1]`–`[4]` Swap Hero (`Kaelen`, `Malakor`, `Vespera`, `Gorvath`) | `WASD` Move | `Mouse / Space` Attack | `[Shift]` Mana Dash | `[F]` Arcane Parry | `[Q]` Class Ultimate | `[C]` Use Potion | `[E]` Loot Relic Chest | `[N]` Next Dungeon Room | `[G]` Wave Survival Mode | `[P]` Autonomous Tactical AI Auto-Pilot | `[M]` Mute SFX | `[F5]` / `[F9]` Save / Load Party.
- **Run the 42-Step Automated Headless Godot Test Suite**:
  ```bash
  godot --headless --path godot_project -s res://tests/test_hud_headless.gd
  ```
- **Run the Python Dual-Engine MCP & Monte Carlo Combat Simulator Tests**:
  ```bash
  pytest -v
  ```

## Data & Privacy
- Processes local fictional RPG character JSON schemas, procedural pixel-art sprites, and localhost (`127.0.0.1`) UDP telemetry only. Zero PII, external analytics, or network credentials are collected or stored. Licensed under the [MIT License](LICENSE).
