# Stoway - Advanced Roblox Inventory System (V2.x Dev) 🎒✨
<img src="pics/Logo.png" alt="Stoway Logo" width="120" align = "left" style="margin-right:15px"/> 

<div style="display: flex; flex-direction: column; gap: 2px;">
<p> <strong>Stoway V2</strong> is the next evolution of the Stoway inventory system. This branch is currently in active development, focusing on a complete overhaul of the input handling architecture using <strong>IllusionIAS</strong>. This update aims to provide robust, context-aware keybindings, full console controller support, and dynamic runtime rebinding capabilities.</p>
</div>

<br>

> ⚠️ **Development Branch**: This is the `version-2.x.x` branch. Features here are experimental and subject to change. For the stable release, please see the `main` branch (V1.2).

## 📖 Table of Contents

- [Stoway - Advanced Roblox Inventory System (V2.x Dev) 🎒✨](#stoway---advanced-roblox-inventory-system-v2x-dev-)
  - [📖 Table of Contents](#-table-of-contents)
  - [🆕 What's New in V2? ](#-whats-new-in-v2-)
    - [🎮 Advanced Input Manager ](#-advanced-input-manager-)
  - [🌟 Core Features (Inherited from V1) ](#-core-features-inherited-from-v1-)
  - [🚀 Getting Started (V2 Dev) ](#-getting-started-v2-dev-)
  - [Credits](#credits)

<br>

## 🆕 What's New in V2? <a name="whats-new-in-v2"></a>

### 🎮 Advanced Input Manager <a name="advanced-input-manager"></a>
*   **IllusionIAS Integration:** We have migrated away from basic UserInputService checks to `IllusionIAS`, a powerful input action system.
*   **Context-Aware Controls:** Inputs are now scoped to the `StowayGameplay` context, preventing conflicts with other game systems or UI.
*   **Dynamic Rebinding:** The new `InputManager` allows for real-time updating of keybinds without reloading the character.
*   **Cross-Platform Ready:** Native support structure for PC and Console bindings within the `Binds` configuration.

<br>

## 🌟 Core Features (Inherited from V1) <a name="core-features"></a>

*   **🔥 Hotbar:** Smooth drag & drop, static slots, and reactive state.
*   **🎒 Backpack / Storage:** Data-driven UUID system, stacking, weight limits, and sorting.
*   **⚙️ Advanced Systems:** Fusion-powered UI, Delta Replication, and Custom UI Skins.

<br>

## 🚀 Getting Started (V2 Dev) <a name="getting-started"></a>

1.  **Dependencies:** Ensure you have the `IllusionIAS` package installed in `ReplicatedStorage/Packages`.
2.  **Setup:**
    *   Follow standard V1 setup procedures.
    *   Verify `InputManager.luau` is initialized by `StowayClient`.

*(Detailed V2 documentation will be added as features stabilize)*

---

## Credits

1. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15>  [**HowToRoblox**](https://www.youtube.com/watch?v=kqa4u_9mSTQ&list=WL&index=6) - Core mechanics inspiration.
2. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15> [**Knineteen19**](https://www.youtube.com/watch?v=d2tdaRmqGXI&list=WL&index=8) - Persistence and stacking logic.
3. <img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/4X/5/2/b/52bce3b02f6c5dddf9dfd5390fa00a9b2be6fa38.png" width=17 height = 17> [**Avafe**](https://devforum.roblox.com/t/neohotbar-a-modern-customizable-backpack/2738850) - Fusion and React patterns on Roblox.
