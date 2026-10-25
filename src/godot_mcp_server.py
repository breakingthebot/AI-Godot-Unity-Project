# src/godot_mcp_server.py
# Dual-Engine Godot 4.4 & Unity 6 Model Context Protocol (MCP) Server over Stdio.
# Connects to: godot_project/project.godot, godot_project/scripts/command_center_receiver.gd, unity_project/Assets/Scripts/CharacterLoader.cs
# Created: 2026-10-24

from __future__ import annotations

import json
import shutil
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any

from src import combat_simulator

REQUIRED_CHARACTER_KEYS: tuple[str, ...] = (
    "character_id",
    "name",
    "race",
    "character_class",
    "level",
    "health",
    "mana",
    "attributes",
    "skills",
    "inventory",
    "backstory",
)
DEFAULT_UDP_HOST: str = "127.0.0.1"
DEFAULT_UDP_PORT: int = 4242


def get_home_dir() -> Path:
    """Returns the user's home directory Path."""
    return Path.home()


def get_workspace_root() -> Path:
    """Returns the root directory of AI-Godot-Unity-Project."""
    return Path(__file__).resolve().parent.parent


def redact_path(path_str: str) -> str:
    """Replaces user profile paths with $HOME for Zero-PII output."""
    home_str = str(get_home_dir())
    return path_str.replace(home_str, "$HOME").replace(
        home_str.replace("\\", "/"), "$HOME"
    )


