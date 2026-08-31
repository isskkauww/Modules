-- This is a new version

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local function IsExploit()
	return request and true or false
end

local FileSystemApiSupport = (writefile and readfile and isfile and makefolder and isfolder) and true or false

if FileSystemApiSupport and not isfolder("IconsLibCache") then
	makefolder("IconsLibCache")
end

local function HashString(str)
	local hash = 5381
	for i = 1, #str do
		hash = ((hash * 33) + string.byte(str, i)) % 4294967296
	end
	return string.format("%08x", hash)
end

local function UrlToFileName(url)
	local readableName = url:match("([^/]+)$") or "file"
	readableName = readableName:gsub("[^%w%.%-]", "_")
	return "IconsLibCache/" .. HashString(url) .. "_" .. readableName
end

local function ReadCache(url)
	if not FileSystemApiSupport then
		return nil
	end

	local path = UrlToFileName(url)
	if not isfile(path) then
		return nil
	end

	local ok, raw = pcall(readfile, path)
	if not ok or not raw or raw == "" then
		return nil
	end

	local okDecode, cached = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(cached) ~= "table" or type(cached.data) ~= "string" then
		return nil
	end

	return cached.data
end

local function ReadCacheEntry(url)
	if not FileSystemApiSupport then
		return nil
	end

	local path = UrlToFileName(url)
	if not isfile(path) then
		return nil
	end

	local ok, raw = pcall(readfile, path)
	if not ok or not raw or raw == "" then
		return nil
	end

	local okDecode, cached = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(cached) ~= "table" or type(cached.data) ~= "string" then
		return nil
	end

	return cached
end

local function WriteCache(url, content, hash)
	if not FileSystemApiSupport then
		return
	end

	local path = UrlToFileName(url)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode({
			time = os.time(),
			hash = hash,
			data = content,
		})
	end)
	if ok then
		pcall(writefile, path, encoded)
	end
end

local function Get(url, hash)
	local Success, Result
	if IsExploit() then
		Success, Result = pcall(game.HttpGet, game, url)
	else
		Success, Result = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if not Success then
			Success, Result = pcall(function()
				return ReplicatedStorage:WaitForChild("Request", 9999):InvokeServer({ Url = url })
			end)
		end
	end

	if Success and Result and Result ~= "" then
		WriteCache(url, Result, hash)
		return Result
	end

	local cached = ReadCache(url)
	if cached then
		warn("Get: fetch failed for " .. url .. ", falling back to cached copy")
		return cached
	end

	error("Get: failed to fetch " .. url .. (Result and (" -> " .. tostring(Result)) or "") .. " and no cache available")
end

local function Loadstring(src)
	if not IsExploit() and ReplicatedStorage:WaitForChild("Loadstring", 9999) then
		return function()
			return ReplicatedStorage:WaitForChild("Loadstring", 9999):InvokeServer(src)
		end
	else
		return loadstring(src)
	end
end

local function FetchRaw(url)
	if IsExploit() then
		local ok, result = pcall(game.HttpGet, game, url)
		return (ok and result ~= "" and result) or nil
	else
		local ok, result = pcall(function()
			return HttpService:GetAsync(url)
		end)
		return (ok and result ~= "" and result) or nil
	end
end

local function GetRemoteSHAs()
	local raw = FetchRaw("https://api.github.com/repos/Footagesus/Icons/git/trees/main?recursive=1")
	if not raw then
		return nil
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" or type(decoded.tree) ~= "table" then
		return nil
	end

	local shas = {}
	for _, entry in ipairs(decoded.tree) do
		if entry.type == "blob" then
			shas["/" .. entry.path] = "gh:" .. entry.sha
		end
	end
	return shas
end

local function GetRemoteHashes()
	local raw = FetchRaw("https://data.jsdelivr.com/v1/package/gh/Footagesus/Icons@main/flat")
	if not raw then
		return nil
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" or type(decoded.files) ~= "table" then
		return nil
	end

	local hashes = {}
	for _, file in ipairs(decoded.files) do
		hashes[file.name] = "jsd:" .. file.hash
	end
	return hashes
end

