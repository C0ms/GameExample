-- @ScriptType: ModuleScript
--[[
	Author - RobloxJrTrainer
	Signal class for handling same script type communication. (Server --> Server | client --> client).
	Implements some 'Thread Pooling' for extra performance
]]

-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTS --
local Connection = require(script.Connection)
local Coordinator = require(script.Coordinator)

-- TYPES --
export type Connection = typeof(Connection)

-- CONSTANTS --
local THREAD_POOL_SIZE = 10
local DEBUG_ENABLED = true

-- VARIABLES --
local Signal = {}
Signal.__index = Signal

-- VARIABLE NEEDED TYPES --
export type Nexus = typeof(Signal)

setmetatable(Signal, {
	__index = function(_, k)
		error(("Attempt to set Signal: %q, but not a valid member"):format(tostring(k)))
	end,
	__newIndex = function(_, k, _)
		error(("Attempt to set Signal: %q, but not a valid member"):format(tostring(k)))
	end,
})

-- Local references in outer scope
local threads = {} -- Our pool of resuable threads
local threadPoolSize = 0 -- The current size of the pool
local acquiredThreads = {}
local threadState = {}

-- PRIVATE FUNCTIONS --

--[[
	Thread function that will run in our pooled coroutines
]]
local function runThreadFunctionInPool(fn, args)
	local currentThread = coroutine.running()
	-- Mark thread as busy
	threadState[currentThread] = true
	-- For the first and only time...
	local success, err = pcall(fn, table.unpack(args))
	if not success then
		-- Throw a warning
		warn(("Thread pool handler first time error: %s"):format(tostring(err)))
	end
	-- Mark thread as available
	threadState[currentThread] = false
	-- Enter infinite work loop
	while true do
		-- Yield and wait for next job
		--Log.print("Finished a job, returning to pool, yielding and waiting for next one!")
		fn, args = coroutine.yield()
		-- Mark as busy again
		threadState[currentThread] = true
		-- Execute next job
		local success, err = pcall(fn, table.unpack(args))
		if not success then
			-- Throw a warning
			warn(("Thread pool handler error: %s"):format(tostring(err)))
		end
		
		-- Mark as available again
		threadState[currentThread] = false
	end
end

local function getAvailableThread()
	-- Is the pool size valid? (Cannot loop through 0 or below)
	if threadPoolSize <= 0 then
		return
	end
	for i = 1, threadPoolSize do
		if threadState[threads[i]] then
			-- Busy
			continue
		end
		return i
	end
end

--[[
	Get a thread from the pool or create a new one.
	It is best for performance to have multiple items in a pool, not just one
]]
local function acquireThreadFromPool()
	local thread
	if threadPoolSize > 0 then
		-- Is this thread busy?
		local i = getAvailableThread()
		if i > 0 then
			--Log.print("I can reuse a thread...")
			thread = threads[i]
			-- Remove thread from pool (swap with last element for efficiency)
			threads[i] = threads[threadPoolSize]
			threads[threadPoolSize] = nil
			threadPoolSize -= 1
		else
			-- all pooled threads are busy, create a new one
			thread = coroutine.create(runThreadFunctionInPool)
		end
	else
		--Log.print("I cannot reuse a thread, as none were detected, but I can create a new one...")
		-- Create a new thread since pool is empty
		thread = coroutine.create(runThreadFunctionInPool)
	end
	acquiredThreads[thread] = true
	return thread
end

--[[
	Return a thread to the pool when done
]]
local function releaseThreadToPool(thread)
	-- Was this thread actually acquired?
	if acquiredThreads[thread] and not threadState[thread] then
		-- Add back to the pool if not over capacity
		if threadPoolSize < THREAD_POOL_SIZE then
			threadPoolSize += 1
			threads[threadPoolSize] = thread
			--Log.print(("I added a thread back to pool: %s"):format(tostring(thread)))
		end
		acquiredThreads[thread] = nil
		-- If at capacity, thread will be gc'ed
	end
end

