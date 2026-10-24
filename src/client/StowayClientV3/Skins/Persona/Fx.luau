--!strict

--@author: yyumchi
--@date: 2026-10-20
--[[@description:
	Persona FX runtime. One-shot slot effects for the Persona hooks:
	elastic kicks (scale / tilt / shake), white flash, edge flicker, impact
	slashes, shockwave ring and the equipped-bar pulse. Plain TweenService
	only: no Fusion objects per event and no per-frame loop, so nothing
	keeps running while idle and there is nothing to leak.

	Bursts and rings are parented to the skin's FX layer (a full-screen
	overlay), never to the slot, so the storage ScrollingFrame can't clip
	them. Every method is safe to call on a destroyed slot or after Destroy.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local PersonaFx = {}
PersonaFx.__index = PersonaFx

-----------------------------
-- TYPES --
-----------------------------

export type KickSpec = {
	Scale: number?, -- start scale offset (+ grows, - squashes)
	Rot: number?, -- start tilt offset in degrees (sign alternates per kick)
	Shake: number?, -- start offset in px, random direction
	Time: number?, -- settle time in seconds
}

type SelfData = {
	_layer: Frame,
	_destroyed: boolean,
	_sign: number,
	_active: number,
	_idle: { [string]: Tween? },
	_edgeTweens: { [UIStroke]: Tween? },
	_liftToken: { [GuiObject]: number },
}

export type Fx = typeof(setmetatable({} :: SelfData, PersonaFx))

-----------------------------
-- CONSTANTS --
-----------------------------

local LIFT_Z = 10 -- slot ZIndex while a kick plays, so it draws over neighbours
local MAX_ACTIVE = 64 -- cap on live burst/ring frames (fast sweeps spam bursts)

local SLASH_TIME = 0.24
local SLASH_MOVE = TweenInfo.new(SLASH_TIME, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local SLASH_FADE = TweenInfo.new(SLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local RING_TIME = 0.32
local RING_INFO = TweenInfo.new(RING_TIME, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local FLASH_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLICKER_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Equipped bar pulse: red <-> white forever until cancelled.
local IDLE_INFO = TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- UIScale on the card, so a scale kick never fights the slot frame's own
-- Size binding or the layout's swap-pop UIScale (that one lives on the
-- slot frame, this one on the button inside it).
local function punchScale(btn: GuiButton): UIScale
	local existing = btn:FindFirstChild("PunchScale")
	if existing ~= nil and existing:IsA("UIScale") then
		return existing :: UIScale
	end
	local created = Instance.new("UIScale")
	created.Name = "PunchScale"
	created.Parent = btn
	return created
end

-- Centre of target in the FX layer's coordinate space, plus its half-size.
local function centerIn(layer: Frame, target: GuiObject): (Vector2?, number)
	local size = target.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil, 0
	end
	local center = target.AbsolutePosition + size * 0.5 - layer.AbsolutePosition
	return center, math.min(size.X, size.Y) * 0.5
end

-- Raise the slot above its siblings for the length of a kick. Token-based
-- so overlapping kicks don't restore early.
local function liftSlot(self: Fx, slot: GuiObject, seconds: number)
	local token = (self._liftToken[slot] or 0) + 1
	self._liftToken[slot] = token
	slot.ZIndex = LIFT_Z
	task.delay(seconds, function()
		if self._liftToken[slot] == token then
			self._liftToken[slot] = nil
			if slot.Parent ~= nil then
				slot.ZIndex = 1
			end
		end
	end)
end

local function newStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = parent
	return stroke
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function PersonaFx.new(layer: Frame): Fx
	local self = setmetatable({
		_layer = layer,
		_destroyed = false,
		_sign = 1,
		_active = 0,
		_idle = {},
		_edgeTweens = {},
		_liftToken = {},
	} :: SelfData, PersonaFx)
	return self
end

-- Elastic kick on a slot's card: jumps to the offset instantly, then
-- rings back to rest. Scale, tilt and shake settle together.
function PersonaFx.Kick(self: Fx, btn: GuiButton, spec: KickSpec)
	if self._destroyed or btn.Parent == nil or not btn.Visible then return end

	local seconds = spec.Time or 0.5
	local scale = punchScale(btn)
	scale.Scale = math.max(1 + (spec.Scale or 0), 0.1)

	self._sign = -self._sign
	btn.Rotation = Theme.TILT + self._sign * (spec.Rot or 0)

	local shake = spec.Shake or 0
	local angle = math.random() * math.pi * 2
	btn.Position = Theme.CARD_POS + UDim2.fromOffset(math.cos(angle) * shake, math.sin(angle) * shake)

	local info = TweenInfo.new(seconds, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(scale, info, { Scale = 1 }):Play()
	TweenService:Create(btn, info, { Rotation = Theme.TILT, Position = Theme.CARD_POS }):Play()

	local slot = btn.Parent
	if slot and slot:IsA("GuiObject") then
		liftSlot(self, slot, seconds)
	end
end

-- Stamp-in: starts small and tilted, rings up past full size.
function PersonaFx.PopIn(self: Fx, btn: GuiButton)
	self:Kick(btn, { Scale = -0.75, Rot = 12, Shake = 0, Time = 0.55 })
end

-- White (or tinted) overlay on the card that fades out.
function PersonaFx.Flash(self: Fx, btn: GuiButton, color: Color3, strength: number)
	if self._destroyed or btn.Parent == nil then return end
	local flash = btn:FindFirstChild("Flash")
	if flash == nil or not flash:IsA("Frame") then return end
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	TweenService:Create(flash, FLASH_INFO, { BackgroundTransparency = 1 }):Play()
end

-- Outline snaps to colour/thick, then eases back to the resting look.
function PersonaFx.Flicker(self: Fx, btn: GuiButton, color: Color3)
	if self._destroyed or btn.Parent == nil then return end
	local edge = btn:FindFirstChild("Edge")
	if edge == nil or not edge:IsA("UIStroke") then return end
	edge.Color = color
	edge.Thickness = Theme.EDGE_HOT
	local tween = TweenService:Create(edge, FLICKER_INFO, { Color = Theme.STEEL, Thickness = Theme.EDGE_THICKNESS })
	self._edgeTweens[edge] = tween
	tween:Play()
	tween.Completed:Once(function()
		if self._edgeTweens[edge] == tween then
			self._edgeTweens[edge] = nil
		end
	end)
end

-- Hold the outline hot (red, hover-hot thickness) while the card is the
-- current drag target. on = false drops it straight back to the resting
-- look, so only one card is ever lit.
function PersonaFx.SetHot(self: Fx, btn: GuiButton, on: boolean)
	if self._destroyed or btn.Parent == nil then return end
	local edge = btn:FindFirstChild("Edge")
	if edge == nil or not edge:IsA("UIStroke") then return end
	local running = self._edgeTweens[edge]
	if running ~= nil then
		running:Cancel()
		self._edgeTweens[edge] = nil
	end
	if on then
		edge.Color = Theme.RED
		edge.Thickness = Theme.EDGE_HOT
	else
		edge.Color = Theme.STEEL
		edge.Thickness = Theme.EDGE_THICKNESS
	end
end

-- Impact slashes radiating from the target's centre (the combo counter's
-- slash ring). Frames are created per burst and destroyed on a timer.
function PersonaFx.Burst(self: Fx, target: GuiObject, color: Color3, count: number, power: number)
	if self._destroyed then return end
	local center, radius = centerIn(self._layer, target)
	if center == nil then return end

	local base = math.random() * math.pi * 2
	local width = math.max(3, radius * 0.13)
	local length = radius * 0.95
	local startDist = radius * 0.9
	local travel = radius * 1.25 * power

	for i = 1, count do
		if self._active >= MAX_ACTIVE then break end
		self._active += 1

		local angle = base + (i - 1) * (math.pi * 2 / count) + math.rad(math.random(-14, 14))
		local dir = Vector2.new(math.cos(angle), math.sin(angle))
		local from = center + dir * startDist
		local to = center + dir * (startDist + travel)

		local slash = Instance.new("Frame")
		slash.Name = "Slash"
		slash.AnchorPoint = Vector2.new(0.5, 0.5)
		slash.BackgroundColor3 = color
		slash.BorderSizePixel = 0
		slash.Position = UDim2.fromOffset(from.X, from.Y)
		slash.Size = UDim2.fromOffset(width, length)
		slash.Rotation = math.deg(angle) - 90
		local stroke = newStroke(slash, Theme.INK, 1.5)
		slash.Parent = self._layer

		TweenService:Create(slash, SLASH_MOVE, {
			Position = UDim2.fromOffset(to.X, to.Y),
			Size = UDim2.fromOffset(width, length * 0.45),
		}):Play()
		TweenService:Create(slash, SLASH_FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, SLASH_FADE, { Transparency = 1 }):Play()

		task.delay(SLASH_TIME + 0.05, function()
			self._active -= 1
			slash:Destroy()
		end)
	end
end

-- Hollow tilted square that expands past the slot and fades: the stamp
-- shockwave under a burst.
function PersonaFx.Ring(self: Fx, target: GuiObject, color: Color3, grow: number)
	if self._destroyed or self._active >= MAX_ACTIVE then return end
	local center, radius = centerIn(self._layer, target)
	if center == nil then return end
	self._active += 1

	local start = math.max(radius * 2 - Theme.CARD_INSET, 4)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Position = UDim2.fromOffset(center.X, center.Y)
	ring.Size = UDim2.fromOffset(start, start)
	ring.Rotation = Theme.TILT
	local stroke = newStroke(ring, color, 4)
	ring.Parent = self._layer

	local finish = start * grow
	TweenService:Create(ring, RING_INFO, { Size = UDim2.fromOffset(finish, finish) }):Play()
	TweenService:Create(stroke, RING_INFO, { Transparency = 1, Thickness = 1 }):Play()

	task.delay(RING_TIME + 0.05, function()
		self._active -= 1
		ring:Destroy()
	end)
end

-- Equipped-bar pulse (red <-> white) for as long as the slot stays
-- selected. Keyed by slot name, so a storage slot that got rebuilt
-- mid-selection still has its old pulse cancelled on deselect.
function PersonaFx.SetIdle(self: Fx, slot: GuiObject, on: boolean)
	local key = slot.Name
	local running = self._idle[key]
	if running ~= nil then
		running:Cancel()
		self._idle[key] = nil
	end

	local bar = slot:FindFirstChild("selecticon")
	if bar == nil or not bar:IsA("ImageLabel") then return end
	bar.BackgroundColor3 = Theme.RED

	if on and not self._destroyed then
		local tween = TweenService:Create(bar, IDLE_INFO, { BackgroundColor3 = Theme.WHITE })
		self._idle[key] = tween
		tween:Play()
	end
end

function PersonaFx.Destroy(self: Fx)
	self._destroyed = true
	for key, tween in self._idle do
		if tween ~= nil then
			tween:Cancel()
		end
		self._idle[key] = nil
	end
	for edge, tween in self._edgeTweens do
		if tween ~= nil then
			tween:Cancel()
		end
		self._edgeTweens[edge] = nil
	end
end

-----------------------------
-- MAIN --
-----------------------------

return PersonaFx
