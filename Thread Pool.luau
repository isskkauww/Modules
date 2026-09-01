--------------------------------------------------------------------------------
--                      N-Slot Cached Coroutine Thread Pool                   --
-- This is a generalization of the runner-coroutine caching technique used    --
-- by GoodSignal (stravant), extended from a single cached thread to a pool   --
-- of N idle threads, and detached from the Signal/Connection API so it can   --
-- be used to run any arbitrary function.                                     --
--                                                                            --
-- Like GoodSignal, each dispatched function runs in its own coroutine, so    --
-- yielding inside it (task.wait, RunService events, etc.) never blocks the   --
-- caller or other dispatched functions. Unlike GoodSignal's single           --
-- freeRunnerThread, this keeps a growable list of idle threads, so bursts    --
-- of many concurrently-yielding calls can still reuse threads across         --
-- frames instead of degrading to "always allocate a new coroutine".         --
--                                                                            --
-- API:                                                                       --
--   local ThreadPool = require(THIS MODULE)                                  --
--   ThreadPool:Spawn(fn, ...)        -- run fn(...) on a pooled thread       --
--   ThreadPool:Prewarm(amount)       -- pre-allocate `amount` idle threads   --
--   ThreadPool:Clear()               -- drop all idle threads (let them GC)  --
--   ThreadPool:Destroy()             -- Clear() + detach the metatable       --
--   ThreadPool:Count()               -- number of idle threads in the pool  --
--------------------------------------------------------------------------------
--!strict
--!optimize 2

export type ThreadPool = {
	free: { thread },
	Spawn: <A...>(self: ThreadPool, fn: (A...) -> (), ...: A...) -> (),
	Prewarm: (self: ThreadPool, amount: number) -> (),
	Clear: (self: ThreadPool) -> (),
	Destroy: (self: ThreadPool) -> (),
	Count: (self: ThreadPool) -> number,
}

local ThreadPool = {}
ThreadPool.__index = ThreadPool

-- Aliasing globals (micro optimization)
local spawn = task.spawn
local yield = coroutine.yield
local running = coroutine.running
local create = coroutine.create
local resume = coroutine.resume
local insert = table.insert
local remove = table.remove
local clear = table.clear
local setmetatable = setmetatable

-- Runs fn(...) to completion, then returns the currently-running thread
-- (i.e. itself) to the pool's free list so it can be reused for the next
-- Spawn call instead of allocating a fresh coroutine.
local function CallAndRelease(self, fn, ...)
	fn(...)
	-- fn finished, thread is idle now: return it to the pool
	insert(self.free, running())
end

-- Coroutine body every pooled thread runs. It parks on yield() waiting to
-- be handed a function to run; after CallAndRelease finishes with one job,
-- it loops straight back to yield() to wait for the next one, so a single
-- coroutine can serve an unlimited number of Spawn calls over its lifetime.
local function Worker(self)
	while true do
		-- yield() blocks here until :Spawn resumes this thread with (fn, ...)
		CallAndRelease(self, yield())
	end
end

function ThreadPool.new()
	return setmetatable({ free = {} }, ThreadPool)
end

-- Dispatches fn(...) onto a coroutine. If the pool has an idle thread
-- (previously released by CallAndRelease), that thread is popped and
-- reused; otherwise a brand new one is created and primed. Because fn
-- runs on its own coroutine, it's free to yield without blocking the
-- caller or any other in-flight Spawn call.
function ThreadPool:Spawn(fn, ...)
	local thread

	if #self.free > 0 then
		-- reuse an idle thread instead of allocating a new coroutine
		thread = remove(self.free)
	else
		thread = create(Worker)
		resume(thread, self) -- prime it: runs until the first yield() in Worker
	end

	spawn(thread, fn, ...)
end

-- Pre-allocates `amount` idle threads up front and parks them in the pool,
-- so the first `amount` calls to :Spawn don't pay the cost of creating and
-- priming a new coroutine.
function ThreadPool:Prewarm(amount)
	for _ = 1, amount do
		local thread = create(Worker)
		resume(thread, self) -- prime it, then park it in free ready to use
		insert(self.free, thread)
	end
end

-- Drops every idle thread from the pool. They aren't force-killed, just
-- unreferenced here, so they'll simply be garbage collected.
function ThreadPool:Clear()
	clear(self.free)
end

-- Clears the pool and detaches the metatable, so any further :Spawn/etc.
-- call on this instance fails loudly instead of silently doing nothing.
function ThreadPool:Destroy()
	clear(self.free)
	setmetatable(self, nil)
end

-- Number of threads currently idle and ready for reuse (not the number of
-- threads currently running a job).
function ThreadPool:Count()
	return #self.free
end

return ThreadPool.new()