local function GetRemoteVersions()
	return GetRemoteSHAs() or GetRemoteHashes() or {}
end

local remoteVersions = (IsExploit() and FileSystemApiSupport) and GetRemoteVersions() or {}

local function GetPack(path)
	local url = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/" .. path
	local cacheEntry = ReadCacheEntry(url)
	local remoteVersion = remoteVersions["/" .. path]

	if cacheEntry and remoteVersion and cacheEntry.hash == remoteVersion then
		return cacheEntry.data
	end

	return Get(url, remoteVersion)
end

local IconModule = {
	IconsType = "lucide",

	New = nil,
	IconThemeTag = nil,

	Icons = {
		lucide = IsExploit() and Loadstring(GetPack("lucide/dist/Icons.lua"))() or require("./lucide/dist/Icons"),
		solar = IsExploit() and Loadstring(GetPack("solar/dist/Icons.lua"))() or require("./solar/dist/Icons"),
		craft = IsExploit() and Loadstring(GetPack("craft/dist/Icons.lua"))() or require("./craft/dist/Icons"),
		geist = IsExploit() and Loadstring(GetPack("geist/dist/Icons.lua"))() or require("./geist/dist/Icons"),
		sfsymbols = IsExploit() and Loadstring(GetPack("sfsymbols/dist/Icons.lua"))() or require("./sfsymbols/dist/Icons"),
		gravity = IsExploit() and Loadstring(GetPack("gravity/dist/Icons.lua"))() or require("./gravity/dist/Icons"),
	},
}

local function parseIconString(iconString)
	if type(iconString) == "string" then
		local splitIndex = iconString:find(":")
		if splitIndex then
			local iconType = iconString:sub(1, splitIndex - 1)
			local iconName = iconString:sub(splitIndex + 1)
			return iconType, iconName
		end
	end
	return nil, iconString
end

function IconModule.AddIcons(packName, iconsData)
	if type(packName) ~= "string" or type(iconsData) ~= "table" then
		error("AddIcons: packName must be string, iconsData must be table")
		return
	end

	if not IconModule.Icons[packName] then
		IconModule.Icons[packName] = {
			Icons = {},
			Spritesheets = {},
		}
	end

	for iconName, iconValue in pairs(iconsData) do
		if type(iconValue) == "number" or (type(iconValue) == "string" and iconValue:match("^rbxassetid://")) then
			local imageId = iconValue
			if type(iconValue) == "number" then
				imageId = "rbxassetid://" .. tostring(iconValue)
			end

			IconModule.Icons[packName].Icons[iconName] = {
				Image = imageId,
				ImageRectSize = Vector2.new(0, 0),
				ImageRectPosition = Vector2.new(0, 0),
				Parts = nil,
			}
			IconModule.Icons[packName].Spritesheets[imageId] = imageId
		elseif type(iconValue) == "table" then
			if iconValue.Image and iconValue.ImageRectSize and iconValue.ImageRectPosition then
				local imageId = iconValue.Image
				if type(imageId) == "number" then
					imageId = "rbxassetid://" .. tostring(imageId)
				end

				IconModule.Icons[packName].Icons[iconName] = {
					Image = imageId,
					ImageRectSize = iconValue.ImageRectSize,
					ImageRectPosition = iconValue.ImageRectPosition,
					Parts = iconValue.Parts,
				}

				if not IconModule.Icons[packName].Spritesheets[imageId] then
					IconModule.Icons[packName].Spritesheets[imageId] = imageId
				end
			else
				warn("AddIcons: Invalid spritesheet data format for icon '" .. iconName .. "'")
			end
		else
			warn("AddIcons: Unsupported data type for icon '" .. iconName .. "': " .. type(iconValue))
		end
	end
end

function IconModule.SetIconsType(iconType)
	IconModule.IconsType = iconType
end

function IconModule.Init(New, IconThemeTag)
	IconModule.New = New
	IconModule.IconThemeTag = IconThemeTag

	return IconModule
end

