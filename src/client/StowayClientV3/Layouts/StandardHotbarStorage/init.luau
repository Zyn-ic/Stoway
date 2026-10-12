--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StandardHotbarStorage layout. Combines the hotbar and storage views.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local PointerDragService = require(script.Parent.Parent.Interactions.PointerDragService)

local HotbarView = require(script.HotbarView)
local StorageView = require(script.StorageView)
local LayoutInput = require(script.Input)
local Shared = require(script.Parent.Shared)

local StandardHotbarStorage = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StandardHotbarStorage.Mount(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	local draggingGui = Shared.ensureDraggingGui(scope, skin)

	local dragService = PointerDragService.new(
		scope,
		draggingGui,
		function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef?, context: PointerDragService.DragContext)
			local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
			local backpackEnabled = settings == nil or settings.BackpackEnabled ~= false
			local hotbarType: CoreTypes.HotbarType = if settings then settings.HotbarType else "Static"

			-- Guard: storage-involved drags when backpack disabled
			if not backpackEnabled then
				if from.Type == "Storage" then return false end
				if to and to.Type == "Storage" then return false end
				if context.overBackpack then return false end
			end

			if to then
				if from.Type == to.Type and from.Slot == to.Slot then return false end
				local destHasItem = Shared.hasDestItem(store, to)
				if destHasItem then
					-- Occupied -> Swap (StackOnSwap can stack; Move would reject DESTINATION_OCCUPIED)
					return Shared.handleSwap(from, to)
				else
					-- Empty slot -> Move (never stacks). Fallback to Swap if Move rejects (e.g. Static HH empty via Move is allowed but keep fallback)
					local res = ClientController.Move(from, to)
					if not res.ok then
						warn("[StandardHotbarStorage] Move rejected", res.error and res.error.message or tostring(res))
						if res.error and res.error.message == "DESTINATION_UNAVAILABLE" then
							-- Dynamic hotbar empty-hole guard already handled by Operations; try Swap as fallback only for Static
							if hotbarType == "Static" then return Shared.handleSwap(from, to) end
						end
						return false
					end
					return true
				end
			end

			-- No slot hit: empty-area vs outside
			if context.overBackpack and from.Type == "Hotbar" and backpackEnabled then
				-- AddToBackpack: Hotbar -> Storage append (Move HS path ignores dest slot and appends)
				local storage: { string } = Fusion.peek(store.Storage)
				local appendSlot = #storage + 1
				return Shared.handleMove(from, { Type = "Storage", Slot = appendSlot })
			end

			if context.overHotbar and from.Type == "Storage" and hotbarType == "Dynamic" then
				-- Dynamic hotbar: dropping storage item over hotbar background inserts at first empty hotbar slot
				local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
				local maxSlots = if settings then settings.MaxHotbarSlots else 10
				local appendSlot: number? = nil
				for i = 1, maxSlots do
					if hotbar[i] == nil then
						appendSlot = i
						break
					end
				end
				if appendSlot then return Shared.handleSwap(from, { Type = "Hotbar", Slot = appendSlot }) end
				return false
			end

			if not context.overBackpack and not context.overHotbar then
				-- Outside both -> proper Drop: request only, the server
				-- validates, spawns the world Tool, and pushes Removed.
				local uuid: string? = nil
				if from.Type == "Hotbar" then
					local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
					uuid = hotbar[from.Slot]
				else
					local storage: { string } = Fusion.peek(store.Storage)
					uuid = storage[from.Slot]
				end
				if uuid then
					ClientController.RequestDrop(uuid)
				end
				return true
			end
			return false
		end,
		skin.SlotTemplate,
		skin.BackpackFrame,
		skin.HotbarFrame,
		skin.GhostHidden,
		skin.Hooks
	)

	-- Controller wrapper events (swap/remove/add/equip/unequip) fire the
	-- generic bus + skin hooks on res.ok. Set per mount; next Mount
	-- overwrites, Teardown leaves the last skin's table (harmless:
	-- all hook calls are pcall'd against live-or-destroyed instances).
	ClientController.SetHooks(skin.Hooks)

	HotbarView.Create(scope, skin, store, dragService)
	StorageView.Create(scope, skin, store, dragService)
	-- Modular input: layout-owned IAS binds + PreferredInput bus + console modes
	LayoutInput.Mount(scope, skin, store, dragService)
end

-----------------------------
-- MAIN --
-----------------------------

return StandardHotbarStorage
