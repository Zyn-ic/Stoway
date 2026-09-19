--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Example external subscriber on the ClientEvents bus. Requires the
	NotifyExample module and connects it (toast/sound stubs until real
	assets exist). Lives in the Tests harness, outside the client root
	module.
]]

local NotifyExample = require(script.Parent.Parent.Controller.NotifyExample)

NotifyExample.Connect()
