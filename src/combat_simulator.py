# src/combat_simulator.py
# Deterministic & Monte Carlo 1,000-Match Combat Balance Simulator for the 4-Hero Ashen Pantheon Roster.
# Connects to: data/CharacterData.json, data/characters/*.json, src/godot_mcp_server.py
# Created: 2026-10-24

from __future__ import annotations

import argparse
import json
import math
import random
import time
from pathlib import Path
from typing import Any

BASE_MOVE_SPEED: float = 230.0
SPEED_PER_DEX_MOD: float = 18.0
BASE_ARROW_DAMAGE: int = 6
CONTACT_BASE_DAMAGE: int = 12
ULTIMATE_MANA_COST: int = 15
DASH_MANA_COST: int = 6
MANA_REGEN_PER_SEC: float = 3.0
PRIMARY_ATTACKS_PER_SEC: float = 2.4

RELIC_CATALOG: tuple[dict[str, Any], ...] = (
    {
        "item_id": "relic_ember_heart",
        "name": "Embercrest Relic (+4 Dmg, +10 HP)",
        "bonus_damage": 4,
        "bonus_max_hp": 10,
        "bonus_speed": 0.0,
    },
    {
        "item_id": "relic_wind_feather",
        "name": "Gale-Stalker Plume (+2 Dmg, +25 Spd)",
        "bonus_damage": 2,
        "bonus_max_hp": 0,
        "bonus_speed": 25.0,
    },
    {
        "item_id": "relic_titan_core",
        "name": "Titan Core Relic (+6 Dmg, +20 HP)",
        "bonus_damage": 6,
        "bonus_max_hp": 20,
        "bonus_speed": 10.0,
    },
)


def get_workspace_root() -> Path:
    """Returns the root directory of AI-Godot-Unity-Project."""
    return Path(__file__).resolve().parent.parent


def get_attribute_modifier(score: int) -> int:
    """Calculates standard RPG attribute modifier: floor((score - 10) / 2)."""
    return math.floor((score - 10) / 2.0)


def load_all_roster_heroes(root: Path | None = None) -> list[dict[str, Any]]:
    """Loads all 4 roster heroes from data/CharacterData.json and data/characters/*.json."""
    workspace = root or get_workspace_root()
    paths = [
        workspace / "data" / "CharacterData.json",
        workspace / "data" / "characters" / "ash_knight.json",
        workspace / "data" / "characters" / "echo_wraith.json",
        workspace / "data" / "characters" / "rotting_sentinel.json",
    ]
    heroes: list[dict[str, Any]] = []
    for p in paths:
        if not p.is_file():
            raise FileNotFoundError(f"Missing roster character file: {p}")
        heroes.append(json.loads(p.read_text(encoding="utf-8")))
    return heroes


def compute_hero_combat_metrics(
    hero: dict[str, Any],
    bonus_dmg: int = 0,
    bonus_hp: int = 0,
    bonus_spd: float = 0.0,
) -> dict[str, Any]:
    """Computes derived combat stats matching godot_project/scripts/arena_controller.gd."""
    attrs = hero.get("attributes", {})
    skills = hero.get("skills", [])
    primary_rank = int(skills[0].get("rank", 0)) if skills else 0
    primary_mod_attr = str(skills[0].get("modifier", "dexterity")) if skills else "dexterity"
    secondary_rank = int(skills[1].get("rank", 0)) if len(skills) > 1 else 0

    primary_attr_score = int(attrs.get(primary_mod_attr, 10))
    primary_mod = get_attribute_modifier(primary_attr_score)
    dex_mod = get_attribute_modifier(int(attrs.get("dexterity", 10)))
    con_mod = get_attribute_modifier(int(attrs.get("constitution", 10)))

    arrow_dmg = max(1, BASE_ARROW_DAMAGE + primary_rank + primary_mod + bonus_dmg)
    move_speed = BASE_MOVE_SPEED + float(dex_mod) * SPEED_PER_DEX_MOD + bonus_spd
    armor = max(0, con_mod)
    mitigated_contact_dmg = max(2, CONTACT_BASE_DAMAGE - armor)

    max_hp = int(hero.get("health", {}).get("max", 45)) + bonus_hp
    max_mp = int(hero.get("mana", {}).get("max", 20))
    effective_hp = round(max_hp * (CONTACT_BASE_DAMAGE / float(mitigated_contact_dmg)), 1)
    base_dps = round(arrow_dmg * PRIMARY_ATTACKS_PER_SEC, 1)

    return {
        "arrow_damage": arrow_dmg,
        "move_speed": round(move_speed, 1),
        "armor": armor,
        "mitigated_contact_dmg": mitigated_contact_dmg,
        "max_hp": max_hp,
        "max_mp": max_mp,
        "effective_hp": effective_hp,
        "base_dps": base_dps,
        "secondary_rank": secondary_rank,
    }


