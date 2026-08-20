--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Orchestration layer (Layer 2): mounts the active HotbarType layout engine
	against the active UiSkin, and owns the LayoutScope lifecycle so swapping
	either one tears down every visual instance, spring, and listener from
	the previous layout before the next one mounts.

	hotbarTypeKey selects a Layouts[] engine (today: StandardHotbarStorage;
	later: CarouselHotbar, UtilityBelt). skinKey selects a Skins[] loader,
	which resolves Settings.UiSkin to a ReplicatedStorage.Stoway.GUI.<name>
	prefab folder. The two are independent — this is the HotbarType vs UiSkin
	split from section 1 of the master plan. Adding a new layout or skin
	later only means adding an entry to the tables below; nothing in
	CoreStore, ClientStore, or init.luau needs to change.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local ClientStore = require(script.Parent.ClientStore)

local LayoutManager = {}

local Layouts = {
	StandardHotbarStorage = require(script.Parent.Parent.Layouts.StandardHotbarStorage),
}

local Skins = {
	DefaultModern = require(script.Parent.Parent.Skins.DefaultModern),
}

local currentLayoutScope: Fusion.Scope<any>? = nil
local currentLayoutKey: string? = nil
local currentSkinKey: string? = nil

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function LayoutManager.SetLayout(
	rootScope: Fusion.Scope<any>,
	playerGui: PlayerGui,
	store: typeof(ClientStore),
	hotbarTypeKey: string,
	skinKey: string
)
	local engine = (Layouts :: any)[hotbarTypeKey]
	if not engine then
		warn(`[LayoutManager] unknown HotbarType layout '{hotbarTypeKey}'`)
		return
	end

	local skinLoader = (Skins :: any)[skinKey]
	if not skinLoader then
		warn(`[LayoutManager] unknown UiSkin '{skinKey}'`)
		return
	end

	LayoutManager.Teardown()

	local layoutScope = rootScope:deriveScope()
	currentLayoutScope = layoutScope
	currentLayoutKey = hotbarTypeKey
	currentSkinKey = skinKey

	local settings = store.GetSettings()
	local skinAssetName = (settings and settings.UiSkin) or "Default"

	local skin = skinLoader.Load(layoutScope, playerGui, skinAssetName)
	if not skin then
		warn(`[LayoutManager] skin '{skinKey}' failed to load asset '{skinAssetName}' — layout not mounted`)
		return
	end

	engine.Mount(layoutScope, skin, store)
end

-- Tears down the current LayoutScope: every Instance, Computed, and event
-- listener created under it (skin GUI clone included) gets cleaned up.
function LayoutManager.Teardown()
	if currentLayoutScope then
		(currentLayoutScope :: any):doCleanup()
		currentLayoutScope = nil
		currentLayoutKey = nil
		currentSkinKey = nil
	end
end

function LayoutManager.GetCurrentLayout(): (string?, string?)
	return currentLayoutKey, currentSkinKey
end

-----------------------------
-- MAIN --
-----------------------------

return LayoutManager
