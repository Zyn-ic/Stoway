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
4. <img src="data:image/png;base64,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" width=17 heigh=17> [**Illusion**](https://devforum.roblox.com/t/illusions-inputactionsystem-currently-the-best-input-manager/4071242) for creating a module around roblox's new InputActionService *thank you this saved me a lot of time* 😭
