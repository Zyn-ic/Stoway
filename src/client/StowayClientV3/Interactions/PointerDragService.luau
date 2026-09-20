--!strict

--@author: yyumchi
--@date: 2026-08-22
--[[@description:
	Fully generic pointer drag service. No inventory knowledge.
	Layouts register any GuiObject as a draggable source or drop target
	with a SlotRef. The service handles MouseButton1Down (covers mouse,
	touch and pen), a 5/10px threshold, a Fusion Spring ghost, and hit
	test via PlayerGui:GetGuiObjectsAtPosition with input.Position.
	All connections and the ghost are parented to the scopes passed in,
	so LayoutManager:Teardown or ForPairs cleanup via doCleanup wipes them.
	Drag commits call the caller-supplied onCommit(from,to) which hits
	ClientInventoryController directly, not Signals (Signals are mock RemoteEvents
	for the 5s LocalScript smoke test only).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)
local ClientTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientEvents = require(script.Parent.Parent.Controller.ClientEvents)

local PointerDragService = {}
PointerDragService.__index = PointerDragService

export type Service = typeof(setmetatable({} :: SelfData, PointerDragService))

export type SlotRef = CoreTypes.SlotRef

-- Context passed to onCommit when no target hit (empty area / outside)
export type DragContext = {
	overBackpack: boolean,
	overHotbar: boolean,
	mousePos: Vector2,
}

type SelfData = {
	_layoutScope: Fusion.Scope<typeof(Fusion)>,
	_draggingGui: ScreenGui,
	_onCommit: (from: SlotRef, to: SlotRef?, context: DragContext) -> (),
	_slotTemplate: Frame?,
	_backpackFrame: Frame?,
	_hotbarFrame: Frame?,
	_ghostHidden: { string }?,
	_hooks: ClientTypes.HookMap?,
	_enabled: boolean,
	_dropMap: { [GuiObject]: SlotRef },
	_dropFrames: { GuiObject },
	_ghost: Frame?,
	_ghostSpringPos: Fusion.Spring<UDim2>?,
	_ghostPosValue: Fusion.Value<UDim2>?,
	_ghostRotValue: Fusion.Value<number>?,
	_ghostRotSpring: Fusion.Spring<number>?,
	_lastMousePos: Vector2,
	_dragging: boolean,
	_pressPos: Vector2,
	_pressSlotRef: SlotRef?,
	_pressFrame: GuiObject?,
	_pressOffset: Vector2,
	_checkConn: RBXScriptConnection?,
	_releaseConn: RBXScriptConnection?,
	_moveConn: RBXScriptConnection?,
	_lastDragEnd: number,
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getMousePos(): Vector2
	local inset = GuiService:GetGuiInset()
	return UserInputService:GetMouseLocation() - inset
end

local function isInside(frame: GuiObject, point: Vector2): boolean
	local absPos = frame.AbsolutePosition
	local absSize = frame.AbsoluteSize
	return point.X >= absPos.X and point.X <= absPos.X + absSize.X
		and point.Y >= absPos.Y and point.Y <= absPos.Y + absSize.Y
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function PointerDragService.new(
	layoutScope: Fusion.Scope<typeof(Fusion)>,
	draggingGui: ScreenGui,
	onCommit: (from: SlotRef, to: SlotRef?, context: DragContext) -> (),
	slotTemplate: Frame?,
	backpackFrame: Frame?,
	hotbarFrame: Frame?,
	ghostHidden: { string }?,
	hooks: ClientTypes.HookMap?
): Service
	local self = setmetatable({}, PointerDragService) :: Service
	self._layoutScope = layoutScope
	self._draggingGui = draggingGui
	self._onCommit = onCommit
	self._slotTemplate = slotTemplate
	self._backpackFrame = backpackFrame
	self._hotbarFrame = hotbarFrame
	self._ghostHidden = ghostHidden
	self._hooks = hooks
	self._enabled = true
	self._dropMap = {} :: { [GuiObject]: SlotRef }
	self._dropFrames = {} :: { GuiObject }
	self._ghost = nil :: Frame?
	self._ghostSpringPos = nil :: Fusion.Spring<UDim2>?
	self._ghostPosValue = nil :: Fusion.Value<UDim2>?
	self._ghostRotValue = nil :: Fusion.Value<number>?
	self._ghostRotSpring = nil :: Fusion.Spring<number>?
	self._lastMousePos = Vector2.zero
	self._dragging = false
	self._pressPos = Vector2.zero
	self._pressSlotRef = nil :: SlotRef?
	self._pressFrame = nil :: GuiObject?
	self._pressOffset = Vector2.zero
	self._checkConn = nil :: RBXScriptConnection?
	self._releaseConn = nil :: RBXScriptConnection?
	self._moveConn = nil :: RBXScriptConnection?
	self._lastDragEnd = 0

	local releaseConn = UserInputService.InputEnded:Connect(function(input: InputObject)
		if not self._enabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if self._dragging then
			self:_endDrag(input)
		else
			self:_cancelPress()
		end
	end)
	self._releaseConn = releaseConn
	table.insert(layoutScope, releaseConn)

	return self
end

function PointerDragService.RegisterDraggable(self: Service, slotScope: Fusion.Scope<typeof(Fusion)>, handle: GuiButton, slotRef: SlotRef)
	local conn = handle.MouseButton1Down:Connect(function()
		if not self._enabled then return end
		if not handle.Visible then return end
		self._pressPos = getMousePos()
		self._pressSlotRef = table.clone(slotRef)
		self._pressFrame = handle.Parent :: GuiObject
		self._pressOffset = Vector2.zero

		if self._checkConn then self._checkConn:Disconnect() end
		local checkConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local cur = Vector2.new(input.Position.X, input.Position.Y)
			self._lastMousePos = cur
			local dist = (cur - self._pressPos).Magnitude
			local threshold = if input.UserInputType == Enum.UserInputType.Touch then 10 else 5
			if dist >= threshold and not self._dragging then
				if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
				self:_beginDrag(cur)
			end
		end)
		self._checkConn = checkConn
		table.insert(slotScope, checkConn)
		table.insert(slotScope, handle)
	end)
	table.insert(slotScope, conn)
end

function PointerDragService.RegisterDropTarget(self: Service, dropScope: Fusion.Scope<typeof(Fusion)>, targetFrame: GuiObject, slotRef: SlotRef)
	self._dropMap[targetFrame] = table.clone(slotRef)
	table.insert(self._dropFrames, targetFrame)
	table.insert(dropScope, targetFrame)
	table.insert(dropScope, function()
		self._dropMap[targetFrame] = nil
		local idx = table.find(self._dropFrames, targetFrame)
		if idx then table.remove(self._dropFrames, idx) end
	end)
end

function PointerDragService.SetEnabled(self: Service, enabled: boolean)
	self._enabled = enabled
	if not enabled and self._dragging then self:_cancelPress(); self:_endDrag() end
end

function PointerDragService.IsDragging(self: Service): boolean
	return self._dragging
end

function PointerDragService.WasRecentlyDragging(self: Service, windowSec: number?): boolean
	local w = windowSec or 0.22
	return (os.clock() - self._lastDragEnd) < w
end

function PointerDragService.Destroy(self: Service)
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
	if self._moveConn then self._moveConn:Disconnect(); self._moveConn = nil end
	if self._ghost then self._ghost:Destroy(); self._ghost = nil end
	self._dropMap = {}
	self._dropFrames = {}
	self._dragging = false
	self._pressSlotRef = nil
	self._ghostRotValue = nil
	self._ghostRotSpring = nil
end

-----------------------------
-- INTERNAL --
-----------------------------

function PointerDragService._beginDrag(self: Service, curPos: Vector2)
	if self._dragging then return end
	self._dragging = true

	-- Threshold crossed, ghost about to be created.
	local pressRef = self._pressSlotRef
	if pressRef then
		ClientEvents.DragStarted:Fire(pressRef.Type, pressRef.Slot)
		ClientEvents.CallHook(self._hooks, "OnDragStart", pressRef.Type, pressRef.Slot)
	end

	-- Perfect replica: clone the LIVE hydrated slotFrame (has item image,
	-- rarity color, stack badge, selecticon baked in by SlotView), fall back
	-- to the blank skin template only when pressFrame is unavailable.
	local pressFrame = self._pressFrame
	local template = self._slotTemplate

	local ghost: Frame
	if pressFrame and pressFrame:FindFirstChild("slotbutton") then
		ghost = pressFrame:Clone() :: Frame
	elseif template then
		ghost = template:Clone() :: Frame
	else
		ghost = Instance.new("Frame")
	end
	ghost.Name = "DragGhost"

	-- Strip interaction + layout noise so the ghost is purely visual.
	-- Lift descendants above the ghost root: DraggingGui uses ZIndexBehavior
	-- Global, so the root's ZIndex 100 background would otherwise bury its
	-- own children (template-agnostic, preserves relative order).
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("GuiButton") then
			desc.Active = false
			desc.Selectable = false
			desc.AutoButtonColor = false
		end
		if desc:IsA("GuiObject") then
			desc.ZIndex = desc.ZIndex + 100
		end
	end
	-- Skin-aware strip: hide keybind badges and non-contract chrome (slotdeco,
	-- borders). Defaults preserve legacy behavior when the skin declares no
	-- list. Clone-only; the live slot is untouched.
	local hidden: { string } = self._ghostHidden or { "slotnumber", "keybindbackground" }
	for _, name in hidden do
		local node = ghost:FindFirstChild(name)
		if node and node:IsA("GuiObject") then node.Visible = false end
	end
	ghost.AnchorPoint = Vector2.new(0, 0)
	ghost.LayoutOrder = 0
	ghost.Visible = true
	if pressFrame then
		ghost.Size = pressFrame.Size
	else
		ghost.Size = UDim2.fromOffset(62, 62)
	end
	ghost.ZIndex = 100
	ghost.Parent = self._draggingGui
	self._ghost = ghost


	local posValue: Fusion.Value<UDim2> = self._layoutScope:Value(UDim2.fromOffset(curPos.X, curPos.Y))
	local springPos: Fusion.Spring<UDim2> = self._layoutScope:Spring(posValue, 70, 1)
	self._ghostPosValue = posValue
	self._ghostSpringPos = springPos
	local rotValue: Fusion.Value<number> = self._layoutScope:Value(0)
	local rotSpring: Fusion.Spring<number> = self._layoutScope:Spring(rotValue, 22, 0.4)
	self._ghostRotValue = rotValue
	self._ghostRotSpring = rotSpring
	self._lastMousePos = curPos
	;self._layoutScope:Hydrate(ghost) {
		Position = springPos,
		Rotation = rotSpring,
	}

	local moveConn = RunService.RenderStepped:Connect(function()
		if not self._dragging or not self._ghostPosValue or not self._ghostRotValue then return end
		local m = getMousePos()
		;self._ghostPosValue:set(UDim2.fromOffset(m.X, m.Y))
		local velX = m.X - self._lastMousePos.X
		local velY = m.Y - self._lastMousePos.Y
		self._lastMousePos = m
		local speed = math.sqrt(velX * velX + velY * velY)
		local targetRot = math.clamp(velX * 0.7, -22, 22)
		if speed > 1.5 then
			targetRot += math.sin(tick() * 22) * 4.5 + math.cos(tick() * 14) * 1.5
		else
			targetRot += math.sin(tick() * 10) * 0.8
		end
		;self._ghostRotValue:set(targetRot)
	end)
	self._moveConn = moveConn
	table.insert(self._layoutScope, moveConn)
end

function PointerDragService._endDrag(self: Service, input: InputObject?)
	if not self._dragging then self:_cancelPress(); return end
	self._dragging = false
	self._lastDragEnd = os.clock()
	if self._moveConn then self._moveConn:Disconnect(); self._moveConn = nil end
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end

	local mousePos: Vector2
	if input and input.Position then
		mousePos = Vector2.new(input.Position.X, input.Position.Y)
	else
		mousePos = getMousePos()
	end

	local hitFrames: { GuiObject } = {}
	local playerGui = self._draggingGui.Parent :: PlayerGui?
	if not playerGui then
		playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	end
	local ok, res = pcall(function()
		if playerGui then
			return playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
		end
		return {}
	end)
	if ok and res then hitFrames = res :: { GuiObject } else hitFrames = {} end

	local targetRef: SlotRef? = nil
	for _, guiObj in hitFrames do
		local ref = self._dropMap[guiObj]
		if ref then targetRef = ref; break end
		local parent = guiObj.Parent
		if parent then
			local pr = self._dropMap[parent :: GuiObject]
			if pr then targetRef = pr; break end
		end
	end
	if not targetRef then
		for frame, ref in self._dropMap do
			if frame.Visible and isInside(frame, mousePos) then targetRef = ref; break end
		end
	end

	-- Determine container hover for empty-area semantics (AddToBackpack / Remove / Dynamic insert)
	local overBackpack = false
	local overHotbar = false
	if self._backpackFrame and self._backpackFrame.Visible then
		overBackpack = isInside(self._backpackFrame, mousePos)
	end
	if self._hotbarFrame and self._hotbarFrame.Visible then
		overHotbar = isInside(self._hotbarFrame, mousePos)
	end
	local context: DragContext = {
		overBackpack = overBackpack,
		overHotbar = overHotbar,
		mousePos = mousePos,
	}

	if self._ghost then self._ghost:Destroy(); self._ghost = nil end
	self._ghostPosValue = nil
	self._ghostSpringPos = nil
	self._ghostRotValue = nil
	self._ghostRotSpring = nil

	local from = self._pressSlotRef
	self._pressSlotRef = nil
	self._pressFrame = nil
	-- Release, before commit: the drag happened regardless of hit/miss.
	if from then
		ClientEvents.DragEnded:Fire(from.Type, from.Slot)
		ClientEvents.CallHook(self._hooks, "OnDragEnd", from.Type, from.Slot)
	end
	if from then
		if targetRef then
			if from.Type ~= targetRef.Type or from.Slot ~= targetRef.Slot then
				self._onCommit(from, targetRef, context)
			end
		else
			-- No slot hit but still hovering a container or outside: delegate for AddToBackpack / Remove / Dynamic hotbar insert
			self._onCommit(from, nil, context)
		end
	end
end

function PointerDragService._cancelPress(self: Service)
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
	self._pressSlotRef = nil
	self._pressFrame = nil
end

return PointerDragService