def build_wave_enemies(wave_num: int) -> list[dict[str, Any]]:
    """Builds the wave enemy list matching _init_dummies(scale_wave) in arena_controller.gd."""
    hp_mult = 1.0 + max(0, wave_num - 1) * 0.18
    spd_mult = 1.0 + max(0, wave_num - 1) * 0.10
    enemies = [
        {"name": "Corruption Scout", "hp": round(45.0 * hp_mult), "speed": 95.0 * 1.15 * spd_mult, "is_boss": False},
        {"name": "Ashen Stalker", "hp": round(75.0 * hp_mult), "speed": 95.0 * 1.00 * spd_mult, "is_boss": False},
        {"name": "Blighted Sentinel", "hp": round(110.0 * hp_mult), "speed": 95.0 * 0.82 * spd_mult, "is_boss": False},
    ]
    if wave_num > 0 and wave_num % 3 == 0:
        enemies.append(
            {
                "name": "Ashen Titan [BOSS]",
                "hp": round(220.0 * hp_mult),
                "speed": 95.0 * 0.78 * spd_mult,
                "is_boss": True,
            }
        )
    return enemies


def simulate_single_run(
    hero: dict[str, Any],
    max_waves: int,
    rng: random.Random,
) -> dict[str, Any]:
    """Simulates a single multi-wave arena run (Waves 1..max_waves) with Ultimates, Dashes, Armor, and Relic Chest drops."""
    cid = str(hero.get("character_id", "char_001"))
    bonus_dmg = 0
    bonus_hp = 0
    bonus_spd = 0.0

    metrics = compute_hero_combat_metrics(hero, bonus_dmg, bonus_hp, bonus_spd)
    hp = float(metrics["max_hp"])
    mp = float(metrics["max_mp"])

    waves_cleared = 0
    total_score = 0
    elapsed_sec = 0.0
    dt = 0.5  # Half-second simulation time step
    ult_cd = 0.0

    for wave_num in range(1, max_waves + 1):
        enemies = build_wave_enemies(wave_num)
        metrics = compute_hero_combat_metrics(hero, bonus_dmg, bonus_hp, bonus_spd)
        arrow_dmg = metrics["arrow_damage"]
        move_spd = metrics["move_speed"]
        contact_dmg = metrics["mitigated_contact_dmg"]

        while any(e["hp"] > 0 for e in enemies) and hp > 0:
            elapsed_sec += dt
            mp = min(float(metrics["max_mp"]), mp + MANA_REGEN_PER_SEC * dt)
            ult_cd = max(0.0, ult_cd - dt)

            alive_enemies = [e for e in enemies if e["hp"] > 0]
            if not alive_enemies:
                break

            # 1. Cast Class Ultimate ([Q], 15 MP) when off cooldown and MP >= 15
            iframe_bonus = 0.0
            if ult_cd <= 0.0 and mp >= ULTIMATE_MANA_COST:
                mp -= ULTIMATE_MANA_COST
                ult_cd = 2.0
                if cid == "ash_001":
                    nova_dmg = arrow_dmg * 2 + 12
                    for e in alive_enemies[:2]:
                        e["hp"] -= nova_dmg
                    hp = min(float(metrics["max_hp"]), hp + 12.0)
                elif cid == "ash_002":
                    shadow_dmg = arrow_dmg + 14
                    for e in alive_enemies:
                        e["hp"] -= shadow_dmg
                    alive_enemies[0]["hp"] -= arrow_dmg + 10
                    iframe_bonus = 0.75
                elif cid == "ash_003":
                    quake_dmg = arrow_dmg * 2 + 8
                    for e in alive_enemies:
                        e["hp"] -= quake_dmg
                        e["speed"] *= 0.65
                    iframe_bonus = 1.0
                else:
                    volley_dmg = round(arrow_dmg * 1.35)
                    for i in range(min(3, len(alive_enemies))):
                        alive_enemies[i]["hp"] -= volley_dmg * 2

            # 2. Primary Attack DPS step (with +/- 15% aim/crit variance)
            alive_enemies = [e for e in enemies if e["hp"] > 0]
            if alive_enemies:
                primary_burst = arrow_dmg * PRIMARY_ATTACKS_PER_SEC * dt * rng.uniform(0.85, 1.18)
                alive_enemies[0]["hp"] -= primary_burst

            # 3. Enemy pursuit & contact pressure vs hero mobility & Mana Dash
            alive_enemies = [e for e in enemies if e["hp"] > 0]
            if alive_enemies and iframe_bonus <= 0.0:
                avg_enemy_spd = sum(e["speed"] for e in alive_enemies) / len(alive_enemies)
                kite_ratio = max(0.18, min(0.85, avg_enemy_spd / max(180.0, move_spd)))
                # Spend 6 MP on Mana Dash to evade contact hits when threatened
                if mp >= DASH_MANA_COST and rng.random() < 0.42:
                    mp -= DASH_MANA_COST
                    kite_ratio *= 0.25
                if rng.random() < kite_ratio * 0.55:
                    hp -= contact_dmg

        if hp <= 0:
            break

        # Wave Cleared! Award score, +15 HP, +10 MP, and loot the Wave Clear Relic Chest
        waves_cleared += 1
        for e in enemies:
            total_score += (300 if e["is_boss"] else 100) * wave_num

        relic = RELIC_CATALOG[(wave_num - 1) % len(RELIC_CATALOG)]
        bonus_dmg += int(relic["bonus_damage"])
        bonus_hp += int(relic["bonus_max_hp"])
        bonus_spd += float(relic["bonus_speed"])
        metrics = compute_hero_combat_metrics(hero, bonus_dmg, bonus_hp, bonus_spd)
        hp = min(float(metrics["max_hp"]), hp + 15.0 + float(relic["bonus_max_hp"]))
        mp = min(float(metrics["max_mp"]), mp + 10.0)

    return {
        "cleared_all": waves_cleared >= max_waves,
        "waves_cleared": waves_cleared,
        "elapsed_sec": elapsed_sec,
        "score": total_score,
    }


