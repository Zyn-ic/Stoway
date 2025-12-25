-- src/server/StowayServerV1.2/Utils/UUID.luau
-- UUID generation utility

local UUID = {}

local HttpService = game:GetService("HttpService")

function UUID.Generate(): string
	return HttpService:GenerateGUID(false)
end

return UUID
