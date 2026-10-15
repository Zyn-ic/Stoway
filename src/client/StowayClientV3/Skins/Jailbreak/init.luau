--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Code-built Jailbreak skin. No Studio prefab: builds the ScreenGui,
	bottom hotbar row, centered storage popup, toggle button, and the
	circular slot template entirely in Lua. Same SkinHandle contract as
	the prefab loaders, so LayoutManager treats it identically.

	Slot template contract (Jailbreak has no rarityframe: rarity only
	tints the fallback text via SlotView, never a dot):
	template (Frame)
	  teamframe (Frame, circle)      -> tinted by Metadata.Team
	  slotbutton (ImageButton, circle, dark) -> item Image
	  stackcount (TextLabel)
	  slotnumber (TextLabel, bottom-left position number)
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

local JailbreakSkin = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local SLOT_RED = Color3.fromRGB(175, 45, 52)
-- Jailbreak look: dark fill, team color shows as the outer ring
-- (teamframe underneath, slotbutton inset on top).
local SLOT_FILL = Color3.fromRGB(18, 18, 24)
local SLOT_EDGE = Color3.fromRGB(8, 8, 12)
local PANEL_BG = Color3.fromRGB(22, 22, 28)
local PANEL_STROKE = Color3.fromRGB(60, 60, 72)
local TITLE_TEXT = Color3.fromRGB(240, 240, 245)

local POPUP_WIDTH = 440
local POPUP_HEIGHT = 340
local TITLE_HEIGHT = 32
local WEIGHT_HEIGHT = 24

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function circle(parent: Instance, scope: Fusion.Scope<typeof(Fusion)>)
	scope:New("UICorner") {
		CornerRadius = UDim.new(1, 0),
		Parent = parent,
	}
end

-- Circular red slot template. SlotView clones + hydrates it per slot.
local function buildSlotTemplate(scope: Fusion.Scope<typeof(Fusion)>): Frame
	local template = scope:New("Frame") {
		Name = "template",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	} :: Frame

	scope:New("Frame") {
		Name = "teamframe",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 80, 80),
		BorderSizePixel = 0,
		Parent = template,
	}
	circle(template:FindFirstChild("teamframe") :: Frame, scope)

	local slotbutton = scope:New("ImageButton") {
		Name = "slotbutton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = SLOT_FILL,
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = true,
		ZIndex = 2,
		Parent = template,
	} :: ImageButton
	circle(slotbutton, scope)
	scope:New("UIStroke") {
		Color = SLOT_EDGE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = slotbutton,
	}

	scope:New("TextLabel") {
		Name = "stackcount",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		ZIndex = 3,
		Parent = template,
	}

	-- Bottom-left position number, Jailbreak style. Tint comes from
	-- SlotView (team color, white default, red when unbound).
	scope:New("TextLabel") {
		Name = "slotnumber",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -3, 1, 2),
		Size = UDim2.fromOffset(24, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		ZIndex = 4,
		Parent = template,
	}

	return template
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function JailbreakSkin.Load(
	scope: Fusion.Scope<typeof(Fusion)>,
	playerGui: PlayerGui,
	_skinAssetName: string
): CoreTypes.SkinHandle?
	local player = Players.LocalPlayer
	if player == nil then
		Log.warn(ClientStore.GetSettings(), "[JailbreakSkin] no LocalPlayer, cannot build UI")
		return nil
	end

	local gui = scope:New("ScreenGui") {
		Name = "JailbreakGui",
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

	-- Centered storage popup, Roblox-backpack style. Hidden until Input
	-- flips it (BackpackStuff button or backpack keybind).
	local backpack = scope:New("Frame") {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(POPUP_WIDTH, POPUP_HEIGHT),
		BackgroundColor3 = PANEL_BG,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	} :: Frame
	scope:New("UICorner") {
		CornerRadius = UDim.new(0, 10),
		Parent = backpack,
	}
	scope:New("UIStroke") {
		Color = PANEL_STROKE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = backpack,
	}
	scope:New("UIPadding") {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = backpack,
	}

	scope:New("TextLabel") {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = TITLE_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Backpack",
		Parent = backpack,
	}

	local scrolling = scope:New("ScrollingFrame") {
		Name = "ScrollingFrame",
		Position = UDim2.new(0, 0, 0, TITLE_HEIGHT + 4),
		Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + 4 + WEIGHT_HEIGHT + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = backpack,
	} :: ScrollingFrame

	local weight = scope:New("TextLabel") {
		Name = "Weight",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, WEIGHT_HEIGHT),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = backpack,
	} :: TextLabel

	-- Circular toggle button, bottom-right like the prefab skins (their
	-- BackpackStuff sits at scale (0.857, 0.863)). ImageButton (empty
	-- image) keeps the SkinHandle type; the text child is the visible
	-- glyph. Visibility itself is mobile-only, owned by Input.
	local toggle = scope:New("ImageButton") {
		Name = "BackpackStuff",
		Position = UDim2.new(0.857, 0, 0.863, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = SLOT_RED,
		BorderSizePixel = 0,
		Image = "",
		Visible = false,
		AutoButtonColor = true,
		Parent = gui,
	} :: ImageButton
	circle(toggle, scope)
	scope:New("TextLabel") {
		Name = "glyph",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "≡",
		Parent = toggle,
	}

	local template = buildSlotTemplate(scope)

	-- Shared DraggingGui singleton (same rule as SkinLoader): adopt the
	-- live one, else create scope-owned. Unused by sweep mode, kept so
	-- the handle stays complete for future drag wiring.
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
		SlotBleedPx = 3,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return JailbreakSkin
