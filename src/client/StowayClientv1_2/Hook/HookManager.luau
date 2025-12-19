-- src/client/StowayClientV1_2/Hooks/HookManager.luau
-- UI-specific hook system - each UI skin provides its own hooks

local HookManager = {}
HookManager.__index = HookManager

--// Available hook types
local HOOK_TYPES = {
	OnSlotClick = "OnSlotClick",
	OnSlotHover = "OnSlotHover",
	OnDragStart = "OnDragStart",
	OnDragEnd = "OnDragEnd",
	OnEquip = "OnEquip",
	OnUnequip = "OnUnequip",
	OnItemAdd = "OnItemAdd",
	OnItemRemove = "OnItemRemove",
	OnSwap = "OnSwap",
}


--// Create a new HookManager instance for a UI skin
function HookManager.new(): HookManager
	local self = setmetatable({}, HookManager)
	
	self._hooks = {}
	for _, hookName in ipairs(HOOK_TYPES) do
		self._hooks[hookName] = {}
	end
	
	return self
end

--// Register a hook callback
function HookManager:Register(hookName: string, callback: (...any) -> ())
	if not self._hooks[hookName] then
		warn("[HookManager] Unknown hook:", hookName)
		return
	end
	table.insert(self._hooks[hookName], callback)
end

--// Unregister a specific callback
function HookManager:Unregister(hookName: string, callback: (...any) -> ())
	local list = self._hooks[hookName]
	if not list then return end
	
	for i, cb in ipairs(list) do
		if cb == callback then
			table.remove(list, i)
			return
		end
	end
end

--// Clear all hooks for a specific type
function HookManager:Clear(hookName: string)
	if self._hooks[hookName] then
		self._hooks[hookName] = {}
	end
end

--// Clear all hooks
function HookManager:ClearAll()
	for hookName in pairs(self._hooks) do
		self._hooks[hookName] = {}
	end
end

--// Fire a hook with arguments
function HookManager:Fire(hookName: string, ...: any)
	local list = self._hooks[hookName]
	if not list then return end
	
	for _, callback in ipairs(list) do
		task.spawn(callback, ...)
	end
end

--// Get available hook types
function HookManager.GetHookTypes(): { string }
	return table.clone(HOOK_TYPES)
end

--// Create a hook table preset for a UI skin
--// Returns a table of hook functions that can be registered at once
function HookManager:LoadPreset(preset: { [string]: (...any) -> () })
	for hookName, callback in pairs(preset) do
		if self._hooks[hookName] then
			self:Register(hookName, callback)
		else
			warn("[HookManager] Preset contains unknown hook:", hookName)
		end
	end
end

--// Export type
export type HookManager = typeof(HookManager.new())

return HookManager
