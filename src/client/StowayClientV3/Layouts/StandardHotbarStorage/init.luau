--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StandardHotbarStorage layout. Combines the hotbar and storage views.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)

local HotbarView = require(script.HotbarView)
local StorageView = require(script.StorageView)

local StandardHotbarStorage = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StandardHotbarStorage.Mount(scope: Fusion.Scope<any>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	HotbarView.Create(scope, skin, store)
	StorageView.Create(scope, skin, store)
end

-----------------------------
-- MAIN --
-----------------------------

return StandardHotbarStorage