def find_godot_executable(console: bool = True) -> Path | None:
    """Locates the Godot 4.4.1 console or GUI executable."""
    home = get_home_dir()
    exe_name = (
        "Godot_v4.4.1-stable_mono_win64_console.exe"
        if console
        else "Godot_v4.4.1-stable_mono_win64.exe"
    )
    candidates = [
        home / "Desktop" / "Godot_v4.4.1-stable_mono_win64" / exe_name,
        home
        / "Desktop"
        / "Personal_Vault_Local"
        / "Personal_Folders"
        / "Godot_v4.4.1-stable_mono_win64"
        / exe_name,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def find_unity_hub() -> Path | None:
    """Locates the Unity Hub executable if installed."""
    candidates = [
        Path("C:/Program Files/Unity Hub/Unity Hub.exe"),
        get_home_dir() / "AppData" / "Local" / "Programs" / "Unity Hub" / "Unity Hub.exe",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def find_unity_editors() -> list[Path]:
    """Discovers installed Unity Editor binaries (Unity.exe) under Unity Hub."""
    hub_editors_root = Path("C:/Program Files/Unity/Hub/Editor")
    if not hub_editors_root.is_dir():
        return []
    return sorted(
        hub_editors_root.glob("*/Editor/Unity.exe"),
        reverse=True,
    )


def validate_character_dict(data: Any) -> list[str]:
    """Collect-all boundary validator for CharacterSheet JSON dictionaries."""
    if not isinstance(data, dict):
        return ["Root JSON element must be an object/dictionary."]

    errors: list[str] = []
    for key in REQUIRED_CHARACTER_KEYS:
        if key not in data:
            errors.append(f"Missing required field '{key}'.")

    if "level" in data and (not isinstance(data["level"], int) or data["level"] < 1):
        errors.append("Field 'level' must be a positive integer (>= 1).")

    for vital_key in ("health", "mana"):
        vital = data.get(vital_key)
        if isinstance(vital, dict):
            if "current" not in vital or "max" not in vital:
                errors.append(f"Field '{vital_key}' must include 'current' and 'max'.")
        elif vital is not None:
            errors.append(f"Field '{vital_key}' must be an object.")

    attrs = data.get("attributes")
    if isinstance(attrs, dict):
        for stat in (
            "strength",
            "dexterity",
            "constitution",
            "intelligence",
            "wisdom",
            "charisma",
        ):
            if stat not in attrs or not isinstance(attrs[stat], int):
                errors.append(f"Attribute '{stat}' must be an integer.")
    elif attrs is not None:
        errors.append("Field 'attributes' must be an object.")

    return errors


def handle_get_version(_args: dict[str, Any]) -> dict[str, Any]:
    """Returns the installed Godot 4.4 engine version and binary path."""
    exe = find_godot_executable(console=True)
    if not exe:
        return {"error": "Godot executable not found."}
    res = subprocess.run(
        [str(exe), "--version"],
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    return {
        "executable": redact_path(str(exe)),
        "version": res.stdout.strip() or res.stderr.strip(),
        "exit_code": res.returncode,
    }


def handle_list_projects(_args: dict[str, Any]) -> dict[str, Any]:
    """Lists all discovered Godot projects across Desktop and Documents."""
    home = get_home_dir()
    projects: list[dict[str, Any]] = []
    search_roots = [
        Path(__file__).resolve().parent.parent,
        home / "Desktop" / "AI-Godot-Unity-Project",
        home / "Documents",
    ]
    seen: set[str] = set()
    for root in search_roots:
        if not root.exists():
            continue
        for proj_file in root.rglob("project.godot"):
            proj_dir = str(proj_file.parent.resolve())
            if proj_dir in seen:
                continue
            seen.add(proj_dir)
            projects.append(
                {
                    "name": proj_file.parent.name,
                    "project_dir": redact_path(proj_dir),
                    "project_file": redact_path(str(proj_file.resolve())),
                }
            )
    return {"count": len(projects), "projects": projects}


def handle_inspect_project(args: dict[str, Any]) -> dict[str, Any]:
    """Inspects a Godot project's project.godot, scenes, scripts, and data files."""
    raw_dir = args.get(
        "project_dir",
        str(get_workspace_root() / "godot_project"),
    )
    resolved_dir = Path(raw_dir.replace("$HOME", str(get_home_dir()))).resolve()
    proj_file = resolved_dir / "project.godot"
    if not proj_file.is_file():
        return {"error": f"project.godot not found in {redact_path(str(resolved_dir))}"}

    scenes = [
        redact_path(str(p.relative_to(resolved_dir)))
        for p in resolved_dir.rglob("*.tscn")
    ]
    scripts = [
        redact_path(str(p.relative_to(resolved_dir)))
        for p in list(resolved_dir.rglob("*.gd")) + list(resolved_dir.rglob("*.cs"))
    ]
    data_files = [
        redact_path(str(p.relative_to(resolved_dir)))
        for p in resolved_dir.rglob("*.json")
    ]
    return {
        "project_dir": redact_path(str(resolved_dir)),
        "config": proj_file.read_text(encoding="utf-8", errors="replace"),
        "scenes": scenes,
        "scripts": scripts,
        "data_files": data_files,
    }


def handle_run_headless(args: dict[str, Any]) -> dict[str, Any]:
    """Runs a Godot project headlessly (--headless --quit) and returns console output."""
    exe = find_godot_executable(console=True)
    if not exe:
        return {"error": "Godot console executable not found."}
    raw_dir = args.get(
        "project_dir",
        str(get_workspace_root() / "godot_project"),
    )
    resolved_dir = Path(raw_dir.replace("$HOME", str(get_home_dir()))).resolve()
    cmd = [str(exe), "--headless", "--path", str(resolved_dir), "--quit"]
    scene = args.get("scene")
    if scene:
        cmd.append(str(scene))
    res = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    return {
        "project_dir": redact_path(str(resolved_dir)),
        "exit_code": res.returncode,
        "stdout": redact_path(res.stdout),
        "stderr": redact_path(res.stderr),
    }


def handle_launch_editor(args: dict[str, Any]) -> dict[str, Any]:
    """Launches the Godot 4.4 Editor GUI for the specified project."""
    exe = find_godot_executable(console=False)
    if not exe:
        return {"error": "Godot GUI executable not found."}
    raw_dir = args.get(
        "project_dir",
        str(get_workspace_root() / "godot_project"),
    )
    resolved_dir = Path(raw_dir.replace("$HOME", str(get_home_dir()))).resolve()
    proc = subprocess.Popen(
        [str(exe), "-e", "--path", str(resolved_dir)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return {
        "status": "launched",
        "pid": proc.pid,
        "project_dir": redact_path(str(resolved_dir)),
    }


def handle_godot_send_live_command(args: dict[str, Any]) -> dict[str, Any]:
    """Sends a live JSON RPC command over UDP (port 4242) to a running Godot game and returns the ACK snapshot."""
    command_name = str(args.get("command", "get_state")).strip()
    payload = args.get("payload", {})
    if not isinstance(payload, dict):
        payload = {}
    port = int(args.get("port", DEFAULT_UDP_PORT))
    timeout_sec = float(args.get("timeout", 0.6))

    packet = json.dumps({"command": command_name, "payload": payload}).encode("utf-8")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout_sec)
    try:
        sock.sendto(packet, (DEFAULT_UDP_HOST, port))
        raw_reply, _addr = sock.recvfrom(8192)
        parsed_reply = json.loads(raw_reply.decode("utf-8"))
        return {
            "transport": f"udp://{DEFAULT_UDP_HOST}:{port}",
            "live_response": parsed_reply,
        }
    except (socket.timeout, ConnectionResetError):
        return {
            "transport": f"udp://{DEFAULT_UDP_HOST}:{port}",
            "status": "offline_or_no_window_open",
            "sent_command": command_name,
            "note": "Packet dispatched cleanly; launch the Godot game window to receive live interactive UDP ACK snapshots.",
        }
    finally:
        sock.close()


def handle_unity_get_status(_args: dict[str, Any]) -> dict[str, Any]:
    """Reports Unity Hub installation status, installed Unity Editors, and project readiness."""
    hub_exe = find_unity_hub()
    editors = find_unity_editors()
    unity_proj = get_workspace_root() / "unity_project"
    manifest_file = unity_proj / "Packages" / "manifest.json"
    version_file = unity_proj / "ProjectSettings" / "ProjectVersion.txt"

    return {
        "unity_hub_installed": hub_exe is not None,
        "unity_hub_path": redact_path(str(hub_exe)) if hub_exe else None,
        "installed_unity_editors": [redact_path(str(e)) for e in editors],
        "unity_project_dir": redact_path(str(unity_proj)),
        "project_scaffold_ready": manifest_file.is_file() and version_file.is_file(),
    }


def handle_unity_inspect_project(args: dict[str, Any]) -> dict[str, Any]:
    """Inspects the Unity 6 project structure, packages, C# scripts, and synced JSON resources."""
    raw_dir = args.get(
        "project_dir",
        str(get_workspace_root() / "unity_project"),
    )
    resolved_dir = Path(raw_dir.replace("$HOME", str(get_home_dir()))).resolve()
    if not resolved_dir.is_dir():
        return {"error": f"Unity project directory not found: {redact_path(str(resolved_dir))}"}

    version_file = resolved_dir / "ProjectSettings" / "ProjectVersion.txt"
    manifest_file = resolved_dir / "Packages" / "manifest.json"
    cs_scripts = [
        redact_path(str(p.relative_to(resolved_dir)))
        for p in resolved_dir.rglob("*.cs")
    ]
    json_resources = [
        redact_path(str(p.relative_to(resolved_dir)))
        for p in (resolved_dir / "Assets").rglob("*.json")
    ] if (resolved_dir / "Assets").is_dir() else []

    return {
        "project_dir": redact_path(str(resolved_dir)),
        "editor_version": version_file.read_text(encoding="utf-8").strip()
        if version_file.is_file()
        else "Unknown",
        "has_package_manifest": manifest_file.is_file(),
        "csharp_scripts": cs_scripts,
        "json_resources": json_resources,
    }


def handle_unity_run_batchmode(args: dict[str, Any]) -> dict[str, Any]:
    """Runs Unity in headless -batchmode if an Editor is installed, or validates C# & JSON parity offline."""
    raw_dir = args.get(
        "project_dir",
        str(get_workspace_root() / "unity_project"),
    )
    resolved_dir = Path(raw_dir.replace("$HOME", str(get_home_dir()))).resolve()
    execute_method = args.get(
        "execute_method",
        "UnityBatchmodeBridge.ValidateAndPrintCharacterData",
    )

    editors = find_unity_editors()
    if editors:
        unity_exe = editors[0]
        cmd = [
            str(unity_exe),
            "-batchmode",
            "-nographics",
            "-quit",
            "-projectPath",
            str(resolved_dir),
            "-executeMethod",
            str(execute_method),
            "-logFile",
            "-",
        ]
        res = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        return {
            "mode": "unity_editor_batchmode",
            "unity_executable": redact_path(str(unity_exe)),
            "exit_code": res.returncode,
            "stdout": redact_path(res.stdout),
            "stderr": redact_path(res.stderr),
        }

    # Fallback deterministic pre-flight check when Unity Editor is not yet downloaded via Unity Hub
    json_path = resolved_dir / "Assets" / "Resources" / "Data" / "CharacterData.json"
    loader_cs = resolved_dir / "Assets" / "Scripts" / "CharacterLoader.cs"
    bridge_cs = (
        resolved_dir / "Assets" / "Scripts" / "Editor" / "UnityBatchmodeBridge.cs"
    )
    if not json_path.is_file():
        return {"error": f"Missing Unity resource file: {redact_path(str(json_path))}"}

    try:
        parsed = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"error": f"Invalid JSON in Unity resource: {exc}"}

    validation_errors = validate_character_dict(parsed)
    if validation_errors:
        return {"error": "Schema validation failed", "issues": validation_errors}

    return {
        "mode": "pre_flight_contract_verification",
        "note": "Unity Hub is ready; install a Unity 6 LTS Editor inside Unity Hub to enable live Unity.exe -batchmode compilation.",
        "verified_character": parsed.get("name"),
        "character_loader_cs_present": loader_cs.is_file(),
        "batchmode_bridge_cs_present": bridge_cs.is_file(),
        "validation_issues": [],
    }


def handle_dual_engine_sync_data(args: dict[str, Any]) -> dict[str, Any]:
    """Validates character JSON files, enforces character_id deduplication, and syncs to Godot 4.4 and Unity 6."""
    root = get_workspace_root()
    raw_source = args.get("source_json", str(root / "data" / "CharacterData.json"))
    source_path = Path(raw_source.replace("$HOME", str(get_home_dir()))).resolve()

    if not source_path.is_file():
        return {"error": f"Source JSON file not found: {redact_path(str(source_path))}"}

    try:
        parsed = json.loads(source_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {
            "error": f"Malformed JSON in {redact_path(str(source_path))}: {exc.msg} at line {exc.lineno}"
        }

    issues = validate_character_dict(parsed)
    if issues:
        return {
            "error": f"Schema validation failed ({len(issues)} issues)",
            "issues": issues,
        }

    godot_dest = root / "godot_project" / "data" / source_path.name
    unity_dest = (
        root / "unity_project" / "Assets" / "Resources" / "Data" / source_path.name
    )
    godot_dest.parent.mkdir(parents=True, exist_ok=True)
    unity_dest.parent.mkdir(parents=True, exist_ok=True)

    shutil.copy2(source_path, godot_dest)
    shutil.copy2(source_path, unity_dest)

    # Also sync any roster pack files in data/characters/*.json with character_id deduplication
    roster_dir = root / "data" / "characters"
    seen_ids: set[str] = {str(parsed.get("character_id"))}
    synced_roster: list[str] = [str(parsed.get("character_id"))]

    if roster_dir.is_dir() and source_path == (root / "data" / "CharacterData.json").resolve():
        godot_roster_dir = root / "godot_project" / "data" / "characters"
        unity_roster_dir = (
            root / "unity_project" / "Assets" / "Resources" / "Data" / "characters"
        )
        godot_roster_dir.mkdir(parents=True, exist_ok=True)
        unity_roster_dir.mkdir(parents=True, exist_ok=True)

        for pack_file in sorted(roster_dir.glob("*.json")):
            pack_data = json.loads(pack_file.read_text(encoding="utf-8"))
            pack_issues = validate_character_dict(pack_data)
            if pack_issues:
                return {
                    "error": f"Roster validation failed in {pack_file.name}",
                    "issues": pack_issues,
                }
            cid = str(pack_data.get("character_id"))
            if cid in seen_ids:
                return {
                    "error": f"Duplicate character_id '{cid}' in {pack_file.name}"
                }
            seen_ids.add(cid)
            synced_roster.append(cid)
            shutil.copy2(pack_file, godot_roster_dir / pack_file.name)
            shutil.copy2(pack_file, unity_roster_dir / pack_file.name)

    return {
        "status": "synced",
        "character_id": parsed.get("character_id"),
        "character_name": parsed.get("name"),
        "synced_roster_ids": synced_roster,
        "source": redact_path(str(source_path)),
        "godot_target": redact_path(str(godot_dest)),
        "unity_target": redact_path(str(unity_dest)),
        "byte_parity_verified": godot_dest.read_bytes() == unity_dest.read_bytes(),
    }


def handle_godot_run_combat_simulation(args: dict[str, Any]) -> dict[str, Any]:
    """Runs Monte Carlo combat balance simulations across all 4 Ashen Pantheon heroes."""
    runs_per_hero = int(args.get("runs_per_hero", 250))
    max_waves = int(args.get("max_waves", 5))
    seed = int(args.get("seed", 42))
    if runs_per_hero < 1 or max_waves < 1:
        return {"error": "runs_per_hero and max_waves must be positive integers (>= 1)."}
    return combat_simulator.run_monte_carlo_balance_simulation(
        runs_per_hero=runs_per_hero,
        max_waves=max_waves,
        seed=seed,
        root=get_workspace_root(),
    )


TOOLS = [
    {
        "name": "godot_get_version",
        "description": "Get the installed Godot 4.4 engine version and binary location.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "godot_list_projects",
        "description": "List all discovered Godot projects across Desktop and Documents.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "godot_inspect_project",
        "description": "Inspect a Godot project's project.godot, scenes (.tscn), scripts (.gd/.cs), and data files.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {
                    "type": "string",
                    "description": "Path to the folder containing project.godot.",
                }
            },
        },
    },
    {
        "name": "godot_run_headless",
        "description": "Run a Godot project headlessly (--headless --quit) and return console output.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {
                    "type": "string",
                    "description": "Path to the folder containing project.godot.",
                },
                "scene": {
                    "type": "string",
                    "description": "Optional scene path (e.g., res://scenes/main.tscn).",
                },
            },
        },
    },
    {
        "name": "godot_launch_editor",
        "description": "Launch the Godot 4.4 Editor GUI for the specified project.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {
                    "type": "string",
                    "description": "Path to the folder containing project.godot.",
                }
            },
        },
    },
    {
        "name": "godot_send_live_command",
        "description": "Send a live JSON RPC command over UDP (port 4242) to a running Godot window (level_up, select_hero, heal, damage, roll_skill, toggle_arena, toggle_wave, mana_dash, get_state).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Command name to execute in the running Godot game.",
                },
                "payload": {
                    "type": "object",
                    "description": "Optional JSON dictionary of command parameters (e.g., {'slot': 2} or {'amount': 20}).",
                },
                "port": {
                    "type": "integer",
                    "description": "Target loopback UDP port (default: 4242).",
                },
            },
            "required": ["command"],
        },
    },
    {
        "name": "unity_get_status",
        "description": "Check Unity Hub installation, installed Unity 6 Editors, and Unity project readiness.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "unity_inspect_project",
        "description": "Inspect the Unity 6 project's ProjectVersion.txt, Packages/manifest.json, C# scripts, and JSON assets.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {
                    "type": "string",
                    "description": "Path to the Unity project directory.",
                }
            },
        },
    },
    {
        "name": "unity_run_batchmode",
        "description": "Execute Unity in headless -batchmode -nographics (or run pre-flight C#/JSON contract verification).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_dir": {
                    "type": "string",
                    "description": "Path to the Unity project directory.",
                },
                "execute_method": {
                    "type": "string",
                    "description": "Static C# method to execute (default: UnityBatchmodeBridge.ValidateAndPrintCharacterData).",
                },
            },
        },
    },
    {
        "name": "dual_engine_sync_data",
        "description": "Validate character JSON files against the schema and sync them to both Godot 4.4 and Unity 6.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source_json": {
                    "type": "string",
                    "description": "Path to the source character JSON file.",
                }
            },
        },
    },
    {
        "name": "godot_run_combat_simulation",
        "description": "Run a 1,000-match Monte Carlo combat balance simulation across all 4 Ashen Pantheon heroes (Waves 1..N) and return win rates, DPS, EHP, and balance recommendations.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "runs_per_hero": {
                    "type": "integer",
                    "description": "Number of simulated arena runs per hero (default: 250 = 1,000 total matches).",
                },
                "max_waves": {
                    "type": "integer",
                    "description": "Target wave count per run (default: 5).",
                },
                "seed": {
                    "type": "integer",
                    "description": "Deterministic RNG seed (default: 42).",
                },
            },
        },
    },
]