--[[
	Run a function in a pooled thread
]]
local function runInPooledThread(fn, ...)
	local args = {...}
	-- Get a thread from pool
	local thread = acquireThreadFromPool()
	-- Run function in thread
	local success, err = coroutine.resume(thread, fn, args)
	-- Handle any errors
	if not success then
		warn(("Thread pool error: %s"):format(tostring(err)))
	end
	--[[
		What if signal callbacks fire other signals recursively? This creates a race condition
		where:
		1. Signal A fires and acquires Thread 1
		2. Inside Signal A's callback, new Signal B is fired
		3. Thread 1 is released back to the pool prematurely, while it is still running
		4. Signal B tries to acquire a thread, and may get Thread 1 again
		5. The same thread is now being used for two different operations simultaneously!
	]]
	-- Dont release immediately - release happens when thread marks itself as done
	local releaseThread = coroutine.create(function()
		-- Wait for threadState to be truthy
		repeat
			task.wait(0.01)
		until not threadState[thread]
		releaseThreadToPool(thread)
	end)
	coroutine.resume(releaseThread)
end

-- CONSTRUCTOR --

--[[
	Return a new Signal object.
	If 'id' is nil or not a string, it assigns a random GUID from HttpService
	(WARNING: Returns an existing signal if 'id' is present in a different Signal)
	@param id - string: The id of the Signal to create
	@return any: The Signal object
]]
function Signal.new(id: string?)
	if type(id) ~= "string" then
		-- Assign a random ID
		id = game:GetService("HttpService"):GenerateGUID(false)
	end

	if Coordinator.is(id) then
		return Coordinator.get(id)
	end

	local self = setmetatable({
		_connections = {},
		_connecting = false,
		_id = id,
		_head = false,
		_filterCounter = 1,
	}, Signal)

	Coordinator.register(id, self)
	return self
end

-- PUBLIC FUNCTIONS --

--[[
	Connect a function to this signal
    @param fn - function: The function to call when the signal fires
    @return Connection: A connection object that can be used to disconnect
]]
function Signal:Connect(fn: () -> ()): Connection
	assert(typeof(fn) == "function", ("fn expects a function data-type, got %s"):format(tostring(fn)))
	-- Create connection
	local connection = Connection.new(self, fn)
	-- Add to linked list (prepend is O(1))
	if self._head then
		connection._later = self._head
	end
	self._head = connection
	table.insert(self._connections, fn)
	self._connecting = false
	return connection
end

--[[
	Fire the signal with any arguments.
	Uses thread pooling for higher performance
	@param ... - any: Arguments to pass to the handlers
]]
function Signal:Fire(...: any) -- Parameter has any data
	-- prevent firing while connecting to prevent infinite loops
	if self._connecting then
		return
	end
	-- Traverse the linked list
	local connection = self._head
	while connection do
		if connection._connected then
			-- Use thread pooling to run the handler
			runInPooledThread(connection._fn, ...)
		end
		connection = connection._later
	end
end

--[[
	Wait for the signal to fire (yields)
	@return ... - any: The arguments that were fired with the signal
]]
function Signal:Wait()
	local thread = coroutine.running() -- Returns the current thread
	local connection -- Needs to be stored outside of :Connect() scope
	-- One-time connection that disconnects itself
	connection = self:Connect(function(...)
		-- Remove the connection first
		connection:Disconnect()
		-- Then resume the thread
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

--[[
	Creates a new Signal that only fires when the predicate returns true
    @param predicate - function: Function that determines if event should pass through
    @return Signal: A new signal that only fires for filtered events
]]
function Signal:Filter(predicate: (...any) -> boolean)
	-- Make sure to create a Unique ID each time.
	local uId = `{self._id}_filtered_{self._filterCounter}` -- IMPORTANT: Adds a number at the end, to prevent same ID signals
	local filteredSignal = Signal.new(uId)
	self._filterCounter += 1 -- Increments self._filterCounter each time a new Signal is successfully created
	-- Connect to source signal and filter events
	self:Connect(function(...)
		if predicate(...) then
			filteredSignal:Fire(...)
		end
	end)
	return filteredSignal
end

--[[
	Disconnect all connections from this signal.
]]
function Signal:DisconnectAll()
	local connection = self._head
	while connection do
		connection._connected = false
		connection._signal = {}
		connection = connection._later
	end
	self._head = false
	table.clear(self._connections)
end

--[[
	Destroys this signal completely.
	Cleans up all connections and references
]]
function Signal:Destroy()
	self:DisconnectAll()
	-- Remove from global registry if needed
	Coordinator.unregister(self._id)
	-- Clear all properties
	for k, _ in pairs(self) do
		self[k] = nil
	end
	-- Clear metatable
	setmetatable(self, nil)
end

return Signal
