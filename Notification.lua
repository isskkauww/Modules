local cloneref = (type(cloneref) == "function" and cloneref) or (type(clonereference) == "function" and clonereference) or function(X) return X end
local TweenService = cloneref(game:GetService("TweenService"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))

local FileSystemApiSupport = (writefile and readfile and isfile and makefolder and isfolder) and true or false

local LocalPlayer = Players.LocalPlayer

local function NewInstance(ClassName, Props)
	local Inst = Instance.new(ClassName)

	for Prop, Value in pairs(Props or {}) do
		Inst[Prop] = Value
	end

	local Chars = {}
	for Index = 1, 128 do
		Chars[Index] = string.char(math.random(128, 255))
	end
	Inst.Name = table.concat(Chars)

	if not (Props and Props.Parent) then
		local Ok, Parent = pcall(function()
			return (type(gethui) == "function" and gethui()) or cloneref(game:GetService("CoreGui"))
		end)
		Inst.Parent = (Ok and Parent) or LocalPlayer:WaitForChild("PlayerGui")
	end

	return Inst
end

local IconsLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/isskkauww/Modules/refs/heads/main/Icons.luau"))()

local function GetAsset(IconName)
	if type(IconName) ~= "string" or IconName == "" then
		return nil
	end

	local Result = IconsLib.GetIcon(IconName)
	if type(Result) == "string" then
		return {Url = Result, IconName = IconName, ImageRectSize = Vector2.zero, ImageRectOffset = Vector2.zero}
	end

	if type(Result) == "table" and Result[1] and Result[2] then
		return {Url = tostring(Result[1]), IconName = IconName, ImageRectSize = Result[2].ImageRectSize or Vector2.zero, ImageRectOffset = Result[2].ImageRectPosition or Vector2.zero}
	end
end

local function Tween(TargetInstance, Properties, Duration, Style, Direction)
	local Info = TweenInfo.new(
		Duration or 0.25,
		Style or Enum.EasingStyle.Quad,
		Direction or Enum.EasingDirection.Out
	)
	local PlayingTween = TweenService:Create(TargetInstance, Info, Properties)
	PlayingTween:Play()
	return PlayingTween
end

local function FadeGroup(Entries, Visible, Duration)
	local LastTween = nil
	for _, Entry in ipairs(Entries) do
		local Target = 1
		if Visible then
			Target = Entry.visible
		end
		LastTween = Tween(Entry.instance, {[Entry.property] = Target}, Duration or 0.15)
	end
	return LastTween
end

local function FadeGroupSnap(Entries, Visible)
	for _, Entry in ipairs(Entries) do
		local Target = 1
		if Visible then
			Target = Entry.visible
		end
		Entry.instance[Entry.property] = Target
	end
end

local FONT_OPTIONS = {
	{ Name = "GothamBold", Font = Enum.Font.GothamBold },
	{ Name = "Gotham", Font = Enum.Font.Gotham },
	{ Name = "SourceSansBold", Font = Enum.Font.SourceSansBold },
	{ Name = "ArialBold", Font = Enum.Font.ArialBold },
	{ Name = "Arcade", Font = Enum.Font.Arcade },
	{ Name = "Fantasy", Font = Enum.Font.Fantasy },
}

local POSITION_OPTIONS = {
	{ Name = "BottomRight", Label = "Bottom Right", XSide = "right", YSide = "bottom" },
	{ Name = "TopRight", Label = "Top Right", XSide = "right", YSide = "top" },
	{ Name = "BottomLeft", Label = "Bottom Left", XSide = "left", YSide = "bottom" },
	{ Name = "TopLeft", Label = "Top Left", XSide = "left", YSide = "top" },
}

local CurrentFont, CurrentFontName
for _, Option in ipairs(FONT_OPTIONS) do
	if Option.Name == "GothamBold" then
		CurrentFont, CurrentFontName = Option.Font, Option.Name
		break
	end
end
if not CurrentFont then
	CurrentFont, CurrentFontName = Enum.Font.GothamBold, "GothamBold"
end

local CurrentPositionOption
for _, Option in ipairs(POSITION_OPTIONS) do
	if Option.Name == "BottomRight" then
		CurrentPositionOption = Option
		break
	end
end
if not CurrentPositionOption then
	CurrentPositionOption = POSITION_OPTIONS[1]
end

local function SaveSettings()
	if not FileSystemApiSupport then return end
	pcall(function()
		writefile("Noname/Notification_Settings.json", HttpService:JSONEncode({ Font = CurrentFontName, Position = CurrentPositionOption.Name }))
	end)
end