HANDLERS = {
    "godot_get_version": handle_get_version,
    "godot_list_projects": handle_list_projects,
    "godot_inspect_project": handle_inspect_project,
    "godot_run_headless": handle_run_headless,
    "godot_launch_editor": handle_launch_editor,
    "godot_send_live_command": handle_godot_send_live_command,
    "unity_get_status": handle_unity_get_status,
    "unity_inspect_project": handle_unity_inspect_project,
    "unity_run_batchmode": handle_unity_run_batchmode,
    "dual_engine_sync_data": handle_dual_engine_sync_data,
    "godot_run_combat_simulation": handle_godot_run_combat_simulation,
}


def process_request(req: dict[str, Any]) -> dict[str, Any] | None:
    """Processes a single JSON-RPC 2.0 request dictionary."""
    method = req.get("method")
    req_id = req.get("id")

    if method == "initialize":
        protocol_version = req.get("params", {}).get(
            "protocolVersion", "2024-11-05"
        )
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {
                    "name": "godot-unity-mcp-server",
                    "version": "1.3.0",
                },
            },
        }
    if method in ("notifications/initialized", "initialized"):
        return None
    if method == "ping":
        return {"jsonrpc": "2.0", "id": req_id, "result": {}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    if method == "tools/call":
        params = req.get("params", {})
        tool_name = params.get("name", "")
        tool_args = params.get("arguments", {}) or {}
        handler = HANDLERS.get(tool_name)
        if not handler:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }
        try:
            output = handler(tool_args)
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [
                        {"type": "text", "text": json.dumps(output, indent=2)}
                    ],
                    "isError": "error" in output,
                },
            }
        except Exception as exc:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps({"error": str(exc)}, indent=2),
                        }
                    ],
                    "isError": True,
                },
            }
    if req_id is not None:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        }
    return None


def main() -> None:
    """Main Stdio loop for the Dual-Engine MCP server."""
    for line in sys.stdin:
        line = line.lstrip("\ufeff").strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue
        resp = process_request(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
