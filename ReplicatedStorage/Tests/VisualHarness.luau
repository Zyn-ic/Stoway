--!strict
-- Forwarder — real VisualHarness lives at src/client/StowayClientV3/Tests/VisualHarness.luau
-- Keeps old CommandBar path working: require(game.ReplicatedStorage.Tests.VisualHarness).run(2)
-- Must forward to the CLIENT singleton (PlayerScripts), not a copy.

local Players = game:GetService("Players")

local function getReal()
	local ok, mod = pcall(function()
		return require(Players.LocalPlayer.PlayerScripts.StowayClientV3.Tests.VisualHarness)
	end)
	if ok and mod then return mod end

	local ok2, mod2 = pcall(function()
		return require(game:GetService("StarterPlayer").StarterPlayerScripts.StowayClientV3.Tests.VisualHarness)
	end)
	if ok2 and mod2 then return mod2 end

	error("[VisualHarness forwarder] could not find client VisualHarness at PlayerScripts/StarterPlayer.StowayClientV3.Tests.VisualHarness — are you in Play on the Client?")
end

return getReal()
