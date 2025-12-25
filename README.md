# Stoway - Advanced Roblox Inventory System (V1.2) 🎒✨
<img src="pics/Logo.png" alt="Stoway Logo" width="120" align = "left" style="margin-right:15px"/> 

<div style="display: flex; flex-direction: column; gap: 2px;">
<p> <strong>Stoway</strong> is a robust, data-driven inventory and hotbar system designed for Roblox experiences. Built with performance and flexibility in mind, it uses <strong>Fusion</strong> for reactive UI updates and a smart <strong>Delta Replication</strong> system to minimize network traffic. Whether you need a simple RPG backpack or a complex survival inventory, Stoway provides the solid foundation you need. Please consider going to the <a href="https://github.com/Zyn-ic/Stoway/releases">latest release</a> and downloading it there.</p>
</div>

<br>

## 📖 Table of Contents

- [Stoway - Advanced Roblox Inventory System (V1.2) 🎒✨](#stoway---advanced-roblox-inventory-system-v12-)
  - [📖 Table of Contents](#-table-of-contents)
  - [🌟 Core Features ](#-core-features-)
    - [🔥 Hotbar ](#-hotbar-)
    - [🎒 Backpack / Storage ](#-backpack--storage-)
    - [⚙️ Advanced Systems ](#️-advanced-systems-)
  - [🚀 Getting Started ](#-getting-started-)
  - [🛠️ Configuration ](#️-configuration-)
  - [💬 Debug Commands ](#-debug-commands-)
- [Credits](#credits)

<br>

## 🌟 Core Features <a name="core-features"></a>

### 🔥 Hotbar <a name="hotbar"></a>
* **🖐️ Drag & Drop:** Smooth, glitch-free dragging between Hotbar and Storage.
* **⚡ Static Slots:** Fixed number of hotbar slots (e.g., 1-9) for consistent keybinding.
* **⌨️ Keybinds:** Built-in support for equipping items via number keys.

### 🎒 Backpack / Storage <a name="backpack-storage"></a>
* **💾 Data-Driven:** Items are stored as pure data (UUIDs), not physical Instances. Physical tools are only spawned when equipped.
* **📚 Stacking:** Fully customizable stacking logic. Define max stack sizes globally or per-item.
* **⚖️ Weight System:** Optional weight/capacity limits (set specific limits or allow infinite storage).
* **🔍 Sorting & Filtering:** Built-in support for sorting by Rarity, Name, or ItemType, plus real-time search filtering.

### ⚙️ Advanced Systems <a name="advanced-systems"></a>
* **⚛️ Reactive UI (Fusion):** Uses the Fusion library for highly performant, state-driven UI updates. Zero polling.
* **📡 Delta Replication:** The server only sends *changes* to the client, ensuring minimal network usage even with large inventories.
* **🎨 UI Skins:** Support for multiple UI layouts/skins (e.g., "Default", "Admin", "Trader") that can be switched on the fly.
* **💎 Rarity Support:** Integrated rarity system with color-coded borders and sorting priority.
* **💧 Droppable Items:** Configurable logic for dropping items into the world.

<br>

## 🚀 Getting Started <a name="getting-started"></a>

1.  📥 **Download:** Get the latest `.rbxm` from the [Releases](https://github.com/Zyn-ic/Stoway/releases) page.
2.  📁 **Server Setup:**
    *   Place `StowayServerV1_2` inside `ServerScriptService`.
    *   *Recommendation:* Create a folder `ServerScriptService/Stoway` to keep it organized.
3.  📁 **Client Setup:**
    *   Place `StowayClientv1_2` inside `StarterPlayerScripts`.
4.  📁 **Shared Resources:**
    *   Place the `Shared` folder (containing `Settings`, `Types`, `RarityValues`, `Binds`) into `ReplicatedStorage`.
5.  📦 **Dependencies:**
    *   Ensure the `Fusion` library is available in `ReplicatedStorage/Packages` (or adjust the `require` paths in the scripts).
6.  🏁 **Initialize:**
    Create a server script to load the system:
    ```lua
    local StowayServer = require(game.ServerScriptService.StowayServerV1_2)
    StowayServer.Init()
    ```

---

## 🛠️ Configuration <a name="configuration"></a>

Stoway V1.2 is configured via `ReplicatedStorage/Shared/Settings.luau`.

```lua
local Settings = {}

--// HOTBAR
Settings.Hotbar = {
    MaxSlots = 9,       -- Number of static hotbar slots
}

--// STORAGE & LIMITS
Settings.Storage = {
    Limit = 50,         -- Max weight/slots (0 = Infinite)
    CanStack = true,    -- Enable item stacking
    MaxStackSize = 64,  -- Default max stack size
    Sorting = true,     -- Enable sorting logic
    SortOrder = "Rarity" -- "None", "Name", "Rarity", "ItemType"
}

--// GAMEPLAY
Settings.Gameplay = {
    Droppable = true,   -- Allow players to drop items
    DropDistance = 5,   -- How far items drop
}

--// UI SKINS
Settings.DifferentUIs = {
    ["Default"] = {
        FolderName = "DefaultUI",
        GuiName = "StowayGui",
        HookPresetName = "DefaultHooks"
    }
}

return Settings
```

<br>

## 💬 Debug Commands <a name="debug-commands"></a>
Stoway comes with built-in chat commands for testing (restrict these in production!).

*   `/inv` - Print current inventory state to console.
*   `/add [itemId] [amount]` - Add an item to your inventory.
*   `/remove [uuid]` - Remove an item by UUID.
*   `/clear` - Wipe your inventory.
*   `/set_limit [n]` - Change your weight limit at runtime.
*   `/setui [UiType]` - Switch your UI skin (e.g., `/setui Default`).

<br>
# Credits

1. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15>  [**HowToRoblox**](https://www.youtube.com/watch?v=kqa4u_9mSTQ&list=WL&index=6) - sourced a lot of core mechanics from him for backpack/hotbar.
2. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15> [**Knineteen19**](https://www.youtube.com/watch?v=d2tdaRmqGXI&list=WL&index=8) - his series helped me get a good understanding for inventory/hotbar, presistance, and stacking.
3. <img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/4X/5/2/b/52bce3b02f6c5dddf9dfd5390fa00a9b2be6fa38.png" width=17 height = 17> [**Avafe**](https://devforum.roblox.com/t/neohotbar-a-modern-customizable-backpack/2738850) - learned about the existance of [fusion and react](https://www.youtube.com/watch?v=OHqMLEL5QnY&t=1730s) on roblox from this custom hotbar and backpack system.