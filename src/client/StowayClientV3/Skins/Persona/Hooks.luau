--!strict

--@author: yyumchi
--@date: 2026-10-20
--[[@description:
	Persona skin hooks (Layer 2). The full 11-name contract, each one wired
	to a punch from Persona.Fx. Built per mount (not a static table)
	because the hooks need the live hotbar / storage containers to find the
	slot a (slotType, index) payload points at: payloads never carry
	frames, subscribers resolve visuals themselves (see ClientEvents).

	Who does what:
	  state changes   OnEquip / OnUnequip / OnItemAdd / OnItemRemove / OnSwap
	                  -> the big beats (kick + flash + slashes + ring)
	  held state      OnSelect / OnDeselect -> equipped-bar pulse for as long
	                  as the slot stays selected (SlotView only fires these
	                  for templates with a selecticon, which Persona has)
	  pointer         OnSlotHover / OnSlotClick / OnDragStart / OnDragEnd
	                  -> small feedback, deliberately quieter than the beats

	Hooks are spawned + pcall'd by ClientEvents.CallHook, so yielding here
	(the one-frame settle wait) never stalls input, and a throw only warns.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)

local Theme = require(script.Parent.Theme)
local PersonaFx = require(script.Parent.Fx)

local PersonaHooks = {}

export type Targets = {
	Hotbar: Frame,
	Storage: ScrollingFrame,
	Backpack: Frame,
}

-----------------------------
-- CONSTANTS --
-----------------------------

-- Tuning lives here: every number the feel depends on, in one place.
local TUNE = {
	Hover = { Scale = 0.08, Rot = 3, Shake = 1.5, Time = 0.35 } :: PersonaFx.KickSpec,
	Click = { Scale = -0.14, Rot = 2, Shake = 0, Time = 0.35 } :: PersonaFx.KickSpec,
	Equip = { Scale = 0.32, Rot = 8, Shake = 5, Time = 0.55 } :: PersonaFx.KickSpec,
	Unequip = { Scale = -0.2, Rot = 4, Shake = 0, Time = 0.4 } :: PersonaFx.KickSpec,
	Swap = { Scale = 0.2, Rot = 7, Shake = 3, Time = 0.45 } :: PersonaFx.KickSpec,
	DragStart = { Scale = 0.18, Rot = 6, Shake = 0, Time = 0.4 } :: PersonaFx.KickSpec,
	DragEnd = { Scale = -0.1, Rot = 3, Shake = 0, Time = 0.35 } :: PersonaFx.KickSpec,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function PersonaHooks.new(fx: PersonaFx.Fx, targets: Targets): CoreTypes.HookMap
	-- Slot frames are named "<SlotType>-<index>" by SlotView and sit
	-- directly under the hotbar / the storage ScrollingFrame.
	local function slotFrame(slotType: CoreTypes.SlotType, index: number): Frame?
		-- A closed popup has nothing to animate.
		if slotType == "Storage" and not targets.Backpack.Visible then return nil end
		local container: Instance = if slotType == "Hotbar" then targets.Hotbar else targets.Storage
		local found = container:FindFirstChild(`{slotType}-{index}`)
		if found ~= nil and found:IsA("Frame") then
			return found :: Frame
		end
		return nil
	end

	local function buttonOf(frame: Frame?): GuiButton?
		if frame == nil then return nil end
		local btn = frame:FindFirstChild("slotbutton")
		if btn ~= nil and btn:IsA("GuiButton") then
			return btn :: GuiButton
		end
		return nil
	end

	-- State hooks fire right after the store sync, so a storage slot the
	-- sync just rebuilt may not have been laid out yet (size 0). Give the
	-- layout one frame, then look the slot up again.
	local function settled(slotType: CoreTypes.SlotType, index: number): (Frame?, GuiButton?)
		local frame = slotFrame(slotType, index)
		if frame == nil or frame.AbsoluteSize.X <= 0 then
			task.wait()
			frame = slotFrame(slotType, index)
		end
		if frame == nil or frame.AbsoluteSize.X <= 0 then
			return nil, nil
		end
		return frame, buttonOf(frame)
	end

	local hooks: CoreTypes.HookMap = {}

	-----------------------------
	-- POINTER (quiet) --
	-----------------------------

	-- Hover: tilt wobble + the outline flashes red and cools back down.
	hooks.OnSlotHover = function(btn: GuiButton, _slotType: CoreTypes.SlotType, _slotIndex: number)
		fx:Kick(btn, TUNE.Hover)
		fx:Flicker(btn, Theme.RED)
	end

	-- Click: press-in squash + a thin white flash. The equip/unequip beat
	-- follows from the state hook, so this stays small.
	hooks.OnSlotClick = function(slotType: CoreTypes.SlotType, index: number, _uuid: string?)
		local btn = buttonOf(slotFrame(slotType, index))
		if btn == nil then return end
		fx:Kick(btn, TUNE.Click)
		fx:Flash(btn, Theme.WHITE, 0.35)
	end

	-- Sweep armed: the pressed card lifts and its outline goes hot.
	hooks.OnDragStart = function(slotType: CoreTypes.SlotType, index: number)
		local btn = buttonOf(slotFrame(slotType, index))
		if btn == nil then return end
		fx:Kick(btn, TUNE.DragStart)
		fx:Flicker(btn, Theme.RED)
	end

	-- Sweep over: the card the stroke ended on settles with a soft thud.
	hooks.OnDragEnd = function(slotType: CoreTypes.SlotType, index: number)
		local btn = buttonOf(slotFrame(slotType, index))
		if btn == nil then return end
		fx:Kick(btn, TUNE.DragEnd)
		fx:Flash(btn, Theme.WHITE, 0.3)
	end

	-----------------------------
	-- STATE (the beats) --
	-----------------------------

	-- Equip: the loudest one. Slam, white flash, red shockwave, red slashes.
	hooks.OnEquip = function(slotType: CoreTypes.SlotType, index: number)
		local frame, btn = settled(slotType, index)
		if frame == nil or btn == nil then return end
		fx:Kick(btn, TUNE.Equip)
		fx:Flash(btn, Theme.WHITE, 0.85)
		fx:Ring(frame, Theme.RED, 1.9)
		fx:Burst(frame, Theme.RED, 8, 1.2)
	end

	-- Unequip: the card dips and a few white slashes fall away.
	hooks.OnUnequip = function(slotType: CoreTypes.SlotType, index: number)
		local frame, btn = settled(slotType, index)
		if frame == nil or btn == nil then return end
		fx:Kick(btn, TUNE.Unequip)
		fx:Flash(btn, Theme.WHITE, 0.3)
		fx:Burst(frame, Theme.WHITE, 3, 0.55)
	end

	-- Add: the new item stamps in from small, white ring + slashes.
	hooks.OnItemAdd = function(slotType: CoreTypes.SlotType, index: number)
		local frame, btn = settled(slotType, index)
		if frame == nil or btn == nil then return end
		fx:PopIn(btn)
		fx:Flash(btn, Theme.WHITE, 0.8)
		fx:Ring(frame, Theme.WHITE, 1.7)
		fx:Burst(frame, Theme.WHITE, 5, 0.85)
	end

	-- Remove: the card is already gone, so only the shatter is left. Red
	-- slashes burst from the empty slot.
	hooks.OnItemRemove = function(slotType: CoreTypes.SlotType, index: number)
		local frame = settled(slotType, index)
		if frame == nil then return end
		fx:Ring(frame, Theme.RED, 1.5)
		fx:Burst(frame, Theme.RED, 6, 0.9)
	end

	-- Swap: fires for the destination slot (the layout already pops both
	-- endpoints). Kept short because a sweep ripple fires it per crossing.
	hooks.OnSwap = function(slotType: CoreTypes.SlotType, index: number)
		local frame, btn = settled(slotType, index)
		if frame == nil or btn == nil then return end
		fx:Kick(btn, TUNE.Swap)
		fx:Flash(btn, Theme.WHITE, 0.5)
		fx:Burst(frame, Theme.WHITE, 4, 0.7)
	end

	-----------------------------
	-- HELD STATE --
	-----------------------------

	-- Select/Deselect carry the slot frame itself. SlotView fires them from
	-- the equipped observer, which only runs on a change, so a slot that is
	-- already equipped at mount gets the red bar but no pulse until it is
	-- re-selected.
	hooks.OnSelect = function(frame: Frame, _slotType: CoreTypes.SlotType, _slotIndex: number)
		fx:SetIdle(frame, true)
	end

	hooks.OnDeselect = function(frame: Frame, _slotType: CoreTypes.SlotType, _slotIndex: number)
		fx:SetIdle(frame, false)
	end

	return hooks
end

-----------------------------
-- MAIN --
-----------------------------

return PersonaHooks
