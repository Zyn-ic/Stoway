# Stoway - Advanced Roblox Inventory System 🎒✨
<img src="pics/Logo.png" alt="Stoway Logo" width="120" align = "left" style="margin-right:15px"/> 

<div style="display: flex; flex-direction: column; gap: 2px;">
<p> <strong>Stoway</strong> is a flexible and feature-rich inventory and hotbar system designed for Roblox experiences. It provides developers with a robust framework to manage player items, offering deep customization for various gameplay needs, from simple backpacks to complex, data-driven inventories. Please consider going to the <a href="https://github.com/Zyn-ic/Stoway/releases">latest release</a> and downloading it there if you want a view at a basic set up.</p>
</div>

<br>

## 📖 Table of Contents

- [Stoway - Advanced Roblox Inventory System 🎒✨](#stoway---advanced-roblox-inventory-system-)
  - [📖 Table of Contents](#-table-of-contents)
  - [🌟 Core Features ](#-core-features-)
    - [🔥 Hotbar ](#-hotbar-)
    - [🎒 Backpack / Inventory ](#-backpack--inventory-)
    - [⚙️ Extra Functionalities ](#️-extra-functionalities-)
  - [🚀 Getting Started ](#-getting-started-)
  - [🛠️ Configuration ](#️-configuration-)
- [Credits](#credits)

<br>

## 🌟 Core Features <a name="core-features"></a>

Stoway aims to provide a comprehensive set of features to cover all your inventory needs.

### 🔥 Hotbar <a name="hotbar"></a>

The hotbar is designed for quick access and intuitive item management.

* **🖐️ Drag & Drop UI:** Seamlessly move items within the hotbar and between the hotbar and backpack.
* **🔁 Swappable Slots:** Easily swap the contents of two slots by dragging one onto another.
* **📚 Stacking:** Configure items to stack, with customizable maximum stack sizes per item type or globally.
* **💾 Persistence Options (Savable):**
    * **Always Save:** Item data in hotbar slots persists through death and across sessions.
    * **Session/Life Specific:** If disabled, hotbar can be configured to reset upon player death or when they leave the game.
* **↔️ Static or Dynamic Display:**
    * **Static:** A fixed number of hotbar slots are always visible.
    * **Dynamic:** The hotbar can visually expand or shrink to only show slots that contain items.

---

### 🎒 Backpack / Inventory <a name="backpack-inventory"></a>

The backpack serves as the main storage, with flexible operational modes.

* **📦 Dual Mode Operation:**
    * **`Backpack Mode`**: All tool instances (both hotbar and backpack items) are physically stored in the player's Roblox `Backpack` instance. Stoway manages their organization and data.
    * **`Inventory Mode`**: Only tools equipped or on the hotbar are in the player's Roblox `Backpack` instance. Other items are managed as data by Stoway on the server, allowing for larger and more abstract storage.
* **⚖️ Item Limit:** Set a total carrying capacity (e.g., by weight or item count) that considers items in both the hotbar and the backpack. `0` can signify an infinite limit.
* **🖐️ Drag & Drop UI:** Intuitive drag and drop functionality within the backpack interface.
* **🔄 Hotbar <-> Backpack Swapping:** Drag an item from the hotbar to a backpack slot (or vice-versa) will swap positions.
* **📊 Sorting:** Option to implement sorting functionality for the backpack based on specific categories (e.g., item type, rarity, name).

---

### ⚙️ Extra Functionalities <a name="extra-functionalities"></a>

Enhance player interaction and item management with these powerful extras.

* **⌨️ Bind Key Actions:**
    * Select a slot/item in the hotbar or backpack.
    * Press a predefined key (e.g., `Backspace`, `Delete`, `E`).
    * Trigger custom functions like deleting, selling, dropping, or using the item.
* **✨ Bound Visual Functions (On Select):**
    * Purely for cosmetics and visual feedback.
    * When a slot/item is selected, automatically run a function without needing an additional key press.
    * Use cases: Tweening the selected slot's color, showing a `ViewportFrame` preview of the item, displaying item stats, etc.
* **💧 Droppable Items:**
    * Option to designate items as droppable.
    * Drag a slot/item to a specific "droppable UI frame" or a droppable position on the 2d Interface.
    * Dropping resets the slot to empty or removes the visual slot if the hotbar/backpack is dynamic.
* **💎 Rarity Check & Display:**
    * If enabled, Stoway can check for a "Rarity" attribute on tools.
    * Apply a corresponding color or visual indicator to a designated "rarity frame" or element within the item's UI display.

<br>

## 🚀 Getting Started <a name="getting-started"></a>

Setting up Stoway in your Roblox game is straightforward:

1.  📥 **Download:** Grab the latest release from the [Releases](https://github.com/Zyn-ic/Stoway/releases) page (or clone the repository).
2.  📦 **Import:** Import the `.rbxm` model file into Roblox Studio.
3.  📁 **Placement:**
    * Place the `StowayServer` ModuleScript (and its children like `Settings`) into `ServerScriptService` (e.g., `ServerScriptService.Stoway.StowayServer`).
    * Place shared modules like `Types` into `ReplicatedStorage` (e.g., `ReplicatedStorage.Shared.Types`).
    * Place the `StowayClient` ModuleScript (and its children) into
    `StarterPlayerScripts` (e.g `StarterPlayerScripts.Stoway.StowayClient`).
    * Ensure any client-side UI and scripts are placed appropriately (e.g., in `StarterGui` `StarterPlayerScripts`, `ReplicatedStorage`).
4.  ⚙️ **Configure:** Modify the `Settings.lua` module to tailor Stoway to your game's needs (see [Configuration](#️-configuration) below).
5.  🏁 **Initialize:** In a server-side script (e.g., `ServerScriptService.GameManager`), initialize the system:
    ```lua
    -- Example: ServerScriptService/GameManager.lua
    require(game.ServerScriptService.Stoway.StowayServer)
    ```

---

## 🛠️ Configuration <a name="configuration"></a>

Stoway's behavior is heavily controlled by the `Settings.lua` module. This allows you to easily tweak functionality without digging deep into the core scripts.

```lua

-- Example snippet from Settings.lua

local Settings = {}
-- ... Types module requirement ...

Settings.HotbarSettings = {
    HotbarType = Types.HotbarType.Static, -- "Static" or "Dynamic"
    MaxSlots = 9
}

Settings.BackpackSettings = {
    CarryingType = Types.CarryingType.Backpack, -- "Backpack" or "Inventory"
    Limit = 50, -- 0 for infinite
    Sorting = false -- true to enable sorting logic placeholder
}

Settings.CanStack = true
Settings.MaxStackCount = 64 -- maximum amount a item can stack to

Settings.RarityCheck = true
Settings.Droppable = true
Settings.SaveBackpackandSlotInfo = false -- Toggle data persistence

Settings.Bindkey = {
    [tostring(Enum.KeyCode.Delete)] = function(slotContents)
        print(player.Name .. " wants to delete:", slotContents.Properties.Type)
        --[[ remember this runs on the client so if you want to delete
        something then you will have to implement it on both sides
        ]]
    end
}

Settings.BindFunction = function(slotContents, slotGuiObject)
    print("Selected:", slotContents.Properties.Type)
    -- think of the parameters as anything you want to pass from the frame/button selected on the client
end

return Settings
```

# Credits

1. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15>  [**HowToRoblox**](https://www.youtube.com/watch?v=kqa4u_9mSTQ&list=WL&index=6) - sourced a lot of core mechanics from him for backpack/hotbar.
2. <img src="https://www.iconpacks.net/icons/2/free-youtube-logo-icon-2431-thumb.png" width=15 height = 15> [**Knineteen19**](https://www.youtube.com/watch?v=d2tdaRmqGXI&list=WL&index=8) - his series helped me get a good understanding for inventory/hotbar, presistance, and stacking.
3. <img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/4X/5/2/b/52bce3b02f6c5dddf9dfd5390fa00a9b2be6fa38.png" width=17 height = 17> [**Avafe**](https://devforum.roblox.com/t/neohotbar-a-modern-customizable-backpack/2738850) - learned about the existance of [fusion and react](https://www.youtube.com/watch?v=OHqMLEL5QnY&t=1730s) on roblox from this custom hotbar and backpack system.