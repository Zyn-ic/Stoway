--API.LUAU MODULE(Functions for getting data, e.g., GetStoway)

-- Module-level variables to hold the shared dependencies. They start as nil.
local PlayerStoways
local Settings
local Utils -- A reference to our other utility module!

local API = {}


-- This Init function receives all the shared parts from the main script
function API:Init(context)
    if not context then warn("No context added for API MODULE"); return end
    
    PlayerStoways = context.PlayerStoways
    Settings = context.Settings
    Utils = context.Utils -- We can even share other modules
end

return API