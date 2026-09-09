--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Mounts a HotbarType layout with a UiSkin and manages the LayoutScope
	lifecycle. HotbarType and UiSkin are independent.
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

local currentLayoutScope: Fusion.Scope<typeof(Fusion)>? = nil
local currentLayoutKey: string? = nil
local currentSkinKey: string? = nil

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function LayoutManager.SetLayout(
	rootScope: Fusion.Scope<typeof(Fusion)>,
	playerGui: PlayerGui,
	store: typeof(ClientStore),
	hotbarTypeKey: string,
	skinKey: string
)
	local engine = Layouts[hotbarTypeKey]
	if not engine then
		warn(`[LayoutManager] unknown HotbarType layout '{hotbarTypeKey}'`)
		return
	end

	local skinLoader = Skins[skinKey]
	if not skinLoader then
		warn(`[LayoutManager] unknown UiSkin '{skinKey}'`)
		return
	end

	LayoutManager.Teardown()

	local layoutScope: Fusion.Scope<typeof(Fusion)> = (rootScope :: any):deriveScope()
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

-- Cleans up the current layout scope and its instances.
function LayoutManager.Teardown()
	if currentLayoutScope then
		currentLayoutScope:doCleanup()
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
