--!strict

--@author: yyumchi
--@date: 2026-09-18
--[[@description:
	Modern skin hook-function contract (Layer 2). Modern's Studio module
	is literally named DefaultHooks and is byte-identical to Default's,
	so this re-exports Default's contract. The file exists per-skin (not
	per-layout) so Modern can diverge freely: replace the re-export with
	a full table the day its hooks differ.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local DefaultPayloads = require(script.Parent.Parent.Default.HookPayloads)

-----------------------------
-- TYPES --
-----------------------------

export type HookFuncs = DefaultPayloads.HookFuncs

-----------------------------
-- MAIN --
-----------------------------

return DefaultPayloads