def run_monte_carlo_balance_simulation(
    runs_per_hero: int = 250,
    max_waves: int = 5,
    seed: int = 42,
    root: Path | None = None,
) -> dict[str, Any]:
    """Runs Monte Carlo combat simulations across all 4 roster heroes and generates balance recommendations."""
    if runs_per_hero < 1 or max_waves < 1:
        raise ValueError("runs_per_hero and max_waves must be >= 1.")

    start_ts = time.perf_counter()
    rng = random.Random(seed)
    heroes = load_all_roster_heroes(root)

    hero_reports: list[dict[str, Any]] = []
    for hero in heroes:
        base_metrics = compute_hero_combat_metrics(hero)
        wins = 0
        total_waves = 0
        total_time = 0.0
        total_score = 0

        for _ in range(runs_per_hero):
            outcome = simulate_single_run(hero, max_waves=max_waves, rng=rng)
            if outcome["cleared_all"]:
                wins += 1
            total_waves += outcome["waves_cleared"]
            total_time += outcome["elapsed_sec"]
            total_score += outcome["score"]

        win_rate = round((wins / float(runs_per_hero)) * 100.0, 1)
        avg_waves = round(total_waves / float(runs_per_hero), 2)
        avg_time = round(total_time / float(runs_per_hero), 2)
        avg_score = round(total_score / float(runs_per_hero), 1)

        hero_reports.append(
            {
                "character_id": hero.get("character_id"),
                "name": hero.get("name"),
                "character_class": hero.get("character_class"),
                "level": hero.get("level"),
                "base_dps": base_metrics["base_dps"],
                "effective_hp": base_metrics["effective_hp"],
                "move_speed": base_metrics["move_speed"],
                "armor": base_metrics["armor"],
                "win_rate_pct": win_rate,
                "avg_waves_cleared": avg_waves,
                "avg_clear_time_sec": avg_time,
                "avg_score": avg_score,
            }
        )

    mean_win_rate = round(
        sum(r["win_rate_pct"] for r in hero_reports) / float(len(hero_reports)),
        1,
    )
    recommendations: list[str] = []
    for r in hero_reports:
        delta = r["win_rate_pct"] - mean_win_rate
        if delta > 15.0:
            r["balance_tier"] = "OVERPERFORMING (S-Tier)"
            recommendations.append(
                f"Tune down {r['name']} ({r['win_rate_pct']}% vs {mean_win_rate}% party mean): consider -1 primary skill rank."
            )
        elif delta < -15.0:
            r["balance_tier"] = "UNDERPERFORMING (Needs Buff)"
            recommendations.append(
                f"Buff {r['name']} ({r['win_rate_pct']}% vs {mean_win_rate}% party mean): consider +8 Base HP or +1 primary skill rank."
            )
        else:
            r["balance_tier"] = "BALANCED (A-Tier)"

    if not recommendations:
        recommendations.append(
            f"All 4 Ashen Pantheon heroes are within +/-15% of the {mean_win_rate}% party mean win rate across Wave {max_waves}."
        )

    duration_ms = round((time.perf_counter() - start_ts) * 1000.0, 2)
    return {
        "status": "completed",
        "total_matches_simulated": runs_per_hero * len(hero_reports),
        "runs_per_hero": runs_per_hero,
        "target_waves": max_waves,
        "seed": seed,
        "duration_ms": duration_ms,
        "party_mean_win_rate_pct": mean_win_rate,
        "heroes": hero_reports,
        "recommendations": recommendations,
    }


