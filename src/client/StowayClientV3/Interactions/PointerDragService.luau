--!strict

--@author: yyumchi
--@date: 2026-08-22
--[[@description:
	Fully generic pointer drag service. No inventory knowledge.
	Layouts register any GuiObject as a draggable source or drop target
	with a SlotRef. The service handles MouseButton1Down (covers mouse,
	touch and pen), a 5/10px threshold, a Fusion Spring ghost, and hit
	test via GuiService:GetGuiObjectsAtPosition. All connections and the
	ghost are parented to the scopes passed in, so LayoutManager:Teardown
	or ForPairs cleanup via doCleanup wipes them. Drag commits call the
	caller-supplied onCommit(from,to) which should hit
	ClientInventoryController directly, not Signals (Signals are mock RemoteEvents
	for the 5s LocalScript smoke test only).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

local PointerDragService = {}
PointerDragService.__index = PointerDragService

export type SlotRef = CoreTypes.SlotRef
export type Service = {
	RegisterDraggable: (self: Service, slotScope: Fusion.Scope<any>, handle: GuiButton, slotRef: SlotRef) -> (),
	RegisterDropTarget: (self: Service, dropScope: Fusion.Scope<any>, targetFrame: GuiObject, slotRef: SlotRef) -> (),
	SetEnabled: (self: Service, enabled: boolean) -> (),
	Destroy: (self: Service) -> (),
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getMousePos(): Vector2
	local pos = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	return Vector2.new(pos.X - inset.X, pos.Y - inset.Y)
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
	layoutScope: Fusion.Scope<any>,
	draggingGui: ScreenGui,
	onCommit: (from: SlotRef, to: SlotRef) -> (),
	slotTemplate: Frame?
): Service
	local self: any = setmetatable({}, PointerDragService)
	self._layoutScope = layoutScope
	self._draggingGui = draggingGui
	self._onCommit = onCommit
	self._slotTemplate = slotTemplate
	self._enabled = true
	self._dropMap = {} :: { [GuiObject]: SlotRef }
	self._dropFrames = {} :: { GuiObject }
	self._ghost = nil :: Frame?
	self._ghostSpringPos = nil :: any
	self._ghostPosValue = nil :: any
	self._dragging = false
	self._pressPos = Vector2.new(0, 0)
	self._pressSlotRef = nil :: SlotRef?
	self._pressFrame = nil :: GuiObject?
	self._pressOffset = Vector2.new(0, 0)
	self._checkConn = nil :: RBXScriptConnection?
	self._releaseConn = nil :: RBXScriptConnection?
	self._moveConn = nil :: RBXScriptConnection?

	-- Global release: if drag never passed threshold, treat as click-style cancel
	self._releaseConn = UserInputService.InputEnded:Connect(function(input)
		if not self._enabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if self._dragging then
			self:_endDrag()
		else
			self:_cancelPress()
		end
	end)
	table.insert(layoutScope, self._releaseConn)

	return self :: Service
end

function PointerDragService:RegisterDraggable(slotScope: Fusion.Scope<any>, handle: GuiButton, slotRef: SlotRef)
	-- MouseButton1Down covers mouse, touch and pen on Roblox
	local conn = handle.MouseButton1Down:Connect(function()
		if not self._enabled then return end
		if not handle.Visible then return end
		self._pressPos = getMousePos()
		self._pressSlotRef = table.clone(slotRef) :: SlotRef
		self._pressFrame = handle.Parent :: GuiObject
		-- offset so ghost stays under finger
		local absPos = handle.AbsolutePosition
		self._pressOffset = self._pressPos - Vector2.new(absPos.X, absPos.Y)

		-- threshold watch – put it in slotScope so ForPairs cleanup kills it
		if self._checkConn then self._checkConn:Disconnect() end
		self._checkConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local cur = getMousePos()
			local dist = (cur - self._pressPos).Magnitude
			local threshold = if input.UserInputType == Enum.UserInputType.Touch then 10 else 5
			if dist >= threshold and not self._dragging then
				if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
				self:_beginDrag(cur)
			end
		end)
		table.insert(slotScope, self._checkConn)
		table.insert(slotScope, handle)
	end)
	table.insert(slotScope, conn)
end

function PointerDragService:RegisterDropTarget(dropScope: Fusion.Scope<any>, targetFrame: GuiObject, slotRef: SlotRef)
	self._dropMap[targetFrame] = table.clone(slotRef) :: SlotRef
	table.insert(self._dropFrames, targetFrame)
	table.insert(dropScope, targetFrame)
	-- keep map clean when frame is destroyed via scope cleanup
	table.insert(dropScope, function()
		self._dropMap[targetFrame] = nil
		local idx = table.find(self._dropFrames, targetFrame)
		if idx then table.remove(self._dropFrames, idx) end
	end)
end

function PointerDragService:SetEnabled(enabled: boolean)
	self._enabled = enabled
	if not enabled and self._dragging then self:_cancelPress(); self:_endDrag() end
end

function PointerDragService:Destroy()
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
	if self._moveConn then self._moveConn:Disconnect(); self._moveConn = nil end
	if self._ghost then (self._ghost :: any):Destroy(); self._ghost = nil end
	self._dropMap = {}
	self._dropFrames = {}
	self._dragging = false
	self._pressSlotRef = nil
end

-----------------------------
-- INTERNAL --
-----------------------------

function PointerDragService._beginDrag(self: any, curPos: Vector2)
	if self._dragging then return end
	self._dragging = true

	local template = self._slotTemplate
	local ghost: Frame
	if template then
		ghost = template:Clone()
		ghost.Name = "DragGhost"
		local sn = ghost:FindFirstChild("slotnumber")
		if sn then (sn :: GuiObject).Visible = false end
		local kb = ghost:FindFirstChild("keybindbackground")
		if kb then (kb :: GuiObject).Visible = false end
		ghost.AnchorPoint = Vector2.new(0, 0)
		ghost.Size = (self._pressFrame and (self._pressFrame :: any).Size) or UDim2.fromOffset(62, 62)
		ghost.ZIndex = 100
		ghost.Parent = self._draggingGui
	else
		ghost = Instance.new("Frame")
		ghost.Name = "DragGhost"
		ghost.Size = UDim2.fromOffset(62, 62)
		ghost.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		ghost.Parent = self._draggingGui
	end
	self._ghost = ghost

	-- Spring ghost – scope owned by layoutScope so teardown kills it
	local posValue = self._layoutScope:Value(UDim2.fromOffset(curPos.X - self._pressOffset.X, curPos.Y - self._pressOffset.Y))
	local springPos = self._layoutScope:Spring(posValue, 30, 1)
	self._ghostPosValue = posValue
	self._ghostSpringPos = springPos
	self._layoutScope:Hydrate(ghost) {
		Position = springPos,
	}

	self._moveConn = RunService.RenderStepped:Connect(function()
		if not self._dragging or not self._ghostPosValue then return end
		local m = getMousePos()
		self._ghostPosValue:set(UDim2.fromOffset(m.X - self._pressOffset.X, m.Y - self._pressOffset.Y))
	end)
	table.insert(self._layoutScope, self._moveConn)
end

function PointerDragService._endDrag(self: any)
	if not self._dragging then self:_cancelPress(); return end
	self._dragging = false
	if self._moveConn then self._moveConn:Disconnect(); self._moveConn = nil end
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end

	local mousePos = getMousePos()
	local hitFrames = {}
	-- Prefer GuiService hit test, fallback to manual AABB
	local ok, res = pcall(function() return GuiService:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y) end)
	if ok and res then hitFrames = res else hitFrames = {} end

	local targetRef: SlotRef? = nil
	-- first try hit test
	for _, guiObj in hitFrames do
		local ref = self._dropMap[guiObj :: GuiObject]
		if ref then targetRef = ref; break end
		-- also check parent (slot Frame contains slotbutton)
		local p = (guiObj :: any).Parent
		if p then
			local pr = self._dropMap[p :: GuiObject]
			if pr then targetRef = pr; break end
		end
	end
	-- fallback manual inside check for cases where GetGuiObjectsAtPosition misses due to ZIndex
	if not targetRef then
		for frame, ref in self._dropMap do
			if frame.Visible and isInside(frame, mousePos) then targetRef = ref; break end
		end
	end

	if self._ghost then (self._ghost :: any):Destroy(); self._ghost = nil end
	self._ghostPosValue = nil
	self._ghostSpringPos = nil

	local from = self._pressSlotRef
	self._pressSlotRef = nil
	self._pressFrame = nil
	if from and targetRef then
		-- avoid no-op
		if from.Type ~= targetRef.Type or from.Slot ~= targetRef.Slot then
			self._onCommit(from, targetRef)
		end
	end
end

function PointerDragService._cancelPress(self: any)
	if self._checkConn then self._checkConn:Disconnect(); self._checkConn = nil end
	self._pressSlotRef = nil
	self._pressFrame = nil
end

return PointerDragService
