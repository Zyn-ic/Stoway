--!strict

--@author: yyumchi
--@date: 2026-07-07
--[[@description:
	Communications adapter for Stoway.
	Uses QuickNet for server -> client event firing with typed data schemas.
	Registers as an adapter with Stoway — Stoway does not import this module.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)

local Protocol = require(script.Parent.Protocol)

local _Types = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

local Communications = {}

-- Single surface: Protocol.StowayApi (the hand-copy here drifted before).
type StowayApi = Protocol.StowayApi

-- Wire payloads are plain tables; the router trusts shapes and lets
-- CoreStore validation decide. Only table-ness is checked up front.
type Payload = { [string]: any }

local _Stoway: StowayApi? = nil

-- Full-sync requests carry a fat per-player cooldown: full state is
-- expensive, and routers correct failures with FullSync on their own.
-- Stamped on EVERY push (not just requests) so a boot request racing a
-- just-sent join push throttles instead of doubling the join.
local SYNC_COOLDOWN = 15
local _lastSyncRequest: { [Player]: number } = {}

-- PRIVATE FUNCTIONS --
-----------------------------

-- Full-state push, shared by the adapter, join, sync requests, and
-- failure corrections. Projects to the wire shape (drops engine extras).
local function pushFullSync(player: Player)
	local state = if _Stoway then _Stoway.get(player) else nil
	if not state then return end
	local items: { [string]: any } = {}
	for uuid, it in state.Items do
		items[uuid] = {
			UUID = it.UUID,
			Id = it.Id,
			Amount = it.Amount,
			Metadata = it.Metadata,
		}
	end
	local hotbar: { [number]: string } = {}
	for slot, uuid in state.Hotbar do
		if uuid then hotbar[slot] = uuid end
	end
	local storage: { [number]: string } = {}
	for idx, uuid in state.Storage do
		storage[idx] = uuid
	end
	local s = state.Settings
	Remotes.InventoryFullSync:FireClient(player, {
		Items = items,
		Hotbar = hotbar,
		Storage = storage,
		EquippedItemUUID = state.EquippedItemUUID,
		Weight = state.Weight,
		-- Settings snapshot (convergence backstop for sparse pushes).
		Settings = {
			HotbarType = s.HotbarType,
			MaxHotbarSlots = s.MaxHotbarSlots,
			Limit = s.Limit,
			CanStack = s.CanStack,
			MaxStackSize = s.MaxStackSize,
			BackpackEnabled = s.BackpackEnabled,
			Sorting = s.Sorting,
			SortOrder = s.SortOrder,
			StackOnSwap = s.StackOnSwap,
			StackRequiredFields = s.StackRequiredFields,
			StackBlacklist = s.StackBlacklist,
			DefaultDroppable = s.DefaultDroppable,
		},
	})
	-- Every push counts for the request cooldown: a boot request racing
	-- a just-sent join push is throttled instead of doubling the join.
	_lastSyncRequest[player] = os.clock()
end

local function adapter(player: Player, signal: Protocol.Signal)
	-- The tagged union's operation discriminant guards each branch, so the
	-- result cast is safe. (Luau cannot correlate signal.result with
	-- signal.operation across versions, hence the explicit cast.)

	local res = signal.result
	if not res.ok then
		if signal.operation == "SwapSlots" or signal.operation == "SwapStack" then
			-- The player already rendered the swap on their end; only talk back
			-- on failure, and send the inverse of the attempted operation.
			--
			Remotes.InventoryRevert:FireClient(player, {
				success = false,
				fromSlot = res.error.message,
			})
		end
		return
	end

	-- Client-initiated operations don't need a full echo: the client applied
	-- them locally and only needs a confirmation if something failed (above).
	if not signal.replicate then
		return
	end

	if signal.operation == "AddItem" or signal.operation == "AddToBackpack" or signal.operation == "AddToHotbar" then
		local result = (signal.result :: any).value
		local addedItems = result.addedItems
		if addedItems then
			local state = if _Stoway then _Stoway.get(player) else nil
			for _, added in addedItems do
				-- Full item: the client inserts verbatim (server UUID wins).
				local item = state and state.Items[added.uuid]
				if not item then
					warn(`[Communications] added item {added.uuid} missing from state, skipping push`)
				else
					Remotes.InventoryAdded:FireClient(player, {
						uuid = added.uuid,
						slotType = added.slotType,
						slot = added.slot,
						item = {
							UUID = item.UUID,
							Id = item.Id,
							Amount = item.Amount,
							Metadata = item.Metadata,
						},
					})
				end
			end
		end

		local updatedItems = result.updatedItems
		if updatedItems then
			for uuid, newAmount in updatedItems do
				Remotes.InventoryUpdated:FireClient(player, {
					uuid = uuid,
					newAmount = newAmount,
				})
			end
		end

	elseif signal.operation == "RemoveItem" then
		local result = (signal.result :: any).value
		local removedItem = result.removedItem
		if removedItem then
			Remotes.InventoryRemoved:FireClient(player, {
				uuid = removedItem.UUID,
				slotType = result.slotType,
				slot = result.slot,
			})
		end

	elseif signal.operation == "EquipSlot" then
		local result = (signal.result :: any).value
		Remotes.InventoryEquipped:FireClient(player, {
			uuid = result.uuid,
			previousUUID = result.previousUUID,
		})

	elseif signal.operation == "UnequipSlot" then
		local result = (signal.result :: any).value
		Remotes.InventoryUnequipped:FireClient(player, {
			uuid = result.previousUUID,
		})

	elseif signal.operation == "Drop" then
		local result = (signal.result :: any).value
		if result.removedItem then
			Remotes.InventoryRemoved:FireClient(player, {
				uuid = result.removedItem.UUID,
				slotType = nil,
				slot = nil,
			})
		end

	elseif signal.operation == "SwapSlots"
		or signal.operation == "SwapStack"
		or signal.operation == "Move"
		or signal.operation == "Split"
		or signal.operation == "UpdateMetadata"
		or signal.operation == "Sort" then
		-- No targeted push exists for these: send full state. res.ok is
		-- guaranteed here (failures returned early above). Client replaces
		-- wholesale and rebuilds indexes; IsNew glow flags do not survive
		-- (server never sets them).
		pushFullSync(player)
	end
end

-- Client-originated requests run silent (replicate=false): the client
-- already rendered optimistically. Failures correct via FullSync.
local function handle(player: Player, payload: Payload?, run: (Player, Payload) -> boolean)
	if not _Stoway then
		warn("[Communications] request before Init, ignoring")
		return
	end
	-- No-schema events (Unequip/Sort) deliver the player alone: nil
	-- payload is legal and means "no arguments". Anything else must be
	-- a table or it never came from our wire.
	if payload ~= nil and typeof(payload) ~= "table" then return end
	local args: Payload = payload or {}
	local ok, res = pcall(run, player, args)
	if not ok then
		warn(`[Communications] route errored: {tostring(res)}`)
		pushFullSync(player)
		return
	end
	if res == false then
		pushFullSync(player)
	end
end

local function requestSync(player: Player)
	local now = os.clock()
	local last = _lastSyncRequest[player]
	if last and now - last < SYNC_COOLDOWN then
		return
	end
	_lastSyncRequest[player] = now
	pushFullSync(player)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Communications.Init(stowayModule: StowayApi)
	_Stoway = stowayModule

	stowayModule.registerAdapter(adapter)
end

function Communications.SendFullSync(player: Player)
	pushFullSync(player)
end

function Communications.Start()
	local stoway = _Stoway
	if not stoway then
		warn("[Communications] Start before Init, listeners skipped")
		return
	end
	-- One any: the 13 events are differently-typed QuickNet objects and
	-- the table needs a uniform element type. Everything else stays typed.
	type Listener = { event: any, run: (Player, Payload) -> boolean }
	local listeners: { Listener } = {
		{ event = Remotes.AddItem, run = function(p: Player, d: Payload): boolean
			return stoway.AddItem(p, d.input, d.options, false).ok
		end },
		{ event = Remotes.AddToBackpack, run = function(p: Player, d: Payload): boolean
			return stoway.AddToBackpack(p, d.input, d.options, false).ok
		end },
		{ event = Remotes.AddToHotbar, run = function(p: Player, d: Payload): boolean
			return stoway.AddToHotbar(p, d.input, d.preferredSlot, false).ok
		end },
		{ event = Remotes.RemoveItem, run = function(p: Player, d: Payload): boolean
			return stoway.RemoveItem(p, d.uuid, d.amount, false).ok
		end },
		{ event = Remotes.SwapSlots, run = function(p: Player, d: Payload): boolean
			return stoway.SwapSlots(p, d.from, d.to, false).ok
		end },
		{ event = Remotes.SwapStack, run = function(p: Player, d: Payload): boolean
			return stoway.SwapStack(p, d.from, d.to, false).ok
		end },
		{ event = Remotes.Move, run = function(p: Player, d: Payload): boolean
			return stoway.Move(p, d.from, d.to, false).ok
		end },
		{ event = Remotes.Split, run = function(p: Player, d: Payload): boolean
			return stoway.Split(p, d.uuid, d.amount, d.dest, false).ok
		end },
		{ event = Remotes.EquipSlot, run = function(p: Player, d: Payload): boolean
			return stoway.EquipSlot(p, d.uuid, false).ok
		end },
		{ event = Remotes.UnequipSlot, run = function(p: Player, d: Payload): boolean
			return stoway.UnequipSlot(p, false).ok
		end },
		{ event = Remotes.UpdateMetadata, run = function(p: Player, d: Payload): boolean
			return stoway.UpdateMetadata(p, d.uuid, d.updates, false).ok
		end },
		{ event = Remotes.Sort, run = function(p: Player, d: Payload): boolean
			return stoway.Sort(p, false).ok
		end },
		{ event = Remotes.Drop, run = function(p: Player, d: Payload): boolean
			return stoway.Drop(p, d.uuid, d.amount, true).ok
		end },
	}
	for _, l in listeners do
		l.event.OnServerEvent:Connect(function(player: Player, payload: Payload)
			handle(player, payload, l.run)
		end)
	end
	-- No-schema events deliver the player alone, no payload arg.
	Remotes.RequestInventorySync.OnServerEvent:Connect(function(player: Player)
		requestSync(player)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		_lastSyncRequest[player] = nil
	end)
end

-----------------------------
--MAIN--
-----------------------------

return Communications
