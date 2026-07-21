-- @ScriptType: ModuleScript
--[[
	RobloxJrTrainer
	Private module specific for the Signal class for handling Connections
]]

-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTS --

-- VARIABLES --
local Connection = {}
Connection.__index = Connection

-- Make Connection strict
setmetatable(Connection, {
	__index = function(_, k)
		error(("Attempt to set Connection: %q, but not valid member"):format(tostring(k)))
	end,
	__newIndex = function(_, k, _)
		error(("Attempt to set Connection: %q, but not valid member"):format(tostring(k)))
	end,
})

-- PRIVATE FUNCTIONS --

--[[
	Creates a new connection between a signal and a function handler
    
    @param signal - The signal this connection belongs to
    @param fn - The function to call when the signal fires
    @return any - A connection object with disconnect capabilities
]]
function Connection.new(signal: any, fn: (...any) -> ()): any
	assert(type(fn) == "function", ("fn expects a function, got %s"):format(tostring(fn)))
	local self = {
		_connected = true, -- is this connection active?
		_fn = fn, -- handler fn
		_signal = signal,
		_later = false -- next connection in linked list
	}
	return setmetatable(self, Connection)
end

-- PRIVATE METHODS --

--[[
	Removes a signals head from a linked list
	(0(1) operation if we're the head)
]]
function Connection:_RemoveFromLinkedList()
	local head = self._signal._head
	if self._signal._head ~= self then
		-- _head is not equal to self
		-- Find our predecessor in the list
		local preceding = self._signal._head
		while preceding and preceding._later ~= self do
			preceding = preceding._later
		end
		-- Update chain
		if preceding then
			preceding._later = self._later
		end
		return nil
	end
	-- _head is equal to self
	-- We're the first connection, just update the head
	self._signal._head = self._later
	return nil
end

--[[
 	Disconnects this connection from its signal.
    Uses optimized linked list operations for fast disconnection.
    Only clears necessary references
]]
function Connection:Disconnect()
	-- Return in mistakes of multiple disconnects
	if not self._connected then
		return
	end
	-- Flag as disconnected immediately
	self._connected = false
	-- Remove from linked list
	self._signal = {}
	self._fn = nil
	self._later = false
	self:_RemoveFromLinkedList(self)
	--Log.print("I disconnected a connection. Self table:", self)
end

return Connection
