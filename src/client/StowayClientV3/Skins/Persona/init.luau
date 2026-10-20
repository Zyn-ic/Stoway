--!strict

--@author: yyumchi
--@date: 2026-10-20
--[[@description:
	Code-built Persona skin for the JailbreakHotbar layout. Slanted ink
	cards with white miter outlines and a red shard behind the equipped
	one, same language as the combo counter. No Studio prefab: builds the
	ScreenGui, hotbar row, storage popup, toggle button and slot template
	in Lua, and carries its own Hooks table (Persona.Hooks) so the visuals
	riding the 11 skin hooks ship with the skin.

	Slot template contract (extends the Jailbreak one):
	template (Frame)
	  plate (Frame)                -> empty-slot hint, always visible
	  teamframe (Frame)            -> shard behind the card, tinted by Metadata.Team
	  slotbutton (ImageButton)     -> ink card, item Image, FX target
	    Edge (UIStroke)            -> resting outline, flickered on hover
	    Flash (Frame)              -> white overlay, tweened by Fx.Flash
	  selecticon (ImageLabel)      -> red equipped bar (SlotView drives it,
	                                  which is also what makes OnSelect fire)
	  stackcount (TextLabel)
	  slotnumber (TextLabel)
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

local Theme = require(script.Theme)
local PersonaFx = require(script.Fx)
local PersonaHooks = require(script.Hooks)

local PersonaSkin = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local POPUP_WIDTH = 440
local POPUP_HEIGHT = 340
local SCROLL_TOP = 40
local WEIGHT_HEIGHT = 22
local POPUP_OPEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Sharp miter outline. Every Persona edge is one of these.
local function outline(
	scope: Fusion.Scope<typeof(Fusion)>,
	parent: Instance,
	color: Color3,
	thickness: number,
	name: string?
): UIStroke
	return scope:New("UIStroke") {
		Name = name or "Outline",
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Parent = parent,
	} :: UIStroke
end

-- Slanted slab: anchored centre, tilted, flat colour, no border.
local function slab(
	scope: Fusion.Scope<typeof(Fusion)>,
	name: string,
	parent: Instance,
	color: Color3,
	position: UDim2,
	size: UDim2,
	zIndex: number
): Frame
	return scope:New("Frame") {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Rotation = Theme.TILT,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	} :: Frame
end

local function label(
	scope: Fusion.Scope<typeof(Fusion)>,
	name: string,
	parent: Instance,
	textSize: number,
	zIndex: number
): TextLabel
	return scope:New("TextLabel") {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.FONT,
		TextSize = textSize,
		TextColor3 = Theme.WHITE,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.INK,
		ZIndex = zIndex,
		Parent = parent,
	} :: TextLabel
end

-- Persona slot template. SlotView clones + hydrates it per slot. ZIndex
-- ladder: plate 0 < teamframe 1 < slotbutton 2 < selecticon 3 < stackcount
-- 3 (SlotView forces it) < slotnumber 4.
local function buildSlotTemplate(scope: Fusion.Scope<typeof(Fusion)>): Frame
	local template = scope:New("Frame") {
		Name = "template",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	} :: Frame

	-- Empty-slot hint: dim ink card so the hotbar reads as a row of
	-- slots even with nothing in it.
	local plate = slab(scope, "plate", template, Theme.INK, Theme.CARD_POS, Theme.CARD_SIZE, 0)
	plate.BackgroundTransparency = 0.45
	outline(scope, plate, Theme.PLATE_EDGE, 2)

	-- Shard: peeks out down-right of the card. SlotView tints it from
	-- Metadata.Team and shows it only while the slot holds an item.
	slab(
		scope,
		"teamframe",
		template,
		Color3.fromRGB(80, 80, 80),
		UDim2.new(0.5, Theme.SHARD_OFFSET, 0.5, Theme.SHARD_OFFSET),
		Theme.CARD_SIZE,
		1
	)

	local slotbutton = scope:New("ImageButton") {
		Name = "slotbutton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Theme.CARD_POS,
		Size = Theme.CARD_SIZE,
		Rotation = Theme.TILT,
		BackgroundColor3 = Theme.INK,
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		ZIndex = 2,
		Parent = template,
	} :: ImageButton
	outline(scope, slotbutton, Theme.STEEL, Theme.EDGE_THICKNESS, "Edge")

	-- White overlay for Fx.Flash. Child of the card so it tilts with it.
	scope:New("Frame") {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = slotbutton,
	}

	-- Equipped bar. SlotView shows it while equipped and pops its Size;
	-- the Persona hooks only ever touch its colour (idle pulse). ZIndex 3
	-- draws it ON the card (the card sits at 2), never behind it.
	scope:New("ImageLabel") {
		Name = "selecticon",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 3, 1, 1),
		Size = UDim2.new(0.8, 0, 0, 5),
		Rotation = Theme.TILT,
		BackgroundColor3 = Theme.RED,
		BorderSizePixel = 0,
		Image = "",
		Visible = false,
		ZIndex = 3,
		Parent = template,
	}

	label(scope, "stackcount", template, 16, 3)

	-- Bottom-left position number. Tint comes from SlotView (team colour,
	-- white default, red when unbound).
	local slotnumber = label(scope, "slotnumber", template, 20, 4)
	slotnumber.AnchorPoint = Vector2.new(0, 1)
	slotnumber.Position = UDim2.new(0, -3, 1, 2)
	slotnumber.Size = UDim2.fromOffset(24, 20)
	slotnumber.Rotation = Theme.TILT

	return template
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function PersonaSkin.Load(
	scope: Fusion.Scope<typeof(Fusion)>,
	playerGui: PlayerGui,
	_skinAssetName: string
): CoreTypes.SkinHandle?
	local player = Players.LocalPlayer
	if player == nil then
		Log.warn(ClientStore.GetSettings(), "[PersonaSkin] no LocalPlayer, cannot build UI")
		return nil
	end

	local gui = scope:New("ScreenGui") {
		Name = "PersonaGui",
		ResetOnSpawn = false,
		Parent = playerGui,
	} :: ScreenGui

	-- Bottom hotbar row. Sized + positioned by HotbarView.
	local hotbar = scope:New("Frame") {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	} :: Frame
	scope:New("UIListLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = hotbar,
	}

	-- Storage popup. The Backpack frame is a transparent holder (the layout
	-- only flips its Visible); the red shard, ink panel and title tag are
	-- children so the shard can sit behind the panel.
	local backpack = scope:New("Frame") {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(POPUP_WIDTH, POPUP_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	} :: Frame

	local shard = slab(
		scope,
		"Shard",
		backpack,
		Theme.RED,
		UDim2.new(0.5, 9, 0.5, 8),
		UDim2.fromScale(1, 1),
		1
	)
	shard.Rotation = -2.5
	outline(scope, shard, Theme.INK, 2)

	local panel = scope:New("Frame") {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.INK,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = backpack,
	} :: Frame
	outline(scope, panel, Theme.WHITE, 2)

	-- Title tag: red shard under an ink banner, overhanging the top-left
	-- corner like the combo banner.
	slab(scope, "TagShard", backpack, Theme.RED, UDim2.fromOffset(86, 12), UDim2.fromOffset(176, 40), 4)
	local tag = slab(scope, "Tag", backpack, Theme.INK, UDim2.fromOffset(80, 6), UDim2.fromOffset(176, 40), 5)
	outline(scope, tag, Theme.WHITE, 2)
	local title = label(scope, "Title", tag, 26, 6)
	title.Size = UDim2.fromScale(1, 1)
	title.Text = "BACKPACK"
	title.TextXAlignment = Enum.TextXAlignment.Left
	scope:New("UIPadding") {
		PaddingLeft = UDim.new(0, 14),
		Parent = title,
	}

	local scrolling = scope:New("ScrollingFrame") {
		Name = "ScrollingFrame",
		Position = UDim2.new(0, 14, 0, SCROLL_TOP),
		Size = UDim2.new(1, -28, 1, -(SCROLL_TOP + WEIGHT_HEIGHT + 14)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.RED,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 3,
		Parent = backpack,
	} :: ScrollingFrame
	-- Room for the shard + tilt overhang of the first row/column.
	scope:New("UIPadding") {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = scrolling,
	}

	local weight = label(scope, "Weight", backpack, 18, 3)
	weight.AnchorPoint = Vector2.new(0, 1)
	weight.Position = UDim2.new(0, 14, 1, -10)
	weight.Size = UDim2.new(1, -28, 0, WEIGHT_HEIGHT)
	weight.TextXAlignment = Enum.TextXAlignment.Left

	-- Open pop: the popup snaps in from slightly small, shard a beat late.
	local pop = scope:New("UIScale") {
		Name = "Pop",
		Scale = 1,
		Parent = backpack,
	} :: UIScale
	local openConn = backpack:GetPropertyChangedSignal("Visible"):Connect(function()
		if not backpack.Visible then return end
		pop.Scale = 0.86
		shard.Position = UDim2.new(0.5, -4, 0.5, -2)
		TweenService:Create(pop, POPUP_OPEN, { Scale = 1 }):Play()
		TweenService:Create(shard, POPUP_OPEN, { Position = UDim2.new(0.5, 9, 0.5, 8) }):Play()
	end)
	table.insert(scope, openConn)

	-- Toggle button, bottom-right (mobile-only visibility is owned by
	-- Input). Transparent hit area; red shard + ink face are children.
	local toggle = scope:New("ImageButton") {
		Name = "BackpackStuff",
		Position = UDim2.new(0.857, 0, 0.863, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	} :: ImageButton
	slab(
		scope,
		"Shard",
		toggle,
		Theme.RED,
		UDim2.new(0.5, Theme.SHARD_OFFSET, 0.5, Theme.SHARD_OFFSET),
		Theme.CARD_SIZE,
		1
	)
	local face = slab(scope, "Face", toggle, Theme.INK, Theme.CARD_POS, Theme.CARD_SIZE, 2)
	outline(scope, face, Theme.WHITE, 2)
	scope:New("TextLabel") {
		Name = "glyph",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = Theme.WHITE,
		Text = "≡",
		ZIndex = 3,
		Parent = face,
	}

	local template = buildSlotTemplate(scope)

	-- FX overlay: bursts and rings live here, never inside a slot, so the
	-- storage ScrollingFrame can't clip them. Not Active: input falls
	-- straight through to the slots underneath.
	local fxLayer = scope:New("Frame") {
		Name = "Fx",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 100,
		Parent = gui,
	} :: Frame
	local fx = PersonaFx.new(fxLayer)
	table.insert(scope, function()
		fx:Destroy()
	end)
	local hooks = PersonaHooks.new(fx, {
		Hotbar = hotbar,
		Storage = scrolling,
		Backpack = backpack,
	})

	-- Shared DraggingGui singleton (same rule as SkinLoader): adopt the
	-- live one, else create scope-owned. Unused by sweep mode, kept so
	-- the handle stays complete.
	local existingDragging = playerGui:FindFirstChild("DraggingGui") :: ScreenGui?
	local draggingGui: ScreenGui
	if existingDragging then
		existingDragging.IgnoreGuiInset = false
		draggingGui = existingDragging
	else
		draggingGui = scope:New("ScreenGui") {
			Name = "DraggingGui",
			DisplayOrder = 100,
			IgnoreGuiInset = false,
			ResetOnSpawn = false,
			Parent = playerGui,
		} :: ScreenGui
	end

	return {
		Gui = gui,
		HotbarFrame = hotbar,
		BackpackFrame = backpack,
		ScrollingFrame = scrolling,
		WeightLabel = weight,
		BackpackStuff = toggle,
		SlotTemplate = template,
		DraggingGui = draggingGui,
		SlotBleedPx = Theme.BLEED,
		Hooks = hooks,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return PersonaSkin
