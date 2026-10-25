// unity_project/Assets/Scripts/Editor/UnityBatchmodeBridge.cs
// Provides headless CLI (-batchmode -executeMethod) and Unity Editor menu automation.
// Connects to: unity_project/Assets/Scripts/CharacterLoader.cs, src/godot_mcp_server.py
// Created: 2026-10-24

#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class UnityBatchmodeBridge
{
    private const string CharacterJsonAssetPath = "Assets/Resources/Data/CharacterData.json";

    /// <summary>
    /// Invoked via Unity Editor Menu or CLI:
    /// Unity.exe -batchmode -nographics -quit -projectPath ./unity_project -executeMethod UnityBatchmodeBridge.ValidateAndPrintCharacterData -logFile -
    /// </summary>
    [MenuItem("Tools/AI Character Studio/Validate CharacterData.json")]
    public static void ValidateAndPrintCharacterData()
    {
        Debug.Log("=== Starting Unity 6 Headless Character Verification ===");
        if (!File.Exists(CharacterJsonAssetPath))
        {
            Debug.LogError("FAIL: Character JSON not found at " + CharacterJsonAssetPath);
            if (Application.isBatchMode) EditorApplication.Exit(1);
            return;
        }

        string rawJson = File.ReadAllText(CharacterJsonAssetPath);
        CharacterSheet sheet = CharacterLoader.ParseAndValidateJson(rawJson);
        if (sheet == null)
        {
            Debug.LogError("FAIL: CharacterSheet deserialization or boundary validation failed.");
            if (Application.isBatchMode) EditorApplication.Exit(1);
            return;
        }

        int dexMod = CharacterLoader.GetAttributeModifier(sheet.attributes.dexterity);
        Debug.Log($"PASS: Loaded '{sheet.name}' (ID: {sheet.character_id}) — Level {sheet.level} {sheet.race} {sheet.character_class}");
        Debug.Log($"PASS: HP {sheet.health.current}/{sheet.health.max} | MP {sheet.mana.current}/{sheet.mana.max} | Dexterity {sheet.attributes.dexterity} (+{dexMod})");
        Debug.Log("=== UNITY 6 HEADLESS VERIFICATION PASSED ===");

        if (Application.isBatchMode)
        {
            EditorApplication.Exit(0);
        }
    }
}
#endif
