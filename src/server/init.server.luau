-- ServerScriptService/init.server.luau

--// Stoway V1 Initialization
-- We are transitioning to the new V1 architecture.
-- The old StowayServer code is replaced by this single service entry point.

local InventoryService = require(script["StowayServerV1_2"])

InventoryService.Init()

print("Stoway Inventory System V1 Loaded")