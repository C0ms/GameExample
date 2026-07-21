-- @ScriptType: ModuleScript
--[[
	Author - RobloxJrTrainer
	This is a public module that allows the global coordination of signals between different scripts
]]
-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local POLLING_INTERVAL = 0.1

-- IMPORTS --

local Coordinator = {
	_awaitingCoroutines = {}
}
local created = {}

-- PRIVATE FUNCTIONS --

-- PUBLIC FUNCTIONS --

--[[
	Register a signal to the 'created' table for storage
	@param id - string: The id of the Signal to register
	@param signal - any: The actual Signal class/object
	@return boolean: Whether or not it was successful
]]
function Coordinator.register(id: string, signal: any)
	-- Make sure 'id' is passed
	if not id or type(id) ~= "string" then
		warn(("id expects a string, got %s"):format(tostring(id)))
		return false
	end
	if created[id] then
		warn(("Already found a created signal with ID %s"):format(id))
		return false
	end
	created[id] = signal
	-- Notify any yielded coroutines (suspended)
	if Coordinator._awaitingCoroutines[id] then
		-- Resume all waiting co's
		for _, co in ipairs(Coordinator._awaitingCoroutines[id]) do
			-- Is it yielded?
			if coroutine.status(co) ~= "suspended" then
				continue
			end
			--Log.print(("Sending continuation call for awaiting %s to continue!"):format(tostring(co)))
			task.spawn(co) -- Starts the coroutine, which should begin at the yield statement
		end
		-- Clear waiting list for this signal
		Coordinator._awaitingCoroutines[id] = nil
		--Log.print("Detected new Signal, clearing _awaitingCoroutines for this id:", Coordinator._awaitingCoroutines)
	end
	return true
end

--[[
	Unregisters a signal from the 'created' table to be gc'ed
	@param id - string: The id of the signal to unregister
]]
function Coordinator.unregister(id: string)
	-- Is this id part of a created signal?
	if not created[id] then
		return
	end
	created[id] = nil
end

--[[
	For cases where one script tries to connect to a Signal that isn't created yet, this function yields until it is created.
	@param timeout - number: Seconds in which it should timeout after not finding it (Default: 500000s)
	@param id - string: The id of the signal that should exist
	@return any: The signal object or nil if timeout occured
]]
function Coordinator.await(id: string, timeout: number): any
	-- First attempt
	local signal = created[id]
	-- Is it already present?
	if signal then
		return signal
	end
	timeout = timeout or 500000
	-- Create a Promise-like structure
	local co = coroutine.running()
	--Log.print(("I stored the current coroutine %s"):format(tostring(co)))
	-- Store this co in a lookup table
	-- Initialize entry for this signal id if needed
	Coordinator._awaitingCoroutines[id] = Coordinator._awaitingCoroutines[id] or {}
	table.insert(Coordinator._awaitingCoroutines[id], co)
	--Log.print("I Initialized necessary tables:", Coordinator._awaitingCoroutines)
	-- Setup timeout handling
	local timeoutDelay
	timeoutDelay = task.delay(timeout, function()
		--Log.print("Timeout detected...")
		timeoutDelay = nil
		-- Find and remove this coroutine from the waiters list
		if not Coordinator._awaitingCoroutines[id] then
			return
		end
		for i, waitingCo in ipairs(Coordinator._awaitingCoroutines[id]) do
			if waitingCo ~= co then
				continue
			end
			table.remove(Coordinator._awaitingCoroutines[id], i)
			--Log.print("Removed waiting coroutine for id: " .. id .. " | _awaitingCoroutines list:", Coordinator._awaitingCoroutines[id])
			-- No table cleanup is necessary
			break
		end
		-- resume with nil to indicate timeout
		-- Is it yielded?
		if coroutine.status(co) == "suspended" then
			--Log.print(("Sending continuation call for awaiting %s to continue!"):format(tostring(co)))
			coroutine.resume(co)
		end
	end)
	-- Yield until signal is found or timeout occurs
	--Log.print("Waiting until continuation call...")
	coroutine.yield()
	--Log.print("Received continuation call!")
	-- Signal was found or timed out
	signal = created[id]
	if timeoutDelay then
		task.cancel(timeoutDelay)
		--Log.print("I noticed timeoutDelay was still active, so I cancelled it")
	end
	--Log.print("Ending with Signal value of:", signal)
	-- Return the signal (or nil if none was found)
	return signal
end

--[[
	Get a specific signal from ID. If the signal isn't present, AND timeout is > 0, it yields until it is present.
	(WARNING: Yields if Signal is not present at this time indefinitely or until 100000s. If timeout is not needed, please default to '0')
	@param id - string: The id for the signal that is being looked for
	@param timeout - number: Seconds in which it should timeout after not finding it (Default: 500000s)
	@return any: The signal returned from 'id'
]]
function Coordinator.get(id: string, timeout: number): any
	if not id or type(id) ~= "string" then
		warn(("id expects a string, got %s"):format(tostring(id)))
		return nil
	end
	local signal = created[id]
	local applyTimeout = type(timeout) == "number" and timeout > 0 or true
	-- If it timeout is nil or not a number, it should default to true, if timeout is not nil and is a number,
	-- then it checks whether the timeout is greater than 0, if it is, then it is also going to apply timeout
	if not signal and applyTimeout then
		-- If not present, then call the await function
		signal = Coordinator.await(id, timeout)
	end
	return signal
end

--[[
	Detect whether a Signal is already created
	@param id - string: The id of the signal to check
	@return boolean: True if it exists, false if not
]]
function Coordinator.is(id: string): boolean
	return created[id] ~= nil
end

--[[
	Main function to connect a signal in one-step from an 'id'
	(WARNING: Yields if Signal is not present at this time indefinitely or until 100000s)
	@param id - string: The id for the signal that is being looked for
	@param fn - function: The function to run when signal is fired
	@return any: A connection object or nil if failed
]]
function Coordinator.connect(id: string, fn: () -> ()?): any
	-- Strict validation
	assert(typeof(id) == "string", "id expects a string data-type")
	assert(typeof(fn) == "function", "fn expects a function data-type")
	-- Get the signal object directly from .get() function
	local signal = Coordinator.get(id)
	if not signal then
		-- Create an error
		error(("Id: %q is not a valid member of 'created'"):format(id))
	end
	-- Return the value (Connection object) from :Connect() method
	return signal:Connect(fn)
end

--[[
	Yields for a signal to fire and instantly disconnects in one-step from an 'id'
	(WARNING: Yields if Signal is not present at this time indefinitely or until 100000s)
	@param id - string: The id for the signal that is being looked for
	@return ... - any: The arguments that were fired with the signal
]]
function Coordinator.wait(id: string): any
	-- Strict validation
	assert(typeof(id) == "string", "id expects a string data-type")
	local signal = Coordinator.get(id)
	if not signal then
		-- Create an error
		error(("Id: %q is not a valid member of 'created'"):format(id))
	end
	-- Return the arguments from :Wait()
	return signal:Wait()
end

--[[
	Disconnects all connections associated with the Signal given from the id.
	If signal is not present, it ends prematurely
	@param id - string: The id of the signal
]]
function Coordinator.disconnectAll(id: string)
	assert(type(id) == "string", "id expects a string data-type")
	local signal = Coordinator.get(id, 0)
	if not signal then
		return
	end
	-- Call the :DisconnectAll() method
	signal:DisconnectAll()
end

-- Returns All Created IDs
function Coordinator.getAll()
	return created
end

return Coordinator
