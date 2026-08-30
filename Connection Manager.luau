--[[ Connection Manager ]]

--!optimize 2

export type EventLike = {
	Connect: (self: any, callback: (...any) -> ()) -> any,
}

export type ConnectionHandle = {
	Connected: boolean,
	Disconnect: (self: ConnectionHandle) -> (),
}

export type BatchConnectEntry = {
	event: EventLike,
	callback: (...any) -> (),
	name: string?,
	tags: {string}?,
	source: Instance?,
}

export type ConnectionManager = {
	Conn: {[string]: any},
	Tags: {[string]: {[string]: boolean}},
	PrCnt: number,
	PruneCursor: string?,
	Connect: (self: ConnectionManager, event: EventLike | {BatchConnectEntry}, callback: ((...any) -> ())?, name: string?, tags: {string}?, source: Instance?) -> ConnectionHandle? | {[any]: ConnectionHandle?},
	Disconnect: (self: ConnectionManager, names: string | {string}) -> boolean | number,
	DisconnectByTag: (self: ConnectionManager, tag: string) -> number,
	GetByTag: (self: ConnectionManager, tag: string) -> {string},
	HasTag: (self: ConnectionManager, name: string, tag: string) -> boolean,
	DisconnectByPrefix: (self: ConnectionManager, prefix: string) -> number,
	DisconnectByPattern: (self: ConnectionManager, pattern: string) -> number,
	DisconnectAll: (self: ConnectionManager) -> (),
	IsConnected: (self: ConnectionManager, name: string) -> boolean,
	SetActive: (self: ConnectionManager, names: string | {string} | {[string]: boolean}, state: boolean?) -> number,
	IsActive: (self: ConnectionManager, names: string | {string}) -> boolean | {[string]: boolean},
	Prune: (self: ConnectionManager) -> number,
	PauseAll: (self: ConnectionManager) -> (),
	ResumeAll: (self: ConnectionManager) -> (),
	Get: (self: ConnectionManager, name: string) -> ConnectionHandle?,
	Rename: (self: ConnectionManager, oldName: string, newName: string) -> boolean,
}

local Bind = {}
Bind.__index = Bind

local PRUNE_BUDGET = 32 -- max entries checked per amortized prune step

function Bind.new()
	local self = setmetatable({}, Bind)
	self.Conn = {}
	self.Tags = {}
	self.PrCnt = 0
	self.PruneCursor = nil
	return self
end

local function IsConnLive(conn)
	if typeof(conn) == "RBXScriptConnection" then
		return conn.Connected
	elseif type(conn) == "table" and type(conn.connected) == "boolean" then
		return conn.connected
	else
		-- fallback for connection-like objects exposing Connected as a property/method
		local ok, res = pcall(function() return conn.Connected end)
		return ok and res == true
	end
end

local function Prune(self, name)
	local entry = self.Conn[name]
	if entry == nil then return false end
	local IsLive = IsConnLive(entry.conn)
	if not IsLive then
		self:Disconnect(name)
	end
	return IsLive
end

local function PruneStep(self)
	local count = 0
	local cursor = self.PruneCursor
	if cursor ~= nil and self.Conn[cursor] == nil then
		cursor = nil
	end
	local key = next(self.Conn, cursor)
	if key == nil then
		self.PruneCursor = nil
		return 0
	end
	-- walk a bounded slice per call instead of the whole table, spreading the cost across many Connect calls
	while count < PRUNE_BUDGET and key ~= nil do
		local nextKey = next(self.Conn, key)
		Prune(self, key)
		count += 1
		key = nextKey
	end
	self.PruneCursor = key
	return count
end

local function RegisterTags(self, name, tags)
	if not tags then return end
	for _, tag in ipairs(tags) do
		if not self.Tags[tag] then self.Tags[tag] = {} end
		self.Tags[tag][name] = true
	end
end

local function UnregisterTags(self, entry)
	if not entry or not entry.tags then return end
	for _, tag in ipairs(entry.tags) do
		local bucket = self.Tags[tag]
		if bucket then
			bucket[entry.name] = nil
			if next(bucket) == nil then self.Tags[tag] = nil end
		end
	end
end

local function MakeHandle(self, entry)
	if entry.handle then return entry.handle end
	-- proxy so callers get a stable handle without reaching into the internal entry table
	local handle = setmetatable({}, {
		__index = function(_, key)
			if key == "Connected" then
				if self.Conn[entry.name] ~= entry then return false end
				return IsConnLive(entry.conn)
			elseif key == "Disconnect" then
				return function()
					if self.Conn[entry.name] == entry then
						self:Disconnect(entry.name)
					end
				end
			end
			return nil
		end,
	})
	entry.handle = handle
	return handle
end

