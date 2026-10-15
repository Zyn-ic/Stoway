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
local ClientController = require(script.Parent.ClientController)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

local LayoutManager = {}

local Layouts = {
	StandardHotbarStorage = require(script.Parent.Parent.Layouts.StandardHotbarStorage),
	JailbreakHotbar = require(script.Parent.Parent.Layouts.JailbreakHotbar),
}

-- 1:1 contract: each UiSkin key mounts ONLY its own
-- ReplicatedStorage.Stoway.GUI.<Key> asset (enforced by Teardown +
-- scope-parented clones in SkinLoader). Switching keys can never
-- show another skin's GUI.
-- Keys resolve through the per-skin modules (not SkinLoader directly)
-- so a skin can stamp its own look data onto the handle (e.g. Modern's
-- HeaderColors). Default/Metal re-export the generic loader as-is.
local Skins = {
	Default = require(script.Parent.Parent.Skins.Default),
	Modern = require(script.Parent.Parent.Skins.Modern),
	Metal = require(script.Parent.Parent.Skins.Metal),
	-- Code-built: ignores the asset name, builds the UI in Lua. No
	-- ReplicatedStorage.Stoway.GUI.Jailbreak folder required.
	Jailbreak = require(script.Parent.Parent.Skins.Jailbreak),
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
		Log.warn(ClientStore.GetSettings(), `[LayoutManager] unknown HotbarType layout '{hotbarTypeKey}'`)
		return
	end

	local skinLoader = Skins[skinKey]
	if not skinLoader then
		warn(`[LayoutManager] unknown UiSkin '{skinKey}'`)
		return
	end

	LayoutManager.Teardown()

	local layoutScope = rootScope:deriveScope() :: Fusion.Scope
	currentLayoutScope = layoutScope
	currentLayoutKey = hotbarTypeKey
	currentSkinKey = skinKey

	-- The UiSkin key IS the asset folder. No separate settings lookup:
	-- a key can only resolve its own GUI folder, never another skin's.
	local skinAssetName = skinKey

	local skin = skinLoader.Load(layoutScope, playerGui, skinAssetName)
	if not skin then
		Log.warn(ClientStore.GetSettings(), `[LayoutManager] skin '{skinKey}' failed to load asset '{skinAssetName}' — layout not mounted`)
		return
	end

	engine.Mount(layoutScope, skin, store)
end

-- Cleans up the current layout scope and its instances. Unloads the
-- skin hooks too: no slot exists to fire them after this, and the next
-- Mount overwrites the table anyway. Belt and suspenders.
function LayoutManager.Teardown()
	if currentLayoutScope then
		currentLayoutScope:doCleanup()
		currentLayoutScope = nil
		currentLayoutKey = nil
		currentSkinKey = nil
	end
	ClientController.SetHooks(nil)
end

function LayoutManager.GetCurrentLayout(): (string?, string?)
	return currentLayoutKey, currentSkinKey
end

-----------------------------
-- MAIN --
-----------------------------

return LayoutManager
