// unity_project/Assets/Scripts/CharacterLoader.cs
// Loads, validates, and manages runtime character sheet state in Unity 6 using JsonUtility.
// Connects to: unity_project/Assets/Resources/Data/CharacterData.json, unity_project/Assets/Scripts/Editor/UnityBatchmodeBridge.cs
// Created: 2026-10-24

using UnityEngine;
using System.IO;
using System; // Required for [System.Serializable]
using System.Collections.Generic; // Required for List<>

// Define data structures to match the JSON schema
// These are defined OUTSIDE the CharacterLoader class to be accessible project-wide

[System.Serializable]
public class CharacterAttributes
{
    public int strength;
    public int dexterity;
    public int constitution;
    public int intelligence;
    public int wisdom;
    public int charisma;
}

[System.Serializable]
public class CharacterSkill
{
    public string name;
    public int rank;
    public string modifier;
}

[System.Serializable]
public class CharacterInventoryItem
{
    public string item_id;
    public string name;
    public int quantity;
}

[System.Serializable]
public class CharacterHealth
{
    public int current;
    public int max;
}

[System.Serializable]
public class CharacterMana
{
    public int current;
    public int max;
}

[System.Serializable]
public class CharacterBackstory
{
    public string summary;
    public string alignment;
}

[System.Serializable]
public class CharacterSheet
{
    public string character_id;
    public string name;
    public string race;
    public string character_class;
    public int level;
    public CharacterHealth health;
    public CharacterMana mana;
    public CharacterAttributes attributes;
    public List<CharacterSkill> skills;
    public List<CharacterInventoryItem> inventory;
    public CharacterBackstory backstory;
}

public class CharacterLoader : MonoBehaviour
{
    public const string DefaultResourcePath = "Data/CharacterData";
    public const int BaseAttributeScore = 10;
    public const int AttributeModifierDivisor = 2;
    public const int LevelUpHpGain = 8;
    public const int LevelUpManaGain = 4;

    public CharacterSheet CurrentCharacter { get; private set; }

    void Start()
    {
        LoadCharacterData(DefaultResourcePath);
    }

    /// <summary>
    /// Loads and deserializes a CharacterSheet from Unity Resources using native JsonUtility.
    /// </summary>
    public CharacterSheet LoadCharacterData(string pathInResources)
    {
        TextAsset jsonFile = Resources.Load<TextAsset>(pathInResources);
        if (jsonFile != null)
        {
            CurrentCharacter = ParseAndValidateJson(jsonFile.text);
            if (CurrentCharacter != null)
            {
                Debug.Log("Successfully loaded character: " + CurrentCharacter.name);
                Debug.Log("Class: " + CurrentCharacter.character_class + ", Level: " + CurrentCharacter.level);
                Debug.Log("Strength: " + CurrentCharacter.attributes.strength);
                if (CurrentCharacter.skills != null && CurrentCharacter.skills.Count > 0)
                {
                    Debug.Log("First Skill: " + CurrentCharacter.skills[0].name);
                }
            }
            return CurrentCharacter;
        }
        else
        {
            Debug.LogError("Failed to load character data from path: " + pathInResources);
            return null;
        }
    }

    /// <summary>
    /// Parses raw JSON text into a CharacterSheet and validates required fields.
    /// </summary>
    public static CharacterSheet ParseAndValidateJson(string jsonText)
    {
        if (string.IsNullOrWhiteSpace(jsonText))
        {
            Debug.LogError("Character JSON text is empty.");
            return null;
        }

        CharacterSheet sheet = JsonUtility.FromJson<CharacterSheet>(jsonText);
        if (sheet == null || string.IsNullOrEmpty(sheet.character_id) || string.IsNullOrEmpty(sheet.name))
        {
            Debug.LogError("Schema validation failed: missing character_id or name.");
            return null;
        }
        return sheet;
    }

    /// <summary>
    /// Calculates standard RPG attribute modifier: floor((score - 10) / 2).
    /// Matches Godot character_loader.gd 1:1.
    /// </summary>
    public static int GetAttributeModifier(int score)
    {
        return Mathf.FloorToInt((score - BaseAttributeScore) / (float)AttributeModifierDivisor);
    }

    /// <summary>
    /// Increments character level, boosts max HP/Mana, and adds +1 Dexterity.
    /// </summary>
    public void ApplyLevelUp()
    {
        if (CurrentCharacter == null) return;
        CurrentCharacter.level += 1;
        if (CurrentCharacter.health != null)
        {
            CurrentCharacter.health.max += LevelUpHpGain;
            CurrentCharacter.health.current = CurrentCharacter.health.max;
        }
        if (CurrentCharacter.mana != null)
        {
            CurrentCharacter.mana.max += LevelUpManaGain;
            CurrentCharacter.mana.current = CurrentCharacter.mana.max;
        }
        if (CurrentCharacter.attributes != null)
        {
            CurrentCharacter.attributes.dexterity += 1;
        }
    }
}