function Bind:Connect(event, callback, name, tags, source)
	if type(event) == "table" and callback == nil then
		-- batch form: array of {event, callback, name, tags, source} tables
		local results = {}
		for i, entry in ipairs(event) do
			local key = entry.name or i
			results[key] = self:Connect(entry.event, entry.callback, entry.name, entry.tags, entry.source)
		end
		return results
	end
	if not event or type(callback) ~= "function" then return nil end
	if name ~= nil and type(name) ~= "string" then return nil end
	if not name then
		return event:Connect(callback)
	end
	self:Disconnect(name)
	local tagsCopy
	if tags then
		-- copy so later mutation of the caller's tags table can't corrupt internal state
		tagsCopy = {}
		for i, tag in ipairs(tags) do
			tagsCopy[i] = tag
		end
	end
	local entry = { active = true, name = name, tags = tagsCopy }
	local conn = event:Connect(function(...)
		if entry.active then callback(...) end
	end)
	entry.conn = conn
	entry.cleanup = function()
		conn:Disconnect()
		if entry.sourceConn then
			entry.sourceConn:Disconnect()
		end
	end
	if typeof(source) == "Instance" then
		-- auto-disconnect this entry if the source instance gets destroyed
		entry.sourceConn = source.Destroying:Connect(function()
			self:Disconnect(entry.name)
		end)
	end
	self.Conn[name] = entry
	RegisterTags(self, name, tagsCopy)
	self.PrCnt += 1
	if self.PrCnt % 128 == 0 then PruneStep(self) end -- amortized sweep, not on every single connect
	return MakeHandle(self, entry)
end

function Bind:Disconnect(names)
	if type(names) == "table" then
		-- batch form: disconnect a list of names at once
		local count = 0
		for _, name in ipairs(names) do
			if self:Disconnect(name) then count += 1 end
		end
		return count
	end
	if not names then return false end
	local entry = self.Conn[names]
	if not entry then return false end
	if entry.cleanup then pcall(entry.cleanup) end
	UnregisterTags(self, entry)
	self.Conn[names] = nil
	return true
end

function Bind:DisconnectByTag(tag)
	local bucket = self.Tags[tag]
	if not bucket then return 0 end
	local count = 0
	for name in pairs(bucket) do
		if self:Disconnect(name) then count += 1 end
	end
	return count
end

function Bind:GetByTag(tag)
	local bucket = self.Tags[tag]
	local result = {}
	if not bucket then return result end
	for name in pairs(bucket) do table.insert(result, name) end
	return result
end

function Bind:HasTag(name, tag)
	local bucket = self.Tags[tag]
	return bucket ~= nil and bucket[name] == true
end

function Bind:DisconnectByPrefix(prefix)
	if not prefix or prefix == "" then return 0 end
	local count = 0
	for name in pairs(self.Conn) do
		if name:sub(1, #prefix) == prefix then
			if self:Disconnect(name) then count += 1 end
		end
	end
	return count
end

function Bind:DisconnectByPattern(pattern)
	if not pattern or pattern == "" then return 0 end
	local patternOk = pcall(string.match, "", pattern) -- guard against a malformed Lua pattern
	if not patternOk then return 0 end
	local count = 0
	for name in pairs(self.Conn) do
		if name:match(pattern) then
			if self:Disconnect(name) then count += 1 end
		end
	end
	return count
end

function Bind:DisconnectAll()
	for name in pairs(self.Conn) do
		self:Disconnect(name)
	end
end

function Bind:IsConnected(name)
	if not name then return false end
	return Prune(self, name) -- also lazily disconnects it here if it's found dead
end

function Bind:SetActive(names, state)
	local count = 0
	if state ~= nil then
		-- names is a single name or an array of names, all set to the same state
		if type(names) == "string" then
			local entry = self.Conn[names]
			if entry then
				entry.active = state and true or false
				count = 1
			end
			return count
		end
		for _, name in ipairs(names) do
			local entry = self.Conn[name]
			if entry then
				entry.active = state and true or false
				count += 1
			end
		end
	else
		-- names is a name -> state map, each entry gets its own state
		for name, s in pairs(names) do
			local entry = self.Conn[name]
			if entry then
				entry.active = s and true or false
				count += 1
			end
		end
	end
	return count
end

function Bind:IsActive(names)
	if type(names) == "string" then
		local entry = self.Conn[names]
		return entry ~= nil and entry.active or false
	end
	local result = {}
	for _, name in ipairs(names) do
		local entry = self.Conn[name]
		result[name] = entry ~= nil and entry.active or false
	end
	return result
end

function Bind:Prune()
	-- full sweep on demand, unlike PruneStep's bounded slice
	local count = 0
	for name in pairs(self.Conn) do
		if not Prune(self, name) then
			count += 1
		end
	end
	return count
end

function Bind:PauseAll()
	for _, entry in pairs(self.Conn) do
		entry.active = false
	end
end

function Bind:ResumeAll()
	for _, entry in pairs(self.Conn) do
		entry.active = true
	end
end

function Bind:Get(name)
	if not name then return nil end
	local entry = self.Conn[name]
	if not entry then return nil end
	return MakeHandle(self, entry)
end

function Bind:Rename(oldName, newName)
	if not oldName or not newName or oldName == newName then return false end
	local entry = self.Conn[oldName]
	if not entry then return false end
	if self.Conn[newName] then self:Disconnect(newName) end
	if entry.tags then
		-- move this entry's name into the tag buckets under the new name
		for _, tag in ipairs(entry.tags) do
			local bucket = self.Tags[tag]
			if bucket then
				bucket[oldName] = nil
				bucket[newName] = true
			end
		end
	end
	self.Conn[oldName] = nil
	entry.name = newName
	self.Conn[newName] = entry
	return true
end

return Bind.new()