local ActiveNotifs = {}
local NotifyScreenGui

local function GetBaseXY(FrameHeight, TotalOffset)
	local Opt = CurrentPositionOption
	local XScale, XOffset
	if Opt.XSide == "left" then XScale, XOffset = 0, 16 else XScale, XOffset = 1, -(320 + 16) end
	local YScale, YOffset
	if Opt.YSide == "top" then YScale, YOffset = 0, 24 + TotalOffset else YScale, YOffset = 1, -(FrameHeight + 24) - TotalOffset end
	return UDim2.new(XScale, XOffset, YScale, YOffset)
end

local function GetOffscreenX()
	local Opt = CurrentPositionOption
	if Opt.XSide == "left" then return 0, -(320 + 30) end
	return 1, 320 + 30
end

local function GetSlotPos(Index)
	local TotalOffset = 0
	for I = 1, Index - 1 do
		local D = ActiveNotifs[I]
		TotalOffset = TotalOffset + (D and D.frameHeight or 84) + 8
	end
	local H = ActiveNotifs[Index] and ActiveNotifs[Index].frameHeight or 84
	return GetBaseXY(H, TotalOffset)
end

local function PlayFrameTween(Data, Props, Duration, Style, Direction)
	if not Data or Data.dismissed or not Data.frame or not Data.frame.Parent then return nil end
	Data.positionToken = (Data.positionToken or 0) + 1
	if Data.positionTween then pcall(function() Data.positionTween:Cancel() end) end
	local PlayingTween = Tween(Data.frame, Props, Duration, Style, Direction)
	Data.positionTween = PlayingTween
	return PlayingTween, Data.positionToken
end

