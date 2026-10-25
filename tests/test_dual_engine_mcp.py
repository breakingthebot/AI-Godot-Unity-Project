# tests/test_dual_engine_mcp.py
# Unit test suite for Dual-Engine Godot 4.4 & Unity 6 MCP Server, Roster Pack, UDP Bridge, and Schema Sync.
# Connects to: src/godot_mcp_server.py, godot_project/project.godot, unity_project/ProjectSettings/ProjectVersion.txt
# Created: 2026-10-24

from __future__ import annotations

import json
import socket
import tempfile
import threading
import unittest
from pathlib import Path

from src import combat_simulator
from src import godot_mcp_server as mcp


class TestDualEngineMcpServer(unittest.TestCase):
    """Verifies Godot 4.4 + Unity 6 MCP tools, 4-hero roster sync parity, UDP bridge, Combat Simulator, and chaos failure modes."""

    def test_01_tools_list_includes_godot_and_unity_tools(self) -> None:
        """Verifies all 11 Godot, Unity, UDP Bridge, Combat Simulator, and Dual-Engine tools are registered."""
        resp = mcp.process_request({"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
        self.assertIsNotNone(resp)
        tools = resp["result"]["tools"]
        names = {t["name"] for t in tools}
        expected = {
            "godot_get_version",
            "godot_list_projects",
            "godot_inspect_project",
            "godot_run_headless",
            "godot_launch_editor",
            "godot_send_live_command",
            "unity_get_status",
            "unity_inspect_project",
            "unity_run_batchmode",
            "dual_engine_sync_data",
            "godot_run_combat_simulation",
        }
        self.assertTrue(expected.issubset(names))

    def test_02_unity_inspect_and_batchmode_preflight(self) -> None:
        """Verifies Unity 6 project scaffolding, C# scripts, and pre-flight contract check."""
        info = mcp.handle_unity_inspect_project({})
        self.assertNotIn("error", info)
        self.assertTrue(info["has_package_manifest"])
        self.assertIn("6000.0", info["editor_version"])
        self.assertTrue(
            any("CharacterLoader.cs" in s for s in info["csharp_scripts"])
        )
        self.assertTrue(
            any("UnityBatchmodeBridge.cs" in s for s in info["csharp_scripts"])
        )

        batch_res = mcp.handle_unity_run_batchmode({})
        self.assertNotIn("error", batch_res)

    def test_03_dual_engine_sync_byte_parity_and_ashen_pantheon_roster(self) -> None:
        """Verifies all 4 heroes sync cleanly with 100% byte parity and unique character_ids across Godot & Unity."""
        sync_res = mcp.handle_dual_engine_sync_data({})
        self.assertEqual(sync_res.get("status"), "synced")
        self.assertEqual(sync_res.get("character_name"), "Kaelen")
        self.assertTrue(sync_res.get("byte_parity_verified"))
        roster_ids = sync_res.get("synced_roster_ids", [])
        self.assertEqual(
            roster_ids,
            ["char_001", "ash_001", "ash_002", "ash_003"],
        )

    def test_04_chaos_fixture_collect_all_validation(self) -> None:
        """Exercises broken chaos fixture simultaneously violating multiple schema rules."""
        chaos_payload = {
            "character_id": "CHAOS-999",
            # Missing 'name', 'race', 'character_class', 'skills', 'inventory', 'backstory'
            "level": -5,
            "health": {"current": 10},  # Missing 'max'
            "mana": "invalid_type",
            "attributes": {"strength": "not_an_int"},
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            chaos_file = Path(tmpdir) / "ChaosCharacter.json"
            chaos_file.write_text(json.dumps(chaos_payload), encoding="utf-8")

            res = mcp.handle_dual_engine_sync_data({"source_json": str(chaos_file)})
            self.assertIn("error", res)
            issues = res.get("issues", [])
            self.assertGreaterEqual(len(issues), 6)
            joined = " | ".join(issues)
            self.assertIn("Missing required field 'name'", joined)
            self.assertIn("Field 'level' must be a positive integer", joined)
            self.assertIn("Field 'health' must include 'current' and 'max'", joined)
            self.assertIn("Field 'mana' must be an object", joined)

    def test_05_udp_live_command_roundtrip_and_offline_fallback(self) -> None:
        """Verifies UDP live command round-trip against a local listener and graceful offline timeout."""
        server_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        server_sock.bind(("127.0.0.1", 0))
        ephemeral_port = server_sock.getsockname()[1]

        def _mock_godot_listener() -> None:
            data, addr = server_sock.recvfrom(4096)
            req = json.loads(data.decode("utf-8"))
            ack = {
                "status": "ok",
                "command": req.get("command"),
                "snapshot": {"name": "Malakor, The Ash-Knight", "level": 8},
            }
            server_sock.sendto(json.dumps(ack).encode("utf-8"), addr)
            server_sock.close()

        t = threading.Thread(target=_mock_godot_listener, daemon=True)
        t.start()

        live_res = mcp.handle_godot_send_live_command(
            {"command": "level_up", "port": ephemeral_port}
        )
        t.join(timeout=1.0)
        self.assertIn("live_response", live_res)
        self.assertEqual(live_res["live_response"]["status"], "ok")

        # Test offline fallback on an unused port
        offline_res = mcp.handle_godot_send_live_command(
            {"command": "ping", "port": 59999, "timeout": 0.05}
        )
        self.assertEqual(offline_res.get("status"), "offline_or_no_window_open")

    def test_06_combat_balance_simulator_1000_matches(self) -> None:
        """Verifies 1,000-match Monte Carlo simulation across all 4 heroes and deterministic seed parity."""
        report_a = mcp.handle_godot_run_combat_simulation(
            {"runs_per_hero": 250, "max_waves": 5, "seed": 42}
        )
        report_b = mcp.handle_godot_run_combat_simulation(
            {"runs_per_hero": 250, "max_waves": 5, "seed": 42}
        )
        self.assertEqual(report_a.get("status"), "completed")
        self.assertEqual(report_a.get("total_matches_simulated"), 1000)
        self.assertEqual(len(report_a.get("heroes", [])), 4)
        self.assertEqual(
            report_a.get("party_mean_win_rate_pct"),
            report_b.get("party_mean_win_rate_pct"),
        )
        cli_table = combat_simulator.format_cli_report(report_a)
        self.assertIn("ASHEN PANTHEON COMBAT BALANCE SIMULATOR", cli_table)
        self.assertIn("Malakor, The Ash-Knight", cli_table)

    def test_07_combat_simulator_invalid_parameter_failure_mode(self) -> None:
        """Verifies invalid simulation parameters return an explicit error dictionary."""
        err_res = mcp.handle_godot_run_combat_simulation(
            {"runs_per_hero": 0, "max_waves": -2}
        )
        self.assertIn("error", err_res)
        with self.assertRaises(ValueError):
            combat_simulator.run_monte_carlo_balance_simulation(
                runs_per_hero=0, max_waves=5
            )


if __name__ == "__main__":
    unittest.main()
