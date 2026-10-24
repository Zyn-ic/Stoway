--!strict

--@author: yyumchi
--@date: 2026-10-20
--[[@description:
	Persona look constants: palette, font, tilt and card geometry. Shared by
	the skin builder, the FX runtime and the hooks so a tweak lands once.
	Palette + font match the combo counter (ComboUi) on purpose.
]]

local Theme = {}

-- Palette
Theme.RED = Color3.fromRGB(235, 35, 55)
Theme.INK = Color3.fromRGB(14, 14, 18)
Theme.WHITE = Color3.fromRGB(255, 255, 255)
Theme.STEEL = Color3.fromRGB(120, 120, 134) -- resting card outline
Theme.PLATE_EDGE = Color3.fromRGB(64, 64, 76) -- empty-slot outline

-- Same family as the combo counter's number/suffix labels.
Theme.FONT = Font.new("rbxassetid://12187368843", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- Geometry. Every slanted element shares TILT so the whole UI leans the
-- same way. The card is the slot frame minus CARD_INSET (3px per side);
-- the shard peeks SHARD_OFFSET px into that margin. BLEED is what the
-- layout widens its gaps by (SkinHandle.SlotBleedPx).
Theme.TILT = -6
Theme.CARD_INSET = 6
Theme.CARD_SIZE = UDim2.new(1, -6, 1, -6)
Theme.CARD_POS = UDim2.fromScale(0.5, 0.5)
Theme.SHARD_OFFSET = 3
Theme.BLEED = 3

-- Card outline: resting and hover-hot thickness.
Theme.EDGE_THICKNESS = 2
Theme.EDGE_HOT = 4

return Theme
