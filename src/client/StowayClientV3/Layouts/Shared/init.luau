--!strict

--@author: yyumchi
--@date: 2026-10-12
--[[@description:
	Shared layout helpers. Both HotbarType engines (StandardHotbarStorage,
	JailbreakHotbar) had their own copies of these; a single module holds
	them so behavior can't drift between layouts. Layout-specific commit
	rules (Standard's empty-area handling, Jailbreak's sweep) stay in the
	engines and call into these primitives.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local State = require(script.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)

local Shared = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Shared.getMaxSlots(store: typeof(ClientStore)): number
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return State.getMaxHotbarSlots(settings)
end

function Shared.isBackpackEnabled(store: typeof(ClientStore)): boolean
	local s: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return s == nil or s.BackpackEnabled ~= false
end

function Shared.hasDestItem(store: typeof(ClientStore), target: CoreTypes.SlotRef): boolean
	if target.Type == "Hotbar" then
		local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
		return hotbar[target.Slot] ~= nil
	else
		local storage: { string } = Fusion.peek(store.Storage)
		return storage[target.Slot] ~= nil
	end
end

function Shared.handleSwap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): boolean
	local res = ClientController.Swap(from, to)
	if not res.ok then
		warn("[Layouts/Shared] Swap rejected", res.error and res.error.message or tostring(res))
	end
	return res.ok
end

function Shared.handleMove(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): boolean
	local res = ClientController.Move(from, to)
	if not res.ok then
		warn("[Layouts/Shared] Move rejected", res.error and res.error.message or tostring(res))
	end
	return res.ok
end

function Shared.doEquipSlot(store: typeof(ClientStore), visibleIndex: number)
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
	local items: { [string]: CoreTypes.Item } = Fusion.peek(store.Items)
	local hotbarType = if settings then settings.HotbarType else "Static"
	local uuid: string?
	if hotbarType == "Dynamic" then
		-- visibleIndex 1.. is packOrder; map to actual slot uuid
		for slot = 1, Shared.getMaxSlots(store) do
			if Query.packedHotbarOrder(hotbar, items, slot, true) == visibleIndex then
				uuid = hotbar[slot]
				break
			end
		end
	else
		uuid = hotbar[visibleIndex]
	end
	if not uuid then
		if Fusion.peek(store.EquippedItemUUID) ~= nil then
			ClientController.Unequip()
		end
		return
	end
	local equipped: string? = Fusion.peek(store.EquippedItemUUID)
	if equipped == uuid then
		ClientController.Unequip()
	else
		ClientController.Equip(uuid)
	end
end

function Shared.ensureDraggingGui(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle): ScreenGui
	local existingDragging = skin.DraggingGui
		or (skin.Gui and (skin.Gui:FindFirstChild("DraggingGui") :: ScreenGui?))
	if existingDragging then
		existingDragging.IgnoreGuiInset = false
		return existingDragging
	end
	local created = Instance.new("ScreenGui")
	created.Name = "DraggingGui"
	created.DisplayOrder = 100
	created.IgnoreGuiInset = false
	created.Parent = skin.Gui and skin.Gui.Parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	table.insert(scope, created)
	return created
end

-----------------------------
-- MAIN --
-----------------------------

return Shared
