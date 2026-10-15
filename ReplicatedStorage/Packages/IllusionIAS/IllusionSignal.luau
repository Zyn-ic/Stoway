--!strict
--IllusionSignal.luau
--[[
  //////////////////////
 //  Illusion Signal //
//////////////////////
]]

local IAS = require("./TypeDefinition")

return {
	new = function<T>(): IAS.IAScriptSignal<T>
		local head: IAS.Node<T>?

		local function createConnection(node: IAS.Node<T>): IAS.IAScriptConnection
			local conn: IAS.IAScriptConnection
			conn = {
				Connected = true,
				Disconnect = function(self: IAS.IAScriptConnection)
					if not self.Connected then return end
					self.Connected = false
					node.fn = nil

					if node.prev then
						node.prev.next = node.next
					else
						head = node.next
					end

					if node.next then
						node.next.prev = node.prev
					end

					node.next = nil
					node.prev = nil
				end,
			}

			return conn
		end

		local Signal: IAS.IAScriptSignal<T> = {
			Connect = function(self: IAS.IAScriptSignal<T>, fn: IAS.func<T>): IAS.IAScriptConnection
				local node: IAS.Node<T> = {
					fn = fn,
					next = head,
					prev = nil,
				}

				if head then
					head.prev = node
				end
				head = node

				return createConnection(node)
			end,

			Once = function(self: IAS.IAScriptSignal<T>, fn: IAS.func<T>): IAS.IAScriptConnection
				local conn: IAS.IAScriptConnection
				conn = self:Connect(function(active: T, pressed: boolean?)
					if conn.Connected then
						conn:Disconnect()
						fn(active, pressed)
					end
				end)

				return conn
			end,

			Wait = function(self: IAS.IAScriptSignal<T>): (T, boolean?)
				local thread = coroutine.running()
				local conn: IAS.IAScriptConnection

				conn = self:Connect(function(active: T, pressed: boolean?)
					if conn.Connected then
						conn:Disconnect()
					end
					task.spawn(thread, active, pressed)
				end)

				return coroutine.yield()
			end,

			Fire = function(self: IAS.IAScriptSignal<T>, active: T, pressed: boolean?)
				local node = head
				while node do
					local fn = node.fn
					node = node.next
					if fn then
						task.spawn(fn, active, pressed)
					end
				end
			end,

			DisconnectAll = function(self: IAS.IAScriptSignal<T>)
				local node = head
				while node do
					node.fn = nil
					local nextNode = node.next
					node.next = nil
					node.prev = nil
					node = nextNode
				end
				head = nil
			end,
		}

		return Signal
	end,
}