def format_cli_report(report: dict[str, Any]) -> str:
    """Formats the simulation report as an aligned ASCII table for terminal inspection."""
    lines = [
        "=" * 94,
        f" ASHEN PANTHEON COMBAT BALANCE SIMULATOR -- {report['total_matches_simulated']} Matches "
        f"(Waves 1..{report['target_waves']}) in {report['duration_ms']} ms",
        "=" * 94,
        f"{'Hero Name':<26} | {'Class':<16} | {'DPS':>5} | {'EHP':>6} | {'Spd':>5} | {'Win %':>6} | {'Avg Wave':>8} | {'Tier'}",
        "-" * 94,
    ]
    for h in report["heroes"]:
        lines.append(
            f"{h['name']:<26} | {h['character_class']:<16} | {h['base_dps']:>5.1f} | "
            f"{h['effective_hp']:>6.1f} | {h['move_speed']:>5.0f} | {h['win_rate_pct']:>5.1f}% | "
            f"{h['avg_waves_cleared']:>8.2f} | {h['balance_tier']}"
        )
    lines.append("-" * 94)
    lines.append(f"Party Mean Win Rate: {report['party_mean_win_rate_pct']}%")
    for rec in report["recommendations"]:
        lines.append(f"  * {rec}")
    lines.append("=" * 94)
    return "\n".join(lines)


def main() -> None:
    """CLI entry point for running the 1,000-match combat balance simulator."""
    parser = argparse.ArgumentParser(
        description="Run Monte Carlo combat balance simulations across the 4-Hero Ashen Pantheon roster."
    )
    parser.add_argument("--runs", type=int, default=250, help="Simulated runs per hero (default: 250 = 1,000 total)")
    parser.add_argument("--waves", type=int, default=5, help="Target wave count per run (default: 5)")
    parser.add_argument("--seed", type=int, default=42, help="Deterministic RNG seed (default: 42)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON report instead of ASCII table")
    args = parser.parse_args()

    report = run_monte_carlo_balance_simulation(
        runs_per_hero=args.runs,
        max_waves=args.waves,
        seed=args.seed,
    )
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(format_cli_report(report))


if __name__ == "__main__":
    main()