function IconModule.Icon(Icon, Type, DefaultFormat)
	DefaultFormat = DefaultFormat ~= false
	local iconType, iconName = parseIconString(Icon)

	local targetType = iconType or Type or IconModule.IconsType
	local targetName = iconName

	local iconSet = IconModule.Icons[targetType]

	if iconSet and iconSet.Icons and iconSet.Icons[targetName] then
		return {
			iconSet.Spritesheets[tostring(iconSet.Icons[targetName].Image)],
			iconSet.Icons[targetName],
		}
	elseif iconSet and iconSet[targetName] and string.find(iconSet[targetName], "rbxassetid://") then
		return DefaultFormat
				and {
					iconSet[targetName],
					{ ImageRectSize = Vector2.new(0, 0), ImageRectPosition = Vector2.new(0, 0) },
				}
			or iconSet[targetName]
	end
	return nil
end

function IconModule.GetIcon(Icon, Type)
	return IconModule.Icon(Icon, Type, false)
end

function IconModule.Icon2(Icon, Type, DefaultFormat)
	return IconModule.Icon(Icon, Type, true)
end

function IconModule.Image(IconConfig)
	local Icon = {
		Icon = IconConfig.Icon or nil,
		Type = IconConfig.Type,
		Colors = IconConfig.Colors or { (IconModule.IconThemeTag or Color3.new(1, 1, 1)), Color3.new(1, 1, 1) },
		Size = IconConfig.Size or UDim2.new(0, 24, 0, 24),

		IconFrame = nil,
	}

	local Colors = {}

	for _, color in next, Icon.Colors do
		Colors[_] = {
			ThemeTag = typeof(color) == "string" and color,
			Color = typeof(color) == "Color3" and color,
		}
	end

	local IconLabel = IconModule.Icon2(Icon.Icon, Icon.Type)
	local isrbxassetid = typeof(IconLabel) == "string" and string.find(IconLabel, "rbxassetid://")

	if IconModule.New then
		local New = IconModule.New

		local IconFrame = New("ImageLabel", {
			Size = Icon.Size,
			BackgroundTransparency = 1,
			ImageColor3 = Colors[1].Color or nil,
			ThemeTag = Colors[1].ThemeTag and {
				ImageColor3 = Colors[1].ThemeTag,
			},
			Image = isrbxassetid and IconLabel or IconLabel[1],
			ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize,
			ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition,
		})

		if not isrbxassetid and IconLabel[2].Parts then
			for _, part in next, IconLabel[2].Parts do
				local IconPartLabel = IconModule.Icon(part, Icon.Type)

				local IconPart = New("ImageLabel", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					ImageColor3 = Colors[1 + _].Color or nil,
					ThemeTag = Colors[1 + _].ThemeTag and {
						ImageColor3 = Colors[1 + _].ThemeTag,
					},
					Image = IconPartLabel[1],
					ImageRectSize = IconPartLabel[2].ImageRectSize,
					ImageRectOffset = IconPartLabel[2].ImageRectPosition,
					Parent = IconFrame,
				})
			end
		end

		Icon.IconFrame = IconFrame
	else
		local IconFrame = Instance.new("ImageLabel")
		IconFrame.Size = Icon.Size
		IconFrame.BackgroundTransparency = 1
		IconFrame.ImageColor3 = Colors[1].Color or nil
		IconFrame.Image = isrbxassetid and IconLabel or IconLabel[1]
		IconFrame.ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize
		IconFrame.ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition

		if not isrbxassetid and IconLabel[2].Parts then
			for _, part in next, IconLabel[2].Parts do
				local IconPartLabel = IconModule.Icon(part, Icon.Type)

				local IconPart = Instance.new("ImageLabel")
				IconPart.Size = UDim2.new(1, 0, 1, 0)
				IconPart.BackgroundTransparency = 1
				IconPart.ImageColor3 = Colors[1 + _].Color or nil
				IconPart.Image = IconPartLabel[1]
				IconPart.ImageRectSize = IconPartLabel[2].ImageRectSize
				IconPart.ImageRectOffset = IconPartLabel[2].ImageRectPosition
				IconPart.Parent = IconFrame
			end
		end

		Icon.IconFrame = IconFrame
	end

	return Icon
end

return IconModule