local function RepositionAll()
	local TotalOffset = 0
	for I, Data in ipairs(ActiveNotifs) do
		local FrameHeight = Data and Data.frameHeight or 84
		local Pos = GetBaseXY(FrameHeight, TotalOffset)
		if Data and Data.frame and Data.frame.Parent and not Data.dismissed then
			PlayFrameTween(Data, { Position = Pos }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
		TotalOffset = TotalOffset + FrameHeight + 8
	end
end

local function DismissNotif(Frame, Data)
	if not Data or Data.dismissed then return end
	Data.dismissed = true
	Data.paused = true
	if Data.positionTween then pcall(function() Data.positionTween:Cancel() end) end
	if Data.dismissTween then pcall(function() Data.dismissTween:Cancel() end) end

	if not Frame or not Frame.Parent then
		for I, D in ipairs(ActiveNotifs) do
			if D.frame == Frame then table.remove(ActiveNotifs, I) break end
		end
		if Data.dropdown then Data.dropdown:Destroy() end
		if Data.dropdownPos then Data.dropdownPos:Destroy() end
		RepositionAll()
		return
	end

	local CurrentPos = Frame.Position
	local ExitXScale, ExitXOffset = GetOffscreenX()
	local ExitPos = UDim2.new(ExitXScale, ExitXOffset, CurrentPos.Y.Scale, CurrentPos.Y.Offset)
	local DismissTween = Tween(Frame, { Position = ExitPos }, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Data.dismissTween = DismissTween
	local CompletedConnection = nil
	CompletedConnection = DismissTween.Completed:Connect(function()
		if CompletedConnection then CompletedConnection:Disconnect() CompletedConnection = nil end
		for I, D in ipairs(ActiveNotifs) do
			if D.frame == Frame then table.remove(ActiveNotifs, I) break end
		end
		Frame:Destroy()
		if Data.dropdown then Data.dropdown:Destroy() end
		if Data.dropdownPos then Data.dropdownPos:Destroy() end
		RepositionAll()
	end)
end

if FileSystemApiSupport then
	if not isfolder("Noname") then
		makefolder("Noname")
	end
	if not isfile("Noname/Notification_Settings.json") then
		SaveSettings()
	else
		local Ok, Decoded = pcall(function()
			return HttpService:JSONDecode(readfile("Noname/Notification_Settings.json"))
		end)
		if Ok and type(Decoded) == "table" then
			if type(Decoded.Font) == "string" then
				for _, Option in ipairs(FONT_OPTIONS) do
					if Option.Name == Decoded.Font then
						CurrentFont, CurrentFontName = Option.Font, Option.Name
						break
					end
				end
			end
			if type(Decoded.Position) == "string" then
				for _, Option in ipairs(POSITION_OPTIONS) do
					if Option.Name == Decoded.Position then
						CurrentPositionOption = Option
						break
					end
				end
			end
		end
	end
end

local function CreateNotifyScreenGui()
	NotifyScreenGui = NewInstance("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	NotifyScreenGui.Destroying:Connect(function()
		for I = #ActiveNotifs, 1, -1 do
			local D = ActiveNotifs[I]
			if D then
				D.dismissed = true
				D.paused = true
				if D.positionTween then pcall(function() D.positionTween:Cancel() end) end
				if D.dismissTween then pcall(function() D.dismissTween:Cancel() end) end
			end
			ActiveNotifs[I] = nil
		end
		CreateNotifyScreenGui()
	end)
end
CreateNotifyScreenGui()

local function Notify(Config)
	if not (NotifyScreenGui and NotifyScreenGui.Parent) then
		warn("notify ScreenGui unavailable")
		return nil
	end
	if type(Config) ~= "table" then Config = {} end

	local Title
	do
		local Value = Config.Title or "Notification"
		if type(Value) ~= "string" then Value = tostring(Value) end
		Value = Value:gsub("\r\n", " "):gsub("\n", " "):gsub("\r", " ")
		Value = Value:gsub("%s+", " ")
		Value = Value:gsub("^%s+", ""):gsub("%s+$", "")
		Title = Value
	end

	local Text
	do
		local Value = Config.Desc or Config.Description or ""
		if type(Value) ~= "string" then Value = tostring(Value) end
		Text = (Value:gsub("\r\n", "\n"):gsub("\r", "\n"))
	end

	local Duration = Config.Duration or 4
	if type(Duration) ~= "number" or Duration ~= Duration or Duration < 0 or Duration == math.huge or Duration == -math.huge then Duration = 4 end

	local CanClose = true
	if Config.CanClose ~= nil then
		CanClose = Config.CanClose and true or false
	end

	local TextTargets = {}

	local TextLabel = NewInstance("TextLabel", {
		Parent = NotifyScreenGui,
		Size = UDim2.new(0, 320 - 84, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Text = Text,
		TextSize = 11,
		Font = CurrentFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	RunService.Heartbeat:Wait()
	local TextHeight = math.max(11 + 2, TextLabel.AbsoluteSize.Y)
	local FrameHeight = 38 + TextHeight + 22

	local StartXScale, StartXOffset = GetOffscreenX()
	local StartSlot = GetBaseXY(FrameHeight, 0)
	local Frame = NewInstance("Frame", {
		Parent = NotifyScreenGui,
		Size = UDim2.new(0, 320, 0, FrameHeight),
		Position = UDim2.new(StartXScale, StartXOffset, StartSlot.Y.Scale, StartSlot.Y.Offset),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BorderSizePixel = 0,
		ZIndex = 10,
	})

	NewInstance("UICorner", { Parent = Frame, CornerRadius = UDim.new(0, 12) })

	local Stroke = NewInstance("UIStroke", {
		Parent = Frame,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.3,
	})

	local CloseBtn = NewInstance("TextButton", {
		Parent = Frame,
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "╳",
		TextColor3 = Color3.fromRGB(80, 80, 80),
		TextSize = 20,
		Font = CurrentFont,
		ZIndex = 13,
		Visible = CanClose,
		Active = CanClose,
	})
	table.insert(TextTargets, CloseBtn)

	CloseBtn.MouseEnter:Connect(function()
		Tween(CloseBtn, { TextColor3 = Color3.fromRGB(255, 255, 255) }, 0.15)
	end)
	CloseBtn.MouseLeave:Connect(function()
		Tween(CloseBtn, { TextColor3 = Color3.fromRGB(80, 80, 80) }, 0.15)
	end)

	local IconFrame = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 20, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 11,
		ClipsDescendants = true,
	})

	local CustomIconSet = false
	if type(Config.Icon) == "string" and Config.Icon ~= "" then
		local Asset = GetAsset(Config.Icon)
		if Asset then
			NewInstance("ImageLabel", {
				Parent = IconFrame,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Image = Asset.Url,
				ImageRectSize = Asset.ImageRectSize,
				ImageRectOffset = Asset.ImageRectOffset,
				ZIndex = 12,
			})
			CustomIconSet = true
		end
	end

	if not CustomIconSet then
		local IconImage = NewInstance("ImageLabel", {
			Parent = IconFrame,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 12,
		})

		task.spawn(function()
			local Ok, Thumb = pcall(function()
				return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if Ok and type(Thumb) == "string" and IconImage.Parent then IconImage.Image = Thumb end
		end)
	end

	local TitleLabel = NewInstance("TextLabel", {
		Parent = Frame,
		Size = UDim2.new(1, -176, 0, 16),
		Position = UDim2.new(0, 64, 0, 18),
		BackgroundTransparency = 1,
		Text = Title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		Font = CurrentFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 12,
	})
	table.insert(TextTargets, TitleLabel)

	TextLabel.Parent = Frame
	TextLabel.Size = UDim2.new(1, -84, 0, 0)
	TextLabel.Position = UDim2.new(0, 64, 0, 38)
	TextLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	TextLabel.ZIndex = 12
	TextLabel.Visible = true
	table.insert(TextTargets, TextLabel)

	local Data = { frame = Frame, frameHeight = FrameHeight, dismissed = false, paused = false, remaining = Duration, duration = Duration, positionTween = nil, positionToken = 0, dismissTween = nil }
	table.insert(ActiveNotifs, Data)

	CloseBtn.Activated:Connect(function()
		if not CanClose then return end
		DismissNotif(Frame, Data)
	end)

	local function PauseTimer()
		if Data.dismissed or Data.paused then return end
		Data.paused = true
	end

	local function ResumeTimer()
		if Data.dismissed or not Data.paused then return end
		Data.paused = false
	end

	local CloseAaDropdownFn, IsAaDropdownOpenFn
	local ClosePosDropdownFn, IsPosDropdownOpenFn

	local AaFrame = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -66, 0, 7),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 13,
	})
	NewInstance("UICorner", { Parent = AaFrame, CornerRadius = UDim.new(1, 0) })

	local AaStroke = NewInstance("UIStroke", {
		Parent = AaFrame,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1.25,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local AaBtn = NewInstance("TextButton", {
		Parent = AaFrame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "Aa",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		Font = CurrentFont,
		ZIndex = 14,
	})
	table.insert(TextTargets, AaBtn)

	local DropdownAaWidth = 190
	local DropdownAaHeight = 40 + (#FONT_OPTIONS * 37) + 14
	local DropdownAa = NewInstance("Frame", {
		Parent = NotifyScreenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
	})
	Data.dropdown = DropdownAa
	NewInstance("UICorner", { Parent = DropdownAa, CornerRadius = UDim.new(0, 12) })

	local DropdownAaStroke = NewInstance("UIStroke", {
		Parent = DropdownAa,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local FontDropdownFade = {}

	local DropdownAaTitle = NewInstance("TextLabel", {
		Parent = DropdownAa,
		Size = UDim2.new(1, -46, 0, 28),
		Position = UDim2.new(0, 14, 0, 6),
		BackgroundTransparency = 1,
		Text = "Font",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 17,
		Font = CurrentFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	table.insert(TextTargets, DropdownAaTitle)
	table.insert(FontDropdownFade, {instance = DropdownAaTitle, property = "TextTransparency", visible = 0})

	local DropdownAaClose = NewInstance("TextButton", {
		Parent = DropdownAa,
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "╳",
		TextColor3 = Color3.fromRGB(180, 180, 180),
		TextSize = 18,
		Font = CurrentFont,
		ZIndex = 22,
	})
	table.insert(TextTargets, DropdownAaClose)
	table.insert(FontDropdownFade, {instance = DropdownAaClose, property = "TextTransparency", visible = 0})

	local DropdownAaOpen = false
	local DropdownAaClosing = false
	local DropdownAaTween = nil
	local DropdownAaTweenToken = 0
	local FontButtons = {}
	local FontBtnFadeEntries = {}

	local function SetFontButtonsActive(Active)
		for _, FontButton in ipairs(FontButtons) do
			if FontButton and FontButton.Parent then
				FontButton.Active = Active
				FontButton.AutoButtonColor = false
			end
		end
	end

	local function CloseDropdownAa()
		if not DropdownAa.Visible or DropdownAaClosing then return end
		DropdownAaOpen = false
		DropdownAaClosing = true
		SetFontButtonsActive(false)
		DropdownAaTweenToken = DropdownAaTweenToken + 1
		local CloseToken = DropdownAaTweenToken
		if DropdownAaTween then pcall(function() DropdownAaTween:Cancel() end) end

		local FadeOutTween = FadeGroup(FontDropdownFade, false, 0.12)

		local function Collapse()
			if CloseToken ~= DropdownAaTweenToken then return end
			DropdownAaTween = Tween(DropdownAa, { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			Tween(DropdownAaStroke, { Transparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local CompletedConnection = nil
			CompletedConnection = DropdownAaTween.Completed:Connect(function()
				if CompletedConnection then CompletedConnection:Disconnect() CompletedConnection = nil end
				if CloseToken ~= DropdownAaTweenToken or DropdownAaOpen or Data.dismissed or not DropdownAa.Parent then return end
				DropdownAaClosing = false
				DropdownAa.Visible = false
				if not (IsPosDropdownOpenFn and IsPosDropdownOpenFn()) then
					ResumeTimer()
				end
			end)
		end

		if FadeOutTween then
			FadeOutTween.Completed:Once(Collapse)
		else
			Collapse()
		end
	end

	local function OpenDropdownAa()
		if DropdownAaOpen or Data.dismissed then return end
		DropdownAaOpen = true
		DropdownAaClosing = false
		SetFontButtonsActive(true)
		DropdownAaTweenToken = DropdownAaTweenToken + 1
		local OpenToken = DropdownAaTweenToken
		PauseTimer()
		DropdownAa.Visible = true
		DropdownAa.Size = UDim2.new(0, 0, 0, 0)
		DropdownAa.BackgroundTransparency = 1
		DropdownAaStroke.Transparency = 1
		FadeGroupSnap(FontDropdownFade, false)
		if DropdownAaTween then pcall(function() DropdownAaTween:Cancel() end) end
		DropdownAaTween = Tween(DropdownAa, { Size = UDim2.new(0, DropdownAaWidth, 0, DropdownAaHeight), BackgroundTransparency = 0 }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tween(DropdownAaStroke, { Transparency = 0.25 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		DropdownAaTween.Completed:Once(function()
			if OpenToken == DropdownAaTweenToken and DropdownAa.Visible then
				FadeGroup(FontDropdownFade, true, 0.15)
			end
		end)
	end

	CloseAaDropdownFn = CloseDropdownAa
	IsAaDropdownOpenFn = function() return DropdownAaOpen end

	AaBtn.MouseEnter:Connect(function()
		Tween(AaFrame, { BackgroundColor3 = Color3.fromRGB(18, 18, 18) }, 0.15)
		Tween(AaStroke, { Transparency = 0 }, 0.15)
	end)
	AaBtn.MouseLeave:Connect(function()
		Tween(AaFrame, { BackgroundColor3 = Color3.fromRGB(0, 0, 0) }, 0.15)
		Tween(AaStroke, { Transparency = 0.15 }, 0.15)
	end)

	AaBtn.Activated:Connect(function()
		if IsPosDropdownOpenFn and IsPosDropdownOpenFn() then
			if ClosePosDropdownFn then ClosePosDropdownFn() end
			task.delay(0.22, function()
				if not Data.dismissed then OpenDropdownAa() end
			end)
		else
			OpenDropdownAa()
		end
	end)

	DropdownAaClose.MouseEnter:Connect(function()
		Tween(DropdownAaClose, { TextColor3 = Color3.fromRGB(230, 230, 230) }, 0.15)
	end)
	DropdownAaClose.MouseLeave:Connect(function()
		Tween(DropdownAaClose, { TextColor3 = Color3.fromRGB(180, 180, 180) }, 0.15)
	end)
	DropdownAaClose.Activated:Connect(function()
		CloseDropdownAa()
	end)

	for I, Option in ipairs(FONT_OPTIONS) do
		local FontBtn = NewInstance("TextButton", {
			Parent = DropdownAa,
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 40 + ((I - 1) * 37)),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BackgroundTransparency = Option.Name == CurrentFontName and 0.1 or 0.45,
			BorderSizePixel = 0,
			Text = Option.Name,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 13,
			Font = CurrentFont,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 21,
		})
		NewInstance("UICorner", { Parent = FontBtn, CornerRadius = UDim.new(0, 8) })
		local FontBtnStroke = NewInstance("UIStroke", {
			Parent = FontBtn,
			Color = Color3.fromRGB(130, 130, 130),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		table.insert(TextTargets, FontBtn)
		table.insert(FontButtons, FontBtn)

		local FontBtnBgEntry = {instance = FontBtn, property = "BackgroundTransparency", visible = FontBtn.BackgroundTransparency}
		table.insert(FontDropdownFade, FontBtnBgEntry)
		table.insert(FontDropdownFade, {instance = FontBtn, property = "TextTransparency", visible = 0})
		FontBtnFadeEntries[FontBtn] = FontBtnBgEntry

		FontBtn.MouseEnter:Connect(function()
			Tween(FontBtn, { BackgroundTransparency = 0.08, Size = UDim2.new(0, 166.6, 0, 29.4) }, 0.15)
			Tween(FontBtnStroke, { Color = Color3.fromRGB(0, 153, 255) }, 0.15)
		end)
		FontBtn.MouseLeave:Connect(function()
			Tween(FontBtn, { BackgroundTransparency = Option.Name == CurrentFontName and 0.1 or 0.45, Size = UDim2.new(1, -20, 0, 30) }, 0.15)
			Tween(FontBtnStroke, { Color = Color3.fromRGB(130, 130, 130) }, 0.15)
		end)

		FontBtn.Activated:Connect(function()
			if Data.dismissed or DropdownAaClosing or not DropdownAaOpen then return end
			CurrentFont = Option.Font
			CurrentFontName = Option.Name
			SaveSettings()
			for _, Obj in ipairs(TextTargets) do
				if Obj and Obj.Parent then Obj.Font = Option.Font end
			end
			for _, Child in ipairs(DropdownAa:GetChildren()) do
				if Child:IsA("TextButton") and Child ~= DropdownAaClose then
					local IsSelected = Child == FontBtn
					Child.BackgroundTransparency = IsSelected and 0.1 or 0.45
					local Entry = FontBtnFadeEntries[Child]
					if Entry then Entry.visible = IsSelected and 0.1 or 0.45 end
				end
			end
			CloseDropdownAa()
		end)
	end

	local PosFrame = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -98, 0, 7),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 13,
	})
	NewInstance("UICorner", { Parent = PosFrame, CornerRadius = UDim.new(1, 0) })

	local PosStroke = NewInstance("UIStroke", {
		Parent = PosFrame,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1.25,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local PosBtn = NewInstance("TextButton", {
		Parent = PosFrame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "Pos",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 10,
		Font = CurrentFont,
		ZIndex = 14,
	})
	table.insert(TextTargets, PosBtn)

	local DropdownPosWidth = 230
	local DropdownPosHeight = 40 + (#POSITION_OPTIONS * 37) + 14
	local DropdownPos = NewInstance("Frame", {
		Parent = NotifyScreenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
	})
	Data.dropdownPos = DropdownPos
	NewInstance("UICorner", { Parent = DropdownPos, CornerRadius = UDim.new(0, 12) })

	local DropdownPosStroke = NewInstance("UIStroke", {
		Parent = DropdownPos,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local PosDropdownFade = {}

	local DropdownPosTitle = NewInstance("TextLabel", {
		Parent = DropdownPos,
		Size = UDim2.new(1, -46, 0, 28),
		Position = UDim2.new(0, 14, 0, 6),
		BackgroundTransparency = 1,
		Text = "Notif Position",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 17,
		Font = CurrentFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	table.insert(TextTargets, DropdownPosTitle)
	table.insert(PosDropdownFade, {instance = DropdownPosTitle, property = "TextTransparency", visible = 0})

	local DropdownPosClose = NewInstance("TextButton", {
		Parent = DropdownPos,
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "╳",
		TextColor3 = Color3.fromRGB(180, 180, 180),
		TextSize = 18,
		Font = CurrentFont,
		ZIndex = 22,
	})
	table.insert(TextTargets, DropdownPosClose)
	table.insert(PosDropdownFade, {instance = DropdownPosClose, property = "TextTransparency", visible = 0})

	local DropdownPosOpen = false
	local DropdownPosClosing = false
	local DropdownPosTween = nil
	local DropdownPosTweenToken = 0
	local PosButtons = {}
	local PosBtnFadeEntries = {}

	local function SetPosButtonsActive(Active)
		for _, PosButton in ipairs(PosButtons) do
			if PosButton and PosButton.Parent then
				PosButton.Active = Active
				PosButton.AutoButtonColor = false
			end
		end
	end

	local function CloseDropdownPos()
		if not DropdownPos.Visible or DropdownPosClosing then return end
		DropdownPosOpen = false
		DropdownPosClosing = true
		SetPosButtonsActive(false)
		DropdownPosTweenToken = DropdownPosTweenToken + 1
		local CloseToken = DropdownPosTweenToken
		if DropdownPosTween then pcall(function() DropdownPosTween:Cancel() end) end

		local FadeOutTween = FadeGroup(PosDropdownFade, false, 0.12)

		local function Collapse()
			if CloseToken ~= DropdownPosTweenToken then return end
			DropdownPosTween = Tween(DropdownPos, { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			Tween(DropdownPosStroke, { Transparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local CompletedConnection = nil
			CompletedConnection = DropdownPosTween.Completed:Connect(function()
				if CompletedConnection then CompletedConnection:Disconnect() CompletedConnection = nil end
				if CloseToken ~= DropdownPosTweenToken or DropdownPosOpen or Data.dismissed or not DropdownPos.Parent then return end
				DropdownPosClosing = false
				DropdownPos.Visible = false
				if not (IsAaDropdownOpenFn and IsAaDropdownOpenFn()) then
					ResumeTimer()
				end
			end)
		end

		if FadeOutTween then
			FadeOutTween.Completed:Once(Collapse)
		else
			Collapse()
		end
	end

	local function OpenDropdownPos()
		if DropdownPosOpen or Data.dismissed then return end
		DropdownPosOpen = true
		DropdownPosClosing = false
		SetPosButtonsActive(true)
		DropdownPosTweenToken = DropdownPosTweenToken + 1
		local OpenToken = DropdownPosTweenToken
		PauseTimer()
		DropdownPos.Visible = true
		DropdownPos.Size = UDim2.new(0, 0, 0, 0)
		DropdownPos.BackgroundTransparency = 1
		DropdownPosStroke.Transparency = 1
		FadeGroupSnap(PosDropdownFade, false)
		if DropdownPosTween then pcall(function() DropdownPosTween:Cancel() end) end
		DropdownPosTween = Tween(DropdownPos, { Size = UDim2.new(0, DropdownPosWidth, 0, DropdownPosHeight), BackgroundTransparency = 0 }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tween(DropdownPosStroke, { Transparency = 0.25 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		DropdownPosTween.Completed:Once(function()
			if OpenToken == DropdownPosTweenToken and DropdownPos.Visible then
				FadeGroup(PosDropdownFade, true, 0.15)
			end
		end)
	end

	ClosePosDropdownFn = CloseDropdownPos
	IsPosDropdownOpenFn = function() return DropdownPosOpen end

	PosBtn.MouseEnter:Connect(function()
		Tween(PosFrame, { BackgroundColor3 = Color3.fromRGB(18, 18, 18) }, 0.15)
		Tween(PosStroke, { Transparency = 0 }, 0.15)
	end)
	PosBtn.MouseLeave:Connect(function()
		Tween(PosFrame, { BackgroundColor3 = Color3.fromRGB(0, 0, 0) }, 0.15)
		Tween(PosStroke, { Transparency = 0.15 }, 0.15)
	end)

	PosBtn.Activated:Connect(function()
		if IsAaDropdownOpenFn and IsAaDropdownOpenFn() then
			if CloseAaDropdownFn then CloseAaDropdownFn() end
			task.delay(0.22, function()
				if not Data.dismissed then OpenDropdownPos() end
			end)
		else
			OpenDropdownPos()
		end
	end)

	DropdownPosClose.MouseEnter:Connect(function()
		Tween(DropdownPosClose, { TextColor3 = Color3.fromRGB(230, 230, 230) }, 0.15)
	end)
	DropdownPosClose.MouseLeave:Connect(function()
		Tween(DropdownPosClose, { TextColor3 = Color3.fromRGB(180, 180, 180) }, 0.15)
	end)
	DropdownPosClose.Activated:Connect(function()
		CloseDropdownPos()
	end)

	for I, Option in ipairs(POSITION_OPTIONS) do
		local PosOptBtn = NewInstance("TextButton", {
			Parent = DropdownPos,
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 40 + ((I - 1) * 37)),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BackgroundTransparency = Option.Name == CurrentPositionOption.Name and 0.1 or 0.45,
			BorderSizePixel = 0,
			Text = Option.Label,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 13,
			Font = CurrentFont,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 21,
		})
		NewInstance("UICorner", { Parent = PosOptBtn, CornerRadius = UDim.new(0, 8) })
		local PosOptBtnStroke = NewInstance("UIStroke", {
			Parent = PosOptBtn,
			Color = Color3.fromRGB(130, 130, 130),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		table.insert(TextTargets, PosOptBtn)
		table.insert(PosButtons, PosOptBtn)

		local PosBtnBgEntry = {instance = PosOptBtn, property = "BackgroundTransparency", visible = PosOptBtn.BackgroundTransparency}
		table.insert(PosDropdownFade, PosBtnBgEntry)
		table.insert(PosDropdownFade, {instance = PosOptBtn, property = "TextTransparency", visible = 0})
		PosBtnFadeEntries[PosOptBtn] = PosBtnBgEntry

		PosOptBtn.MouseEnter:Connect(function()
			Tween(PosOptBtn, { BackgroundTransparency = 0.08, Size = UDim2.new(0, 205.8, 0, 29.4) }, 0.15)
			Tween(PosOptBtnStroke, { Color = Color3.fromRGB(0, 153, 255) }, 0.15)
		end)
		PosOptBtn.MouseLeave:Connect(function()
			Tween(PosOptBtn, { BackgroundTransparency = CurrentPositionOption.Name == Option.Name and 0.1 or 0.45, Size = UDim2.new(1, -20, 0, 30) }, 0.15)
			Tween(PosOptBtnStroke, { Color = Color3.fromRGB(130, 130, 130) }, 0.15)
		end)

		PosOptBtn.Activated:Connect(function()
			if Data.dismissed or DropdownPosClosing or not DropdownPosOpen then return end
			CurrentPositionOption = Option
			SaveSettings()
			for _, Child in ipairs(DropdownPos:GetChildren()) do
				if Child:IsA("TextButton") and Child ~= DropdownPosClose then
					local IsSelected = Child == PosOptBtn
					Child.BackgroundTransparency = IsSelected and 0.1 or 0.45
					local Entry = PosBtnFadeEntries[Child]
					if Entry then Entry.visible = IsSelected and 0.1 or 0.45 end
				end
			end
			RepositionAll()
			CloseDropdownPos()
		end)
	end

	local ProgressBg = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(1, -20, 0, 3),
		Position = UDim2.new(0, 10, 0, FrameHeight - 10),
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		BorderSizePixel = 0,
		ZIndex = 11,
	})
	NewInstance("UICorner", { Parent = ProgressBg, CornerRadius = UDim.new(1, 0) })

	local ProgressBar = NewInstance("Frame", {
		Parent = ProgressBg,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 12,
	})
	NewInstance("UICorner", { Parent = ProgressBar, CornerRadius = UDim.new(1, 0) })

	local TargetPos = GetSlotPos(#ActiveNotifs)
	local OvershootSign = (CurrentPositionOption.XSide == "left") and 1 or -1
	local BounceOver = UDim2.new(TargetPos.X.Scale, TargetPos.X.Offset + OvershootSign * 12, TargetPos.Y.Scale, TargetPos.Y.Offset)

	local _, EntranceToken = PlayFrameTween(Data, { Position = BounceOver }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	task.delay(0.4, function()
		if Data.dismissed or not Frame.Parent or Data.positionToken ~= EntranceToken then return end
		local Idx = (function()
			for I, D in ipairs(ActiveNotifs) do
				if D == Data then return I end
			end
			return nil
		end)()
		if not Idx then return end
		local CurrentTargetPos = GetSlotPos(Idx)
		local BackSign = (CurrentPositionOption.XSide == "left") and 1 or -1
		local CurrentBounceBack = UDim2.new(CurrentTargetPos.X.Scale, CurrentTargetPos.X.Offset - BackSign * 4, CurrentTargetPos.Y.Scale, CurrentTargetPos.Y.Offset)
		local _, BounceToken = PlayFrameTween(Data, { Position = CurrentBounceBack }, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.13, function()
			if Data.dismissed or not Frame.Parent or Data.positionToken ~= BounceToken then return end
			local FinalIdx = (function()
				for I, D in ipairs(ActiveNotifs) do
					if D == Data then return I end
				end
				return nil
			end)()
			if not FinalIdx then return end
			PlayFrameTween(Data, { Position = GetSlotPos(FinalIdx) }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)
	end)

	if Duration <= 0 then
		ProgressBar.Size = UDim2.new(0, 0, 1, 0)
		DismissNotif(Frame, Data)
	else
		task.spawn(function()
			local FixedStep = 1 / 60
			local MaxFrameDt = 0.25
			local Accumulator = 0
			local Last = os.clock()
			while not Data.dismissed and Data.remaining > 0 and Frame.Parent do
				local HeartbeatDt = RunService.Heartbeat:Wait()
				local Now = os.clock()
				local Dt = type(HeartbeatDt) == "number" and HeartbeatDt or Now - Last
				Last = Now
				if Dt < 0 then Dt = 0 end
				if Dt > MaxFrameDt then Dt = MaxFrameDt end
				if not Data.paused then
					Accumulator = Accumulator + Dt
					while Accumulator >= FixedStep and Data.remaining > 0 do
						Data.remaining = Data.remaining - FixedStep
						Accumulator = Accumulator - FixedStep
					end
					if Data.remaining < 0 then Data.remaining = 0 end
					local Ratio = Data.remaining / Data.duration
					if Ratio < 0 then Ratio = 0 end
					if Ratio > 1 then Ratio = 1 end
					if ProgressBar and ProgressBar.Parent then
						ProgressBar.Size = UDim2.new(Ratio, 0, 1, 0)
					end
				end
			end
			if not Data.dismissed then DismissNotif(Frame, Data) end
		end)
	end

end

if _G.Notify == nil then
	_G.Notify = Notify
end

if type(getgenv) == "function" then
	local Env = getgenv()
	if Env.Notify == nil then
		Env.Notify = Notify
	end
end

return Notify
