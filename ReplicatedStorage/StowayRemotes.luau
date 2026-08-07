local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickNet = require(ReplicatedStorage.Packages.QuickNet)
local data = QuickNet.Data

return {
    AddItem = QuickNet:register("AddItem", data.any)
}
