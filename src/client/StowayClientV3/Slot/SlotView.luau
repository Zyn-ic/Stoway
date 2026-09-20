--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Hydrates a slot frame from the skin template. Handles icon, stack
	count, rarity color, equipped state and keybind. Used by all layouts.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Colors = require(ReplicatedStorage.Shared.Stoway.Colors)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local Query = require(script.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local ClientEvents = require(script.Parent.Parent.Controller.ClientEvents)
local PointerDragService = require(script.Parent.Parent.Interactions.PointerDragService)

local SlotView = {}

-----------------------------
-- TYPES --
-----------------------------

export type DragLike = PointerDragService.Service

export type SlotProps = {
	SlotType: CoreTypes.SlotType,
	SlotIndex: number,
	Parent: Instance,
	Template: Frame,
	Store: typeof(ClientStore),
	ShowKeybind: boolean?,
	HasBind: boolean?,
	HideChrome: { string }?,
	PackOrder: Fusion.Computed<number>?,
	Keybind: Fusion.Computed<string>?,
	Visibility: Fusion.Computed<boolean>?,
	DragService: DragLike?,
	GlowSpread: UDim2?,
	Hooks: CoreTypes.HookMap?,
}

local UNBOUND_KEYBIND_COLOR = Color3.fromRGB(255, 85, 85)
local LOCKED_KEYBIND_COLOR = Color3.fromRGB(255, 190, 80)

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function SlotView.Create(scope: Fusion.Scope<typeof(Fusion)>, props: SlotProps): Frame
	local slotFrame = props.Template:Clone()
	slotFrame.Name = props.SlotType .. "-" .. tostring(props.SlotIndex)
	slotFrame.Parent = props.Parent
	table.insert(scope, slotFrame)

	local store = props.Store

	-- Skin-declared chrome visibility: hide listed direct children (deco
	-- overlays) per slot type. Ghost inherits via clone, so ghost/live stay
	-- consistent. Absent list = everything visible (legacy behavior).
	local hideChrome: { string }? = props.HideChrome
	if hideChrome then
		for _, name in hideChrome do
			local node = slotFrame:FindFirstChild(name)
			if node and node:IsA("GuiObject") then node.Visible = false end
		end
	end

	local slotbutton = slotFrame:FindFirstChild("slotbutton") :: ImageButton?
	local stackcount = slotFrame:FindFirstChild("stackcount") :: TextLabel?
	local slotnumber = slotFrame:FindFirstChild("slotnumber") :: TextLabel?
	local selecticon = slotFrame:FindFirstChild("selecticon") :: GuiObject?
	local rarityframe = slotFrame:FindFirstChild("rarityframe") :: ImageLabel?

	local hotbarSlotUUID = scope:Computed(function(use: Fusion.Use): string?
		local hotbar: { [number]: string? } = use(store.Hotbar)
		return Query.getHotbarUUID(hotbar, props.SlotIndex)
	end)

	local storageSlotUUID = scope:Computed(function(use: Fusion.Use): string?
		local storage: { string } = use(store.Storage)
		return Query.getStorageUUID(storage, props.SlotIndex)
	end)

	local slotUUID = scope:Computed(function(use: Fusion.Use): string?
		if props.SlotType == "Hotbar" then
			return use(hotbarSlotUUID)
		end
		return use(storageSlotUUID)
	end)

	local currentItem = scope:Computed(function(use: Fusion.Use): CoreTypes.Item?
		local items: { [string]: CoreTypes.Item } = use(store.Items)
		local uuid: string? = use(slotUUID)
		return Query.getItem(items, uuid)
	end)

	local hasItem = scope:Computed(function(use: Fusion.Use): boolean
		return use(currentItem) ~= nil
	end)

	local isEquipped = scope:Computed(function(use: Fusion.Use): boolean
		local uuid: string? = use(slotUUID)
		local equipped: string? = use(store.EquippedItemUUID)
		return Query.isEquipped(equipped, uuid)
	end)

	-- New-item glow: rendered iff the occupying item carries the IsNew
	-- metadata flag. Equip deletes the key via updateMetadata, which takes
	-- the glow off. Pure presence check, no side state.
	local isNew = scope:Computed(function(use: Fusion.Use): boolean
		local item: CoreTypes.Item? = use(currentItem)
		return item ~= nil and item.Metadata ~= nil and item.Metadata.IsNew == true
	end)

	local hasImage = scope:Computed(function(use: Fusion.Use): boolean
		local item: CoreTypes.Item? = use(currentItem)
		return item ~= nil and item.Metadata ~= nil and item.Metadata.Image ~= nil and item.Metadata.Image ~= ""
	end)

	local fallbackText = scope:Computed(function(use: Fusion.Use): string
		local item: CoreTypes.Item? = use(currentItem)
		if not item then return "" end
		local id = item.Id or "?"
		if #id > 12 then return string.sub(id, 1, 10) .. ".." end
		return id
	end)

	if slotbutton then
		local fallbackLabel = scope:New("TextLabel") {
			Name = "fallbacklabel",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.72),
			ZIndex = 2,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.2,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			Parent = slotbutton,
		}
		scope:New("UITextSizeConstraint") {
			MaxTextSize = 18,
			MinTextSize = 7,
			Parent = fallbackLabel,
		}
		scope:New("UIPadding") {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = fallbackLabel,
		}

		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use: Fusion.Use): string
				local item: CoreTypes.Item? = use(currentItem)
				return if item and item.Metadata then item.Metadata.Image or "" else ""
			end),
			ImageTransparency = scope:Computed(function(use: Fusion.Use): number
				return if use(hasImage) then 0 else 1
			end),
			Visible = hasItem,
		}

		scope:Hydrate(fallbackLabel) {
			Text = fallbackText,
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				return use(hasItem) and not use(hasImage)
			end),
			TextColor3 = scope:Computed(function(use: Fusion.Use): Color3
				local item: CoreTypes.Item? = use(currentItem)
				-- Use rarity tint for fallback text so color-blind still has Id, but hue helps
				return Colors.getRarityColor(item and item.Metadata and item.Metadata.Rarity)
			end),
		}

		-- Tap/Activated to equip (covers Mouse, Touch, and Gamepad ButtonA via
		-- GuiService.SelectedObject + Activated). Guard against firing right
		-- after a drag so a drag-release doesn't also equip.
		local dragService = props.DragService
		table.insert(
			scope,
			slotbutton.Activated:Connect(function()
				if dragService ~= nil then
					if dragService:IsDragging() then return end
					if dragService:WasRecentlyDragging(0.25) then return end
				end
				local uuid: string? = Fusion.peek(slotUUID)
				if not uuid then return end
				local has: boolean = Fusion.peek(hasItem)
				if not has then return end
				ClientEvents.SlotClicked:Fire(props.SlotType, props.SlotIndex, uuid)
				ClientEvents.CallHook(props.Hooks, "OnSlotClick", props.SlotType, props.SlotIndex, uuid)
				local equipped: string? = Fusion.peek(store.EquippedItemUUID)
				if equipped == uuid then
					ClientController.Unequip()
				else
					ClientController.Equip(uuid)
				end
			end)
		)

		-- Hover hook: fires on hover begin. Skin function is spawned
		-- (stock OnSlotHover yields on its tween), never blocking input.
		table.insert(
			scope,
			slotbutton.MouseEnter:Connect(function()
				ClientEvents.SlotHovered:Fire(props.SlotType, props.SlotIndex)
				ClientEvents.CallHook(props.Hooks, "OnSlotHover", slotbutton, props.SlotType, props.SlotIndex)
			end)
		)

		-- New-item glow: soft white halo behind the cell via UIShadow.
		-- Pulse is a slow breathe (0.51 <-> 0.66). On equip the IsNew
		-- flag is deleted; we tween Transparency to 1 once instead of
		-- snapping off. Parent is the CELL so the button draws above
		-- the shadow — opaque Default button occludes cleanly (behind
		-- glow), transparent Modern/Metal no longer light up.
		local newGlow = scope:New("UIShadow") {
			Name = "NewGlow",
			Color = Color3.new(1, 1, 1),
			Transparency = 0.58,
			BlurRadius = UDim.new(0.3, 0),
			Spread = props.GlowSpread or UDim2.new(0.05, 0, 0.05, 0),
			Offset = UDim2.new(0, 0, 0, 0),
			Parent = slotFrame,
		} :: UIShadow
		-- Oscillator must NOT be a Fusion cycle (ancestor write from
		-- descendant observer). Breathe uses TweenService Completed
		-- callbacks; one-shot fade on unequip is a simple tween.
		-- Fusion stays for the selecticon pop (acyclic: isEquipped -> tween).
		newGlow.Enabled = Fusion.peek(isNew)
		local pulsing = false
		local currentTween: Tween? = nil
		local function pulse(to: number)
			if not Fusion.peek(isNew) then
				pulsing = false
				return
			end
			pulsing = true
			local tween = TweenService:Create(
				newGlow,
				TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = to }
			)
			table.insert(scope, tween)
			table.insert(
				scope,
				tween.Completed:Connect(function()
					pulse(if to < 0.58 then 0.66 else 0.51)
				end)
			)
			tween:Play()
			currentTween = tween
		end
		if Fusion.peek(isNew) then pulse(0.66) end
		scope:Observer(isNew):onChange(function()
			if Fusion.peek(isNew) then
				newGlow.Enabled = true
				newGlow.Transparency = 0.58
				if not pulsing then pulse(0.66) end
			else
				if currentTween then currentTween:Cancel() end
				pulsing = false
				newGlow.Enabled = true
				local fade = TweenService:Create(
					newGlow,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1 }
				)
				table.insert(scope, fade)
				table.insert(
					scope,
					fade.Completed:Connect(function()
						if not Fusion.peek(isNew) then newGlow.Enabled = false end
					end)
				)
				fade:Play()
			end
		end)
	end

	if rarityframe then
		-- Tint both channels: ImageColor3 drives image-art frames, BackgroundColor3
		-- drives native bars (imageless templates tint via background).
		local rarityColor: Fusion.Computed<Color3> = scope:Computed(function(use: Fusion.Use): Color3
			local item: CoreTypes.Item? = use(currentItem)
			return Colors.getRarityColor(item and item.Metadata and item.Metadata.Rarity)
		end)
		scope:Hydrate(rarityframe) {
			ImageColor3 = rarityColor,
			BackgroundColor3 = rarityColor,
			Visible = hasItem,
		}
	end

	if stackcount then
		-- Keep badge inside the cell and tilted for readability.
		if props.SlotType == "Storage" then
			stackcount.AnchorPoint = Vector2.new(1, 1)
			stackcount.Position = UDim2.new(1, -3, 1, -3)
			stackcount.Size = UDim2.fromOffset(30, 22)
			stackcount.ZIndex = 3
			stackcount.Rotation = -15
		elseif props.SlotType == "Hotbar" then
			stackcount.AnchorPoint = Vector2.new(1, 1)
			stackcount.Position = UDim2.new(1, -2, 1, -2)
			stackcount.Size = UDim2.fromOffset(32, 18)
			stackcount.ZIndex = 3
			stackcount.Rotation = -15
		else
			stackcount.Rotation = -15
		end
		scope:Hydrate(stackcount) {
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				local item: CoreTypes.Item? = use(currentItem)
				local settings: CoreTypes.Settings? = use(store.Settings)
				return settings ~= nil and settings.CanStack and item ~= nil
			end),
			Text = scope:Computed(function(use: Fusion.Use): string
				local item: CoreTypes.Item? = use(currentItem)
				if item then
					return Query.formatAmount(item.Amount)
				end
				return ""
			end),
		}
	end

	if slotnumber then
		-- Captured once: the fallback below must return this, never the
		-- live property. Reading slotnumber.TextColor3 live inside the
		-- Computed self-perpetuates (once amber, amber forever).
		local defaultKeybindColor: Color3 = slotnumber.TextColor3
		scope:Hydrate(slotnumber) {
			Text = props.Keybind or "",
			Visible = props.ShowKeybind == true,
			-- EXAMPLE (example/locked-slots): amber while a keyed hotbar
			-- slot is locked, red "!" when keyless. Depth-1 reactive: reads
			-- atoms directly.
			TextColor3 = scope:Computed(function(use: Fusion.Use): Color3
				if props.HasBind == true and props.SlotType == "Hotbar" then
					local settings: CoreTypes.Settings? = use(props.Store.Settings)
					if not Query.isHotbarSlotUnlocked(settings, props.SlotIndex) then
						return LOCKED_KEYBIND_COLOR
					end
				elseif props.HasBind == false then
					return UNBOUND_KEYBIND_COLOR
				end
				return defaultKeybindColor
			end),
		}
	end

	if selecticon then
		-- Visual feedback via Fusion tween: tiny delay then Back pop on equip,
		-- instant off on unequip. isEquipped stays source of truth.
		local origSize: UDim2 = selecticon.Size
		local origTransparency: number = 0
		if selecticon:IsA("ImageLabel") then
			origTransparency = selecticon.ImageTransparency
		end
		local smallSize = UDim2.new(origSize.X.Scale * 0.85, origSize.X.Offset, origSize.Y.Scale * 0.85, origSize.Y.Offset)
		local equipProgress: Fusion.Value<number> = scope:Value(0)
		local tweened: Fusion.Tween<number> = scope:Tween(
			equipProgress,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.06)
		)
		local popSize: Fusion.Computed<UDim2> = scope:Computed(function(use: Fusion.Use): UDim2
			local t: number = use(tweened)
			local sx: number = smallSize.X.Scale + (origSize.X.Scale - smallSize.X.Scale) * t
			local sy: number = smallSize.Y.Scale + (origSize.Y.Scale - smallSize.Y.Scale) * t
			return UDim2.new(sx, origSize.X.Offset, sy, origSize.Y.Offset)
		end)
		local popTransparency: Fusion.Computed<number> = scope:Computed(function(use: Fusion.Use): number
			local t: number = use(tweened)
			return 1 + (origTransparency - 1) * t
		end)
		scope:Hydrate(selecticon) {
			Visible = isEquipped,
			Size = popSize,
			ImageTransparency = popTransparency,
		}
		if Fusion.peek(isEquipped) then equipProgress:set(1) end
		scope:Observer(isEquipped):onChange(function()
			if Fusion.peek(isEquipped) then
				equipProgress:set(1)
				ClientEvents.Selected:Fire(props.SlotType, props.SlotIndex)
				ClientEvents.CallHook(props.Hooks, "OnSelect", slotFrame, props.SlotType, props.SlotIndex)
			else
				equipProgress:set(0)
				ClientEvents.Deselected:Fire(props.SlotType, props.SlotIndex)
				ClientEvents.CallHook(props.Hooks, "OnDeselect", slotFrame, props.SlotType, props.SlotIndex)
			end
		end)
	end

	if props.PackOrder then
		scope:Hydrate(slotFrame) {
			LayoutOrder = props.PackOrder,
		}
	else
		slotFrame.LayoutOrder = props.SlotIndex
	end

	if props.Visibility then
		scope:Hydrate(slotFrame) {
			Visible = props.Visibility,
		}
	end

	return slotFrame
end

-----------------------------
-- MAIN --
-----------------------------

return SlotView
