if not game:IsLoaded() then game.Loaded:Wait() end
local Cloneref = (cloneref or clonereference or function(Instance) return Instance end)

local function Load(Url, Name)
	local Loader = (type(loadstring) == "function" and loadstring) or (type(load) == "function" and load)

	if not Loader then
		error("load/loadstring not supported, get a better executor.")
	end

	local ReqFn = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn) == "table" and type(syn.request) == "function" and syn.request) or (type(http) == "table" and type(http.request) == "function" and http.request)

	local Body
	while not Body do
		Body = (function()
			if type(game.HttpGet) == "function" then
				return game:HttpGet(Url)
			end

			if type(HttpService.GetAsync) == "function" then
				return HttpService:GetAsync(Url)
			end

			if ReqFn then
				local Res = ReqFn({ Url = Url, Method = "GET" })
				if Res and Res.Body then return Res.Body end
			end

			return nil
		end)()

		if not Body then
			warn("[Noname] HTTP fetch failed for " .. Name .. ", retrying in 2s...")
			task.wait(2)
		end
	end

	local Chunk, CompileErr = Loader(Body)
	if not Chunk then
		return nil, "Failed to compile " .. Name .. ": " .. tostring(CompileErr)
	end

	return Chunk()
end

--[[ Services ]]--
local Players = Cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local TweenService = Cloneref(game:GetService("TweenService"))
local UserInputService = Cloneref(game:GetService("UserInputService"))
local ContentProvider = Cloneref(game:GetService("ContentProvider"))

--[[ Variables ]]--
local UIGesture = Load("https://raw.githubusercontent.com/isskkauww/Modules/refs/heads/main/UIGesture.luau", "UIGesture")
local ToggleBusy = false
local IsMobile = UserInputService:GetPlatform() == Enum.Platform.Android or UserInputService:GetPlatform() == Enum.Platform.IOS

local UI = {
	CommandBar = {},
	HUD = {},
	CommandList = {},
	Settings = {},
	ScaleSliderFn = function() end,
	ScaleSliderDragEndFn = function() end,
}
UI.CmdOpen = false
UI.CmdListOpen = false

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

local ScreenGui = NewInstance("ScreenGui", {
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483646,
})

local Scale = NewInstance("UIScale", { Parent = ScreenGui })

local ScreenGui2 = NewInstance("ScreenGui", {
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483647,
})

--[[ Toggle ]]--
do
	local ToggleButton = NewInstance("TextButton", {
		Parent = ScreenGui,
		BackgroundColor3 = Color3.fromRGB(46, 46, 47),
		BackgroundTransparency = 0.14,
		Position = UDim2.new(0.489, 0, 0.07, 0),
		Size = UDim2.new(0, 0, 0, 0),
		Font = Enum.Font.SourceSansBold,
		Text = "NN",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 20,
		TextTransparency = 1,
		Visible = false,
		ZIndex = 10,
		AnchorPoint = Vector2.new(0.5, 0.5),
	})

	UI.ToggleButton = ToggleButton

	NewInstance("UICorner", { Parent = ToggleButton, CornerRadius = UDim.new(0.5, 0) })

	local ToggleDrag = UIGesture:MakeDraggable(ToggleButton)

	function UI.SetToggleButtonLocked(Locked)
		ToggleDrag:SetLocked(Locked)
	end

	function UI.PlayToggleSpawn()
		ToggleButton.Visible = true
		TweenService:Create(ToggleButton, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = UDim2.new(0, 32, 0, 33), TextTransparency = 0 }):Play()
		TweenService:Create(ToggleButton, TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 720 }):Play()
	end

	ToggleButton.Activated:Connect(function()
		if ToggleBusy then return end
		ToggleBusy = true

		local TweenPress = TweenService:Create(ToggleButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 32 * 0.7, 0, 33 * 0.7) })
		local TweenRelease = TweenService:Create(ToggleButton, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 32, 0, 33) })

		TweenPress:Play()
		TweenPress.Completed:Wait()
		TweenRelease:Play()
		if not UI.CmdOpen then
			UI.CommandBar.Open()
		end
		TweenRelease.Completed:Wait()
		ToggleBusy = false
	end)
end

--[[ CommandBar ]]--
do
	local BarWidth = 520
	local RowHeight = 38
	UI.CommandBar.SuggLimit = 5

	UI.CommandBar.Frame = NewInstance("Frame", {
		Parent = ScreenGui,
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
	})

	local Shell = NewInstance("Frame", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(13, 13, 15),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 20,
	})

	NewInstance("UICorner", { Parent = Shell, CornerRadius = UDim.new(0, 12) })

	NewInstance("UIGradient", {
		Parent = Shell,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 23)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
		}),
	})

	local CmdOutline = NewInstance("UIStroke", {
		Parent = Shell,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(235, 235, 240),
		Thickness = 1.25,
		Transparency = 0.58,
	})

	NewInstance("TextLabel", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(0, 18, 0, 22),
		Position = UDim2.new(0, 15, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = ">",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 24,
	})

	UI.CommandBar.InputBox = NewInstance("TextBox", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(1, -207, 1, 0),
		Position = UDim2.new(0, 43, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(246, 246, 248),
		PlaceholderText = "Type a command...",
		PlaceholderColor3 = Color3.fromRGB(130, 130, 138),
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		ZIndex = 23,
	})

	UI.CommandBar.Enter = NewInstance("TextButton", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(0, 52, 0, 22),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(31, 31, 35),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "ENTER",
		TextColor3 = Color3.fromRGB(196, 196, 204),
		TextSize = 9,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 24,
	})

	NewInstance("UICorner", { Parent = UI.CommandBar.Enter, CornerRadius = UDim.new(0, 5) })

	NewInstance("UIStroke", {
		Parent = UI.CommandBar.Enter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.78,
	})

	UI.CommandBar.Prediction = NewInstance("TextBox", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(1, -207, 1, 0),
		Position = UDim2.new(0, 43, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(155, 155, 164),
		TextTransparency = 0.55,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextEditable = false,
		Active = false,
		Selectable = false,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 22,
	})

	UI.CommandBar.Tab = NewInstance("TextLabel", {
		Parent = UI.CommandBar.Frame,
		Size = UDim2.new(0, 82, 0, 22),
		Position = UDim2.new(1, -70, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(27, 27, 31),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Text = "TAB  AUTOFILL",
		TextColor3 = Color3.fromRGB(150, 150, 158),
		TextSize = 9,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 24,
	})

	NewInstance("UICorner", { Parent = UI.CommandBar.Tab, CornerRadius = UDim.new(0, 5) })

	local TabOutline = NewInstance("UIStroke", {
		Parent = UI.CommandBar.Tab,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.86,
	})

	local function SyncPrediction()
		local Has = UI.CommandBar.Prediction.Text ~= "" and UI.CommandBar.Prediction.Text ~= UI.CommandBar.InputBox.Text
		UI.CommandBar.Prediction.Visible = Has
		UI.CommandBar.Tab.TextColor3 = Has and Color3.fromRGB(245, 245, 248) or Color3.fromRGB(150, 150, 158)
		UI.CommandBar.Tab.BackgroundColor3 = Has and Color3.fromRGB(42, 42, 47) or Color3.fromRGB(27, 27, 31)
		UI.CommandBar.Tab.BackgroundTransparency = Has and 0.04 or 0.18
		TabOutline.Transparency = Has and 0.52 or 0.86
	end

	UI.CommandBar.Prediction:GetPropertyChangedSignal("Text"):Connect(SyncPrediction)
	UI.CommandBar.InputBox:GetPropertyChangedSignal("Text"):Connect(SyncPrediction)

	UI.CommandBar.SuggFrame = NewInstance("Frame", {
		Parent = ScreenGui,
		Size = UDim2.new(0, 520, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, -33),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 18,
	})

	NewInstance("UIPadding", {
		Parent = UI.CommandBar.SuggFrame,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})

	NewInstance("UIListLayout", {
		Parent = UI.CommandBar.SuggFrame,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	UI.CommandBar.SuggItems = {}

	local function RefreshSugg()
		local Count = 0
		for _, Item in ipairs(UI.CommandBar.SuggItems) do
			if Item.Visible then
				Count += 1
			end
		end

		local Target = UDim2.new(0, BarWidth, 0, 16 + Count * RowHeight + (Count - 1) * 6)
		if UI.CommandBar.SuggFrame.Visible then
			TweenService:Create(UI.CommandBar.SuggFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Target }):Play()
		else
			UI.CommandBar.SuggFrame.Size = Target
		end
	end

	UI.CommandBar.SuggFrame:GetPropertyChangedSignal("Visible"):Connect(RefreshSugg)

	for I = 1, 5 do
		local Row = NewInstance("Frame", {
			Parent = UI.CommandBar.SuggFrame,
			Size = UDim2.new(1, -16, 0, 38),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = I,
			Visible = false,
			ZIndex = 19,
		})

		local RowShell = NewInstance("Frame", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(24, 24, 27),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 20,
		})

		NewInstance("UICorner", { Parent = RowShell, CornerRadius = UDim.new(0, 8) })

		NewInstance("UIGradient", {
			Parent = RowShell,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 34)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 19, 22)),
			}),
		})

		local RowStroke = NewInstance("UIStroke", {
			Parent = RowShell,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(225, 225, 232),
			Thickness = 1,
			Transparency = 0.76,
		})

		local RowLine = NewInstance("Frame", {
			Parent = RowShell,
			Size = UDim2.new(0, 2, 1, -16),
			Position = UDim2.new(0, 7, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(245, 245, 248),
			BackgroundTransparency = 0.42,
			BorderSizePixel = 0,
			ZIndex = 21,
		})

		NewInstance("UICorner", { Parent = RowLine, CornerRadius = UDim.new(0, 3) })

		local Item = NewInstance("TextButton", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			TextColor3 = Color3.fromRGB(232, 232, 236),
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 22,
		})

		NewInstance("UIPadding", {
			Parent = Item,
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 14),
		})

		local function Reveal()
			RowShell.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
			RowShell.BackgroundTransparency = 0.2
			RowStroke.Transparency = 0.76
			RowLine.BackgroundTransparency = 0.42
			Row.Size = UDim2.new(0.96, -16, 0, RowHeight - 2)
			TweenService:Create(Row, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(1, -16, 0, RowHeight) }):Play()
		end

		local function Hover(Active)
			local Info = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			TweenService:Create(RowShell, Info, {
				BackgroundColor3 = Active and Color3.fromRGB(38, 38, 43) or Color3.fromRGB(24, 24, 27),
				BackgroundTransparency = Active and 0.08 or 0.2,
			}):Play()
			TweenService:Create(RowStroke, Info, { Transparency = Active and 0.28 or 0.76 }):Play()
			TweenService:Create(RowLine, Info, { BackgroundTransparency = Active and 0.05 or 0.42 }):Play()
			if Active then
				UI.CommandBar.InputBox:CaptureFocus()
			end
		end

		UIGesture:MakeHoverable(Item, nil, Hover)

		Item:GetPropertyChangedSignal("Visible"):Connect(function()
			Row.Visible = Item.Visible
			if Item.Visible then
				Reveal()
			end
			RefreshSugg()
		end)

		Item:GetPropertyChangedSignal("Text"):Connect(function()
			if Item.Visible and Item.Text ~= "" then
				Reveal()
			end
		end)

		UI.CommandBar.SuggItems[I] = Item
	end

	local function ResetRows()
		for _, Item in ipairs(UI.CommandBar.SuggItems) do
			Item.Parent.Size = UDim2.new(1, -16, 0, RowHeight)
		end
	end

	local function Relayout()
		local ScreenSize = ScreenGui.AbsoluteSize
		local Scale = math.max(Scale.Scale, 0.01)
		BarWidth = math.min(520, math.max(280, math.floor((ScreenSize.X - 24) / Scale + 0.5)))

		local Compact = IsMobile and ScreenSize.Y < 620
		UI.CommandBar.SuggLimit = Compact and 3 or 5
		RowHeight = Compact and 40 or 38

		local Clearance = IsMobile and 76 or 164
		UI.CommandBar.InputBox.Size = UDim2.new(1, -(43 + Clearance), 1, 0)
		UI.CommandBar.Prediction.Size = UI.CommandBar.InputBox.Size
		UI.CommandBar.Tab.Visible = not IsMobile

		if UI.CmdOpen then
			UI.CommandBar.Frame.Size = UDim2.new(0, BarWidth, 0, 46)
		end

		ResetRows()
		RefreshSugg()
	end

	ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Relayout)
	Scale:GetPropertyChangedSignal("Scale"):Connect(Relayout)
	Relayout()

	function UI.CommandBar.Open()
		UI.CmdOpen = true
		ResetRows()
		UI.CommandBar.InputBox.Text = ""
		UI.CommandBar.Frame.Visible = true
		UI.CommandBar.Frame.Size = UDim2.new(0, BarWidth - 36, 0, 44)
		TweenService:Create(CmdOutline, TweenInfo.new(0.108, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.18 }):Play()
		TweenService:Create(UI.CommandBar.Enter, TweenInfo.new(0.108, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			TextColor3 = Color3.fromRGB(245, 245, 248),
			BackgroundColor3 = Color3.fromRGB(40, 40, 45),
		}):Play()
		TweenService:Create(UI.CommandBar.Frame, TweenInfo.new(0.108, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, BarWidth, 0, 46) }):Play()
		task.delay(0.1, function()
			UI.CommandBar.InputBox:CaptureFocus()
		end)
	end

	function UI.CommandBar.Close()
		UI.CmdOpen = false
		TweenService:Create(CmdOutline, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.58 }):Play()
		TweenService:Create(UI.CommandBar.Enter, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			TextColor3 = Color3.fromRGB(196, 196, 204),
			BackgroundColor3 = Color3.fromRGB(31, 31, 35),
		}):Play()

		for _, Item in ipairs(UI.CommandBar.SuggItems) do
			if Item.Visible then
				TweenService:Create(Item.Parent, TweenInfo.new(0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), { Size = UDim2.new(0.96, -16, 0, 34) }):Play()
			end
		end

		task.delay(0.14, function()
			if UI.CmdOpen then return end
			UI.CommandBar.SuggFrame.Visible = false
			ResetRows()
		end)

		local CloseTween = TweenService:Create(UI.CommandBar.Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), { Size = UDim2.new(0, 0, 0, 0) })
		CloseTween.Completed:Connect(function()
			if not UI.CmdOpen then
				UI.CommandBar.Frame.Visible = false
			end
		end)
		CloseTween:Play()
	end
end

--[[ CommandList ]]--
do
	local Frame = NewInstance("Frame", {
		Parent = ScreenGui,
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 30,
	})

	local Shell = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(13, 13, 15),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 30,
	})

	NewInstance("UICorner", { Parent = Shell, CornerRadius = UDim.new(0, 14) })

	NewInstance("UIGradient", {
		Parent = Shell,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 23)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
		}),
	})

	local ListOutline = NewInstance("UIStroke", {
		Parent = Shell,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(235, 235, 240),
		Thickness = 1.25,
		Transparency = 0.58,
	})

	local Title = NewInstance("TextLabel", {
		Parent = Frame,
		Size = UDim2.new(1, -70, 0, 40),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
		Text = "COMMAND LIST",
		TextColor3 = Color3.fromRGB(246, 246, 248),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 32,
	})

	UIGesture:MakeDraggable(Frame, Title)

	local CloseButton = NewInstance("TextButton", {
		Parent = Frame,
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -14, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(31, 31, 35),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = Color3.fromRGB(196, 196, 204),
		TextSize = 14,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 32,
	})

	NewInstance("UICorner", { Parent = CloseButton, CornerRadius = UDim.new(0, 7) })

	CloseButton.Activated:Connect(function()
		UI.CommandList.Close()
	end)

	local SearchBox = NewInstance("TextBox", {
		Parent = Frame,
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.new(0, 20, 0, 44),
		BackgroundColor3 = Color3.fromRGB(24, 24, 27),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(246, 246, 248),
		PlaceholderText = "Search commands...",
		PlaceholderColor3 = Color3.fromRGB(130, 130, 138),
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		ZIndex = 32,
	})

	NewInstance("UICorner", { Parent = SearchBox, CornerRadius = UDim.new(0, 8) })

	NewInstance("UIPadding", {
		Parent = SearchBox,
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})

	local SearchStroke = NewInstance("UIStroke", {
		Parent = SearchBox,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.78,
	})

	SearchBox.Focused:Connect(function()
		TweenService:Create(SearchStroke, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.3 }):Play()
	end)

	SearchBox.FocusLost:Connect(function()
		TweenService:Create(SearchStroke, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.78 }):Play()
	end)

	local ListFrame = NewInstance("ScrollingFrame", {
		Parent = Frame,
		Size = UDim2.new(1, -40, 1, -122),
		Position = UDim2.new(0, 20, 0, 88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(235, 235, 240),
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 31,
	})

	NewInstance("UIListLayout", {
		Parent = ListFrame,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	NewInstance("UIPadding", {
		Parent = ListFrame,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
	})

	local EmptyLabel = NewInstance("TextLabel", {
		Parent = Frame,
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.new(0, 20, 0, 96),
		BackgroundTransparency = 1,
		Text = "No commands found",
		TextColor3 = Color3.fromRGB(130, 130, 138),
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 13,
		Visible = false,
		ZIndex = 31,
	})

	local Entries = {}

	local function RefreshEmptyState()
		local AnyVisible = false
		for _, Entry in ipairs(Entries) do
			if Entry.Row.Visible then
				AnyVisible = true
				break
			end
		end
		EmptyLabel.Visible = not AnyVisible
	end

	local function FilterEntries()
		local Query = string.lower(SearchBox.Text)
		for _, Entry in ipairs(Entries) do
			Entry.Row.Visible = Query == "" or string.find(Entry.SearchKey, Query, 1, true) ~= nil
		end
		RefreshEmptyState()
	end

	SearchBox:GetPropertyChangedSignal("Text"):Connect(FilterEntries)

	function UI.CommandList.Add(Names, Description, Callback)
		local Aliases = type(Names) == "table" and Names or { Names }

		local Row = NewInstance("Frame", {
			Parent = ListFrame,
			Size = UDim2.new(0.95, 0, 0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = #Entries + 1,
			ZIndex = 31,
		})

		local RowShell = NewInstance("Frame", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(24, 24, 27),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 31,
		})

		NewInstance("UICorner", { Parent = RowShell, CornerRadius = UDim.new(0, 8) })

		local RowStroke = NewInstance("UIStroke", {
			Parent = RowShell,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(225, 225, 232),
			Thickness = 1,
			Transparency = 0.76,
		})

		local RowLine = NewInstance("Frame", {
			Parent = RowShell,
			Size = UDim2.new(0, 2, 1, -16),
			Position = UDim2.new(0, 7, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(245, 245, 248),
			BackgroundTransparency = 0.42,
			BorderSizePixel = 0,
			ZIndex = 32,
		})

		NewInstance("UICorner", { Parent = RowLine, CornerRadius = UDim.new(0, 3) })

		NewInstance("TextLabel", {
			Parent = RowShell,
			Size = UDim2.new(1, -30, 0, 20),
			Position = UDim2.new(0, 18, 0, 5),
			BackgroundTransparency = 1,
			Text = table.concat(Aliases, ", "),
			TextColor3 = Color3.fromRGB(232, 232, 236),
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ClipsDescendants = true,
			ZIndex = 33,
		})

		NewInstance("TextLabel", {
			Parent = RowShell,
			Size = UDim2.new(1, -30, 0, 16),
			Position = UDim2.new(0, 18, 0, 23),
			BackgroundTransparency = 1,
			Text = Description or "",
			TextColor3 = Color3.fromRGB(150, 150, 158),
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ClipsDescendants = true,
			ZIndex = 33,
		})

		local Button = NewInstance("TextButton", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 34,
		})

		local function Hover(Active)
			local Info = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			TweenService:Create(RowShell, Info, {
				BackgroundColor3 = Active and Color3.fromRGB(38, 38, 43) or Color3.fromRGB(24, 24, 27),
				BackgroundTransparency = Active and 0.08 or 0.2,
			}):Play()
			TweenService:Create(RowStroke, Info, { Transparency = Active and 0.28 or 0.76 }):Play()
			TweenService:Create(RowLine, Info, { BackgroundTransparency = Active and 0.05 or 0.42 }):Play()
		end

		UIGesture:MakeHoverable(Button, nil, Hover)

		Button.Activated:Connect(function()
			if Callback then
				Callback()
			end
		end)

		local Entry = {
			Aliases = Aliases,
			Description = Description,
			Callback = Callback,
			Row = Row,
			SearchKey = string.lower(table.concat(Aliases, " ") .. " " .. (Description or "")),
		}

		Entries[#Entries + 1] = Entry
		FilterEntries()

		return Entry
	end

	local Width = 460
	local Height = 420

	local function Relayout()
		local ScreenSize = ScreenGui.AbsoluteSize
		local Scale = math.max(Scale.Scale, 0.01)
		Width = math.min(460, math.max(280, math.floor((ScreenSize.X - 40) / Scale + 0.5)))
		Height = math.min(520, math.max(260, math.floor((ScreenSize.Y - 120) / Scale + 0.5)))

		if UI.CmdListOpen then
			Frame.Size = UDim2.new(0, Width, 0, Height)
		end
	end

	ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Relayout)
	Scale:GetPropertyChangedSignal("Scale"):Connect(Relayout)
	Relayout()

	local function Open()
		UI.CmdListOpen = true
		SearchBox.Text = ""
		Frame.Visible = true
		Frame.Size = UDim2.new(0, Width - 60, 0, Height - 60)
		TweenService:Create(ListOutline, TweenInfo.new(0.108, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.18 }):Play()
		TweenService:Create(Frame, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, Width, 0, Height) }):Play()
	end

	function UI.CommandList.Close()
		UI.CmdListOpen = false
		TweenService:Create(ListOutline, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.58 }):Play()

		local CloseTween = TweenService:Create(Frame, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), { Size = UDim2.new(0, 0, 0, 0) })
		CloseTween.Completed:Connect(function()
			if not UI.CmdListOpen then
				Frame.Visible = false
			end
		end)
		CloseTween:Play()
	end

	function UI.CommandList.Toggle()
		if UI.CmdListOpen then
			UI.CommandList.Close()
		else
			Open()
		end
	end
end

--[[ Picker ]]--
do
	local Count = 0
	local Rows = {}
	local PickerOpen = false

	local Frame = NewInstance("Frame", {
		Parent = ScreenGui,
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 40,
	})

	local Shell = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(13, 13, 15),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 40,
	})

	NewInstance("UICorner", { Parent = Shell, CornerRadius = UDim.new(0, 14) })

	NewInstance("UIGradient", {
		Parent = Shell,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 23)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
		}),
	})

	local PickerOutline = NewInstance("UIStroke", {
		Parent = Shell,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(235, 235, 240),
		Thickness = 1.25,
		Transparency = 0.58,
	})

	local function Close()
		PickerOpen = false
		TweenService:Create(PickerOutline, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.58 }):Play()

		local CloseTween = TweenService:Create(Frame, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), { Size = UDim2.new(0, 0, 0, 0) })
		CloseTween.Completed:Connect(function()
			if not PickerOpen then
				Frame.Visible = false
			end
		end)
		CloseTween:Play()
	end

	NewInstance("TextLabel", {
		Parent = Frame,
		Size = UDim2.new(1, -70, 0, 26),
		Position = UDim2.new(0, 20, 0, 14),
		BackgroundTransparency = 1,
		Text = "Select One",
		TextColor3 = Color3.fromRGB(246, 246, 248),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 42,
	})

	local Content = NewInstance("Frame", {
		Parent = Frame,
		Size = UDim2.new(1, -32, 1, -62),
		Position = UDim2.new(0, 16, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 41,
	})

	NewInstance("UIListLayout", {
		Parent = Content,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for Index = 1, 4 do
		local Row = NewInstance("Frame", {
			Parent = Content,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = Index,
			Visible = false,
			ZIndex = 41,
		})

		local RowShell = NewInstance("Frame", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(24, 24, 27),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 41,
		})

		NewInstance("UICorner", { Parent = RowShell, CornerRadius = UDim.new(0, 8) })

		local RowStroke = NewInstance("UIStroke", {
			Parent = RowShell,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(225, 225, 232),
			Thickness = 1,
			Transparency = 0.76,
		})

		local RowLine = NewInstance("Frame", {
			Parent = RowShell,
			Size = UDim2.new(0, 2, 1, -16),
			Position = UDim2.new(0, 7, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(245, 245, 248),
			BackgroundTransparency = 0.42,
			BorderSizePixel = 0,
			ZIndex = 42,
		})

		NewInstance("UICorner", { Parent = RowLine, CornerRadius = UDim.new(0, 3) })

		local TitleLabel = NewInstance("TextLabel", {
			Parent = RowShell,
			Size = UDim2.new(1, -30, 0, 20),
			Position = UDim2.new(0, 18, 0, 5),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.fromRGB(232, 232, 236),
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ClipsDescendants = true,
			ZIndex = 43,
		})

		local DescLabel = NewInstance("TextLabel", {
			Parent = RowShell,
			Size = UDim2.new(1, -30, 0, 16),
			Position = UDim2.new(0, 18, 0, 23),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.fromRGB(150, 150, 158),
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ClipsDescendants = true,
			ZIndex = 43,
		})

		local Button = NewInstance("TextButton", {
			Parent = Row,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 44,
		})

		UIGesture:MakeHoverable(Button, nil, function(Active)
			TweenService:Create(RowShell, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				BackgroundColor3 = Active and Color3.fromRGB(38, 38, 43) or Color3.fromRGB(24, 24, 27),
				BackgroundTransparency = Active and 0.08 or 0.2,
			}):Play()
			TweenService:Create(RowStroke, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = Active and 0.28 or 0.76 }):Play()
			TweenService:Create(RowLine, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = Active and 0.05 or 0.42 }):Play()
		end)

		Button.Activated:Connect(function()
			if not PickerOpen then return end
			Close()
			if Rows[Index].Fn then
				Rows[Index].Fn()
			end
		end)

		Rows[Index] = {
			Row = Row,
			Shell = RowShell,
			Stroke = RowStroke,
			Line = RowLine,
			Title = TitleLabel,
			Desc = DescLabel,
		}
	end

	local CloseButton = NewInstance("TextButton", {
		Parent = Frame,
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -14, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(31, 31, 35),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = Color3.fromRGB(196, 196, 204),
		TextSize = 14,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		ZIndex = 42,
	})

	NewInstance("UICorner", { Parent = CloseButton, CornerRadius = UDim.new(0, 7) })

	UIGesture:MakeHoverable(CloseButton, nil, function(Active)
		TweenService:Create(CloseButton, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundColor3 = Active and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(31, 31, 35),
			TextColor3 = Active and Color3.fromRGB(245, 245, 248) or Color3.fromRGB(196, 196, 204),
		}):Play()
	end)

	CloseButton.Activated:Connect(Close)

	local function GetSize()
		local Scale = math.max(Scale.Scale, 0.01)
		return UDim2.new(0, math.min(360, math.max(240, math.floor((ScreenGui.AbsoluteSize.X - 40) / Scale + 0.5))), 0, 56 + 50 * Count)
	end

	local function Relayout()
		if PickerOpen then
			Frame.Size = GetSize()
		end
	end

	ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Relayout)
	Scale:GetPropertyChangedSignal("Scale"):Connect(Relayout)

	function UI.CreatePicker(Config)
		Count = math.min(#Config, 4)

		for Index = 1, 4 do
			Rows[Index].Row.Visible = Index <= Count

			if Index <= Count then
				local HasDesc = Config[Index].Desc ~= nil and Config[Index].Desc ~= ""

				Rows[Index].Fn = Config[Index].Fn
				Rows[Index].Title.Text = Config[Index].Title
				Rows[Index].Title.Size = HasDesc and UDim2.new(1, -30, 0, 20) or UDim2.new(1, -30, 0, 24)
				Rows[Index].Title.Position = HasDesc and UDim2.new(0, 18, 0, 5) or UDim2.new(0, 18, 0.5, 0)
				Rows[Index].Title.AnchorPoint = HasDesc and Vector2.new(0, 0) or Vector2.new(0, 0.5)
				Rows[Index].Title.TextSize = HasDesc and 14 or 15
				Rows[Index].Desc.Text = Config[Index].Desc or ""
				Rows[Index].Desc.Visible = HasDesc
				Rows[Index].Line.BackgroundColor3 = Config[Index].Accent or Color3.fromRGB(245, 245, 248)
				Rows[Index].Line.BackgroundTransparency = 0.42
				Rows[Index].Shell.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
				Rows[Index].Shell.BackgroundTransparency = 0.2
				Rows[Index].Stroke.Transparency = 0.76
			end
		end

		local Size = GetSize()
		PickerOpen = true
		Frame.Visible = true
		Frame.Size = UDim2.new(0, Size.X.Offset - 40, 0, Size.Y.Offset - 40)
		TweenService:Create(PickerOutline, TweenInfo.new(0.108, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.18 }):Play()
		TweenService:Create(Frame, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Size }):Play()
	end
end

--[[ HUD ]]--
do
	local function BuildValueRow(Frame, Value, Placeholder, Tw, OnValueChanged, Numeric)
		local ValueLabel = NewInstance("TextLabel", {
			Parent = Frame,
			Size = UDim2.new(0, 36, 0, 44),
			Position = UDim2.new(1, -60, 0, 0),
			BackgroundTransparency = 1,
			Text = tostring(Value),
			TextColor3 = Color3.fromRGB(140, 140, 140),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local ToggleBtn = NewInstance("TextButton", {
			Parent = Frame,
			Size = UDim2.new(0, 22, 0, 22),
			Position = UDim2.new(1, -26, 0, 11),
			BackgroundColor3 = Color3.fromRGB(45, 45, 45),
			BorderSizePixel = 0,
			Text = "+",
			TextColor3 = Color3.fromRGB(200, 200, 200),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			ZIndex = 5,
		})

		NewInstance("UICorner", { Parent = ToggleBtn, CornerRadius = UDim.new(0, 6) })

		local InputRow = NewInstance("Frame", {
			Parent = Frame,
			Size = UDim2.new(1, -16, 0, 38),
			Position = UDim2.new(0, 8, 0, 50),
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BorderSizePixel = 0,
			Visible = false,
		})

		NewInstance("UICorner", { Parent = InputRow, CornerRadius = UDim.new(0, 8) })

		local InputStroke = NewInstance("UIStroke", {
			Parent = InputRow,
			Color = Color3.fromRGB(60, 60, 80),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})

		local InputBox = NewInstance("TextBox", {
			Parent = InputRow,
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.new(0, 8, 0, 4),
			BackgroundTransparency = 1,
			Text = tostring(Value),
			TextColor3 = Color3.fromRGB(230, 230, 230),
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			PlaceholderText = Placeholder,
		})

		local Expanded = false

		local function SetExpanded(State)
			Expanded = State
			ToggleBtn.Text = State and "-" or "+"
			if State then
				TweenService:Create(Frame, Tw, { Size = UDim2.new(0, 130, 0, 98) }):Play()
				task.delay(0.15, function() InputRow.Visible = true end)
			else
				InputRow.Visible = false
				TweenService:Create(Frame, Tw, { Size = UDim2.new(0, 130, 0, 44) }):Play()
			end
		end

		if Numeric then
			local LastText = InputBox.Text
			InputBox:GetPropertyChangedSignal("Text"):Connect(function()
				if InputBox.Text ~= "" and not tonumber(InputBox.Text) then
					InputBox.Text = LastText
				else
					LastText = InputBox.Text
				end
			end)
		end

		InputBox.Focused:Connect(function()
			TweenService:Create(InputStroke, TweenInfo.new(1.2), { Color = Color3.fromRGB(0, 191, 255) }):Play()
		end)

		InputBox.FocusLost:Connect(function()
			TweenService:Create(InputStroke, TweenInfo.new(1.2), { Color = Color3.fromRGB(60, 60, 80) }):Play()

			local N = tonumber(InputBox.Text)
			local V = N or InputBox.Text
			ValueLabel.Text = tostring(V)
			InputBox.Text = tostring(V)
			OnValueChanged(V)
		end)

		return ToggleBtn, ValueLabel, InputBox, SetExpanded, function() return Expanded end
	end

	function UI.HUD.MakeButton(Label, StartFn, Placeholder, DefaultValue, Numeric)
		Numeric = Numeric ~= false
		local HasValue = Placeholder ~= nil and DefaultValue ~= nil
		local Value = DefaultValue
		local Tw = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		local Frame, Hud
		local Built = false
		local SetExpanded, GetExpanded

		local function Build()
			if Built then return end
			Built = true

			Frame = NewInstance("Frame", {
				Parent = ScreenGui,
				BackgroundColor3 = Color3.fromRGB(22, 22, 22),
				BorderSizePixel = 0,
				Active = true,
				Visible = false,
				ClipsDescendants = HasValue,
				Size = HasValue and UDim2.new(0, 130, 0, 44) or UDim2.new(0, 100, 0, 40),
				Position = UDim2.new(0.84, 0, 0.17, 0),
			})
			Hud.Frame = Frame

			NewInstance("UICorner", { Parent = Frame, CornerRadius = UDim.new(0, 12) })

			NewInstance("UIStroke", {
				Parent = Frame,
				Color = Color3.fromRGB(100, 100, 100),
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})

			NewInstance("TextLabel", {
				Parent = Frame,
				BackgroundTransparency = 1,
				Text = Label,
				TextColor3 = Color3.fromRGB(100, 100, 100),
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				Size = HasValue and UDim2.new(1, -64, 0, 44) or UDim2.new(1, 0, 1, 0),
				Position = HasValue and UDim2.new(0, 10, 0, 0) or UDim2.new(0, 0, 0, 0),
				TextXAlignment = HasValue and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})

			if HasValue then
				local ToggleBtn, _, _, SExp, GExp = BuildValueRow(Frame, Value, Placeholder, Tw, function(V)
					Value = V
				end, Numeric)
				SetExpanded = SExp
				GetExpanded = GExp

				local Th = false
				ToggleBtn.Activated:Connect(function()
					Th = true
					SetExpanded(not GetExpanded())
				end)

				local ClickArea = NewInstance("TextButton", {
					Parent = Frame,
					Size = UDim2.new(1, -36, 0, 44),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 2,
				})

				UIGesture:MakeDraggable(Frame, ClickArea)

				ClickArea.Activated:Connect(function()
					if Th then Th = false return end
					StartFn(Value, true)
				end)
			else
				local ClickArea = NewInstance("TextButton", {
					Parent = Frame,
					Size = UDim2.new(1, -8, 1, -8),
					Position = UDim2.new(0, 4, 0, 4),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 2,
				})

				UIGesture:MakeDraggable(Frame, ClickArea)

				ClickArea.Activated:Connect(function()
					StartFn(nil, true)
				end)
			end
		end

		Hud = {
			Show = function() Build(); Frame.Visible = true end,
			Hide = function()
				if not Built then return end
				if HasValue and GetExpanded() then SetExpanded(false) end
				Frame.Visible = false
			end,
			ShowOff = function() Build(); Frame.Visible = true end,
			Destroy = function()
				if Frame then Frame:Destroy(); Frame = nil; Hud.Frame = nil end
				Built = false
			end,
		}

		return Hud
	end

	function UI.HUD.MakeToggle(StartFn, StopFn, Placeholder, DefaultValue, LabelOn, LabelOff, Numeric)
		Numeric = Numeric ~= false
		local HasValue = Placeholder ~= nil and DefaultValue ~= nil
		local Active = false
		local Value = DefaultValue
		local Tw = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		local Frame, Stroke, NameLabel, ValueLabelRef, InputBoxRef, Hud
		local Built = false
		local SetExpanded, GetExpanded

		local function Build()
			if Built then return end
			Built = true

			Frame = NewInstance("Frame", {
				Parent = ScreenGui,
				BackgroundColor3 = Color3.fromRGB(22, 22, 22),
				BorderSizePixel = 0,
				Active = true,
				Visible = false,
				ClipsDescendants = HasValue,
				Size = HasValue and UDim2.new(0, 130, 0, 44) or UDim2.new(0, 100, 0, 40),
				Position = UDim2.new(0.84, 0, 0.17, 0),
			})
			Hud.Frame = Frame

			NewInstance("UICorner", { Parent = Frame, CornerRadius = UDim.new(0, 12) })

			Stroke = NewInstance("UIStroke", {
				Parent = Frame,
				Color = Color3.fromRGB(80, 220, 120),
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})

			NameLabel = NewInstance("TextLabel", {
				Parent = Frame,
				BackgroundTransparency = 1,
				Text = LabelOn,
				TextColor3 = Color3.fromRGB(80, 220, 120),
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				Size = HasValue and UDim2.new(1, -64, 0, 44) or UDim2.new(1, 0, 1, 0),
				Position = HasValue and UDim2.new(0, 10, 0, 0) or UDim2.new(0, 0, 0, 0),
				TextXAlignment = HasValue and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})

			if HasValue then
				local ToggleBtn, SLabel, IBox, SExp, GExp = BuildValueRow(Frame, Value, Placeholder, Tw, function(V)
					Value = V
					if Active then StartFn(Value, true) end
				end, Numeric)
				ValueLabelRef = SLabel
				InputBoxRef = IBox
				SetExpanded = SExp
				GetExpanded = GExp

				local Th = false
				ToggleBtn.Activated:Connect(function()
					Th = true
					SetExpanded(not GetExpanded())
				end)

				local ClickArea = NewInstance("TextButton", {
					Parent = Frame,
					Size = UDim2.new(1, -36, 0, 44),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 2,
				})

				UIGesture:MakeDraggable(Frame, ClickArea)

				ClickArea.Activated:Connect(function()
					if Th then Th = false return end
					Active = not Active
					local Col = Active and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(220, 70, 70)
					NameLabel.Text = Active and LabelOn or LabelOff
					TweenService:Create(Stroke, Tw, { Color = Col }):Play()
					TweenService:Create(NameLabel, Tw, { TextColor3 = Col }):Play()
					if Active then StartFn(Value, true) else StopFn(true) end
					if not Active and GetExpanded() then SetExpanded(false) end
				end)
			else
				local ClickArea = NewInstance("TextButton", {
					Parent = Frame,
					Size = UDim2.new(1, -8, 1, -8),
					Position = UDim2.new(0, 4, 0, 4),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 2,
				})

				UIGesture:MakeDraggable(Frame, ClickArea)

				ClickArea.Activated:Connect(function()
					Active = not Active
					local Col = Active and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(220, 70, 70)
					NameLabel.Text = Active and LabelOn or LabelOff
					TweenService:Create(Stroke, Tw, { Color = Col }):Play()
					TweenService:Create(NameLabel, Tw, { TextColor3 = Col }):Play()
					if Active then StartFn(nil, true) else StopFn(true) end
				end)
			end
		end

		Hud = {
			Show = function(NewValue)
				Build()
				if HasValue and NewValue then
					Value = tonumber(NewValue) or NewValue
					if ValueLabelRef then ValueLabelRef.Text = tostring(Value) end
					if InputBoxRef then InputBoxRef.Text = tostring(Value) end
				end
				Active = true
				Frame.Visible = true
				Stroke.Color = Color3.fromRGB(80, 220, 120)
				NameLabel.Text = LabelOn
				NameLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
				StartFn(HasValue and Value or nil)
			end,
			Hide = function()
				if not Built then return end
				Active = false
				Frame.Visible = false
				if HasValue and GetExpanded() then SetExpanded(false) end
				StopFn()
			end,
			ShowOff = function()
				Build()
				Active = false
				Frame.Visible = true
				Stroke.Color = Color3.fromRGB(220, 70, 70)
				NameLabel.Text = LabelOff
				NameLabel.TextColor3 = Color3.fromRGB(220, 70, 70)
			end,
			Destroy = function()
				if Frame then Frame:Destroy(); Frame = nil; Hud.Frame = nil end
				Built = false
			end,
		}

		return Hud
	end
end

--[[ Settings ]]--
do
	local function LevenshteinDistance(A, B)
		local ALength = #A
		local BLength = #B

		if ALength == 0 then
			return BLength
		end

		if BLength == 0 then
			return ALength
		end

		local PreviousRow = {}
		for Index = 0, BLength do
			PreviousRow[Index] = Index
		end

		for I = 1, ALength do
			local CurrentRow = {[0] = I}
			local ACharacter = string.byte(A, I)
			for J = 1, BLength do
				local Cost = (ACharacter == string.byte(B, J)) and 0 or 1
				CurrentRow[J] = math.min(PreviousRow[J] + 1, CurrentRow[J - 1] + 1, PreviousRow[J - 1] + Cost)
			end
			PreviousRow = CurrentRow
		end

		return PreviousRow[BLength]
	end

	local function ApplySearch(TabItems, Query)
		local LoweredQuery = string.lower(Query)
		local QueryLength = #LoweredQuery

		for _, Item in ipairs(TabItems) do
			if QueryLength == 0 then
				Item.Frame.Visible = true
			else
				local LoweredText = string.lower(Item.Text)
				local BestDistance = math.huge

				for StartIndex = 1, math.max(#LoweredText - QueryLength, 0) + 1 do
					local Distance = LevenshteinDistance(LoweredQuery, string.sub(LoweredText, StartIndex, StartIndex + QueryLength - 1))
					if Distance < BestDistance then
						BestDistance = Distance
					end
				end

				Item.Frame.Visible = BestDistance <= math.max(math.floor(QueryLength / 3), 1)
			end
		end
	end

	local Tab = {}
	Tab.__index = Tab

	function Tab:AddButton(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""

		local ButtonFrame = NewInstance("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 52 or 40), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, AutoButtonColor = true, Text = HasDesc and "" or Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ButtonFrame})
		local ButtonStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ButtonFrame})
		table.insert(self.Items, {Frame = ButtonFrame, Text = Config.Text or ""})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 10), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, Parent = ButtonFrame})
			NewInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 28), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, Parent = ButtonFrame})
		end

		UIGesture:MakeHoverable(ButtonFrame, nil, function(Hovering)
			if Hovering then
				TweenService:Create(ButtonStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(173, 216, 255)}):Play()
			else
				TweenService:Create(ButtonStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(150, 150, 150)}):Play()
			end
		end)

		ButtonFrame.Activated:Connect(function()
			(Config.Callback or function() end)()
		end)
	end

	function Tab:AddToggle(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""

		local ToggleFrame = NewInstance("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 52 or 40), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ToggleFrame})
		table.insert(self.Items, {Frame = ToggleFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = HasDesc and UDim2.new(1, -60, 0, 18) or UDim2.new(1, -60, 1, 0), Position = HasDesc and UDim2.new(0, 12, 0, 10) or UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = ToggleFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 12, 0, 28), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = ToggleFrame})
		end

		local Track = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = ToggleFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Track})
		local TrackStroke = NewInstance("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Track})

		local Knob = NewInstance("Frame", {AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 2, 0.5, 0), BorderSizePixel = 0, Parent = Track})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Knob})

		local Toggled = Config.Default or false

		local function Refresh(Animate)
			local TrackStrokeColor = Toggled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(100, 100, 100)
			local KnobColor = Toggled and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(150, 150, 150)
			local KnobPosition = Toggled and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)

			if Animate then
				TweenService:Create(TrackStroke, TweenInfo.new(0.15), {Color = TrackStrokeColor}):Play()
				TweenService:Create(Knob, TweenInfo.new(0.15), {BackgroundColor3 = KnobColor, Position = KnobPosition}):Play()
			else
				TrackStroke.Color = TrackStrokeColor
				Knob.BackgroundColor3 = KnobColor
				Knob.Position = KnobPosition
			end

			if Toggled then
				ToggleFrame.Image = "rbxassetid://106803105297904"
				ToggleFrame.BackgroundTransparency = 1
			else
				ToggleFrame.Image = ""
				ToggleFrame.BackgroundTransparency = 0
			end
		end

		Refresh(false)

		Track.Activated:Connect(function()
			Toggled = not Toggled
			Refresh(true);
			(Config.Callback or function() end)(Toggled)
		end)

		local ToggleAPI = {}

		function ToggleAPI:SetState(NewState)
			Toggled = NewState
			Refresh(true);
			(Config.Callback or function() end)(Toggled)
		end

		return ToggleAPI
	end

	function Tab:AddSlider(Config)
		local Min = Config.Min or 0
		local Max = Config.Max or 100
		local Step = Config.Step or 1
		local HasDesc = Config.Desc and Config.Desc ~= ""
		local HasTextbox = Config.IsTextbox ~= false

		local SliderFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 72 or 58), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SliderFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = SliderFrame})
		table.insert(self.Items, {Frame = SliderFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, HasDesc and 4 or 6), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = SliderFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 12, 0, 22), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = SliderFrame})
		end

		local Track = NewInstance("CanvasGroup", {Size = UDim2.new(1, HasTextbox and -90 or -24, 0, 22), Position = UDim2.new(0, 12, 0, HasDesc and 44 or 30), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = SliderFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Track})
		local TrackStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Track})

		local Fill = NewInstance("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 150, 255), BorderSizePixel = 0, ZIndex = 2, Parent = Track})

		local ValueLabel = NewInstance("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 4, Parent = Track})

		local InputBox = NewInstance("TextBox", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, HasDesc and 44 or 30), Size = UDim2.new(0, 58, 0, 22), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, Visible = HasTextbox, Parent = SliderFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = InputBox})
		local InputStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = InputBox})

		local Value

		local function SetValue(NewValue, FireCallback)
			Value = tonumber(string.format("%.10g", math.clamp(Min + math.floor((NewValue - Min) / Step + 0.5) * Step, Min, Max)))
			local Alpha = (Value - Min) / (Max - Min)
			Fill.Size = UDim2.new(Alpha, 0, 1, 0)
			ValueLabel.Text = tostring(Value)
			if not InputBox:IsFocused() then
				InputBox.Text = tostring(Value)
			end
			if FireCallback then
				(Config.Callback or function() end)(Value)
			end
		end

		local IsDragging = false

		UIGesture:MakePannable(Track, nil, function(Offset, _, Dragging)
			SetValue(Min + ((Offset.X / Track.AbsoluteSize.X) * (Max - Min)), true)
			if Dragging ~= IsDragging then
				IsDragging = Dragging
				TweenService:Create(TrackStroke, TweenInfo.new(0.15), {Color = Dragging and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
				if not Dragging and Config.DragEndFn then
					Config.DragEndFn(Value)
				end
			end
		end, {LockAxis = "X", Radius = {0, Track.AbsoluteSize.X}, MoveMain = false, ClickToJump = true})

		InputBox.Focused:Connect(function()
			TweenService:Create(InputStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(173, 216, 255)}):Play()
		end)

		InputBox.FocusLost:Connect(function()
			InputBox.Text = tostring(Value)
			TweenService:Create(InputStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(150, 150, 150)}):Play()
		end)

		InputBox:GetPropertyChangedSignal("Text"):Connect(function()
			local NewValue = tonumber(InputBox.Text)
			local Steps = NewValue and (NewValue - Min) / Step
			if Steps and math.abs(Steps - math.floor(Steps + 0.5)) < 0.000001 then
				SetValue(NewValue, true)
			elseif InputBox.Text == "" then
				SetValue(0, true)
			else
				InputBox.Text = tostring(Value)
			end
		end)

		SetValue(Config.Default or Min, false)
	end

	function Tab:AddInput(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""

		local InputFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 72 or 58), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = InputFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = InputFrame})
		table.insert(self.Items, {Frame = InputFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, HasDesc and 4 or 6), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = InputFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 12, 0, 22), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = InputFrame})
		end

		local InputBox = NewInstance("TextBox", {Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, HasDesc and 44 or 30), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Text = Config.Default or "", PlaceholderText = Config.Placeholder or "", PlaceholderColor3 = Color3.fromRGB(150, 150, 150), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = Config.ClearTextOnFocus ~= false, MultiLine = Config.Multiline or false, TextWrapped = Config.Multiline or false, Parent = InputFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = InputBox})
		local InputStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = InputBox})
		NewInstance("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = InputBox})

		local LastValue = Config.Default or ""

		InputBox:GetPropertyChangedSignal("Text"):Connect(function()
			if Config.Numeric then
				local Filtered = string.gsub(InputBox.Text, "[^%d%.%-]", "")
				if Filtered ~= InputBox.Text then
					InputBox.Text = Filtered
					return
				end
			end
			if not Config.Finished then
				LastValue = InputBox.Text;
				(Config.Callback or function() end)(InputBox.Text)
			end
		end)

		InputBox.Focused:Connect(function()
			TweenService:Create(InputStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(173, 216, 255)}):Play()
		end)

		InputBox.FocusLost:Connect(function(EnterPressed)
			TweenService:Create(InputStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(150, 150, 150)}):Play()
			if Config.Finished then
				if EnterPressed then
					LastValue = InputBox.Text;
					(Config.Callback or function() end)(InputBox.Text)
				else
					InputBox.Text = LastValue
				end
			end
		end)
	end

	function Tab:AddDropdown(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""
		local OptionButtons = {}
		local Expanded = false

		local DropdownFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 52 or 40), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, ClipsDescendants = true, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = DropdownFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = DropdownFrame})
		table.insert(self.Items, {Frame = DropdownFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = HasDesc and UDim2.new(1, -60, 0, 18) or UDim2.new(1, -60, 0, 40), Position = HasDesc and UDim2.new(0, 12, 0, 10) or UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = DropdownFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 12, 0, 28), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = DropdownFrame})
		end

		local ToggleButton = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -12, 0, HasDesc and 14 or 8), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, AutoButtonColor = false, Text = "+", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 16, Parent = DropdownFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleButton})
		local ToggleStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ToggleButton})

		local OptionsList = NewInstance("ScrollingFrame", {Position = UDim2.new(0, 12, 0, HasDesc and 52 or 40), Size = UDim2.new(1, -24, 0, math.clamp(#Config.Options * 32 - 2, 0, 150)), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = DropdownFrame})
		NewInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = OptionsList})
		NewInstance("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = OptionsList})

		for Index, Option in ipairs(Config.Options) do
			local IsSelected = (Config.Multi and Config.Default and table.find(Config.Default, Option) ~= nil) or (not Config.Multi and Config.Default == Option)

			local OptionButton = NewInstance("TextButton", {LayoutOrder = Index, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, AutoButtonColor = false, Text = tostring(Option), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = OptionsList})
			NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = OptionButton})
			local OptionStroke = NewInstance("UIStroke", {Color = IsSelected and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = OptionButton})
			NewInstance("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = OptionButton})
			table.insert(OptionButtons, {Stroke = OptionStroke, Value = Option, Selected = IsSelected})

			OptionButton.Activated:Connect(function()
				if Config.Multi then
					local Data = OptionButtons[Index]
					Data.Selected = not Data.Selected
					TweenService:Create(Data.Stroke, TweenInfo.new(0.15), {Color = Data.Selected and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()

					local Result = {}
					for _, ResultData in ipairs(OptionButtons) do
						if ResultData.Selected then
							table.insert(Result, ResultData.Value)
						end
					end
					(Config.Callback or function() end)(Result)
				else
					for _, Data in ipairs(OptionButtons) do
						TweenService:Create(Data.Stroke, TweenInfo.new(0.15), {Color = Data.Value == Option and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
					end
					(Config.Callback or function() end)(Option)
				end
			end)
		end

		UIGesture:MakeHoverable(ToggleButton, nil, function(Hovering)
			TweenService:Create(ToggleStroke, TweenInfo.new(0.15), {Color = Hovering and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
		end)

		ToggleButton.Activated:Connect(function()
			Expanded = not Expanded
			ToggleButton.Text = Expanded and "-" or "+"
			TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, (HasDesc and 52 or 40) + (Expanded and math.clamp(#Config.Options * 32 - 2, 0, 150) + 12 or 0))}):Play()
		end)
	end

	function Tab:AddKeyPicker(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""

		local KeyPickerFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 52 or 40), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = KeyPickerFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = KeyPickerFrame})
		table.insert(self.Items, {Frame = KeyPickerFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = HasDesc and UDim2.new(1, -110, 0, 18) or UDim2.new(1, -110, 1, 0), Position = HasDesc and UDim2.new(0, 12, 0, 10) or UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = KeyPickerFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -110, 0, 14), Position = UDim2.new(0, 12, 0, 28), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = KeyPickerFrame})
		end

		local KeyButton = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0, 90, 0, 24), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, AutoButtonColor = false, Text = Config.Default and Config.Default.Name or "None", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 13, Parent = KeyPickerFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = KeyButton})
		local KeyStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = KeyButton})

		local Mode = Config.Mode or "Toggle"
		local Key = Config.Default
		local Listening = false
		local Toggled = false
		local Locked = false

		UIGesture:MakeHoverable(KeyButton, nil, function(Hovering)
			if not Listening then
				TweenService:Create(KeyStroke, TweenInfo.new(0.15), {Color = Hovering and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
			end
		end)

		KeyButton.Activated:Connect(function()
			Listening = true
			KeyButton.Text = "..."
			TweenService:Create(KeyStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 200, 80)}):Play()
		end)

		UserInputService.InputBegan:Connect(function(Input, GameProcessed)
			if Listening then
				if Input.UserInputType == Enum.UserInputType.Keyboard then
					Key = Input.KeyCode
					KeyButton.Text = Key.Name
					Listening = false
					TweenService:Create(KeyStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(150, 150, 150)}):Play()
				end
				return
			end

			if GameProcessed or not Key or Input.KeyCode ~= Key then
				return
			end

			if Mode == "Toggle" then
				Toggled = not Toggled;
				(Config.Callback or function() end)(Toggled)
			elseif Mode == "Hold" then
				(Config.Callback or function() end)(true)
			elseif Mode == "Press" then
				if Locked then
					return
				end
				if Config.WaitForCallback then
					Locked = true
					(Config.Callback or function() end)(true)
					Locked = false
				else
					(Config.Callback or function() end)(true)
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(Input, GameProcessed)
			if Listening or GameProcessed or not Key or Input.KeyCode ~= Key then
				return
			end

			if Mode == "Hold" then
				(Config.Callback or function() end)(false)
			end
		end)

		if Mode == "Always" then
			(Config.Callback or function() end)(true)
		end
	end

	function Tab:AddLabel(Config)
		local TextXAlignment = (Config.Alignment == "Right" and Enum.TextXAlignment.Right) or (Config.Alignment == "Center" and Enum.TextXAlignment.Center) or Enum.TextXAlignment.Left

		local LabelFrame = NewInstance("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = Config.Text or "", TextWrapped = true, RichText = Config.RichText or false, TextColor3 = Config.Color or Color3.fromRGB(255, 255, 255), Font = Config.Font or Enum.Font.Gotham, TextSize = Config.TextSize or 14, TextXAlignment = TextXAlignment, Parent = self.Content})
		table.insert(self.Items, {Frame = LabelFrame, Text = Config.Text or ""})
	end

	function Tab:AddColorPicker(Config)
		local HasDesc = Config.Desc and Config.Desc ~= ""

		local ColorPickerFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 0, HasDesc and 52 or 40), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, Parent = self.Content})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ColorPickerFrame})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ColorPickerFrame})
		table.insert(self.Items, {Frame = ColorPickerFrame, Text = Config.Text or ""})

		NewInstance("TextLabel", {Size = HasDesc and UDim2.new(1, -60, 0, 18) or UDim2.new(1, -60, 1, 0), Position = HasDesc and UDim2.new(0, 12, 0, 10) or UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = Config.Text or "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = ColorPickerFrame})

		if HasDesc then
			NewInstance("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 12, 0, 28), BackgroundTransparency = 1, Text = Config.Desc, TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 0.3, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = ColorPickerFrame})
		end

		local Swatch = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0, 34, 0, 24), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = Config.DefaultColor or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = ColorPickerFrame})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Swatch})
		local SwatchStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Swatch})

		UIGesture:MakeHoverable(Swatch, nil, function(Hovering)
			TweenService:Create(SwatchStroke, TweenInfo.new(0.15), {Color = Hovering and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
		end)

		local Hue, Sat, Vib = (Config.DefaultColor or Color3.fromRGB(255, 255, 255)):ToHSV()

		local Panel = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.25, 0.6), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, Visible = false, ZIndex = 10, Parent = ScreenGui2})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Panel})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Panel})
		NewInstance("UIAspectRatioConstraint", {AspectRatio = 190 / 258, Parent = Panel})
		NewInstance("UIPadding", {PaddingTop = UDim.new(0.0388, 0), PaddingLeft = UDim.new(0.0526, 0), PaddingRight = UDim.new(0.0526, 0), PaddingBottom = UDim.new(0.0388, 0), Parent = Panel})

		local TitleBar = NewInstance("Frame", {Size = UDim2.fromScale(1, 0.1008), BackgroundTransparency = 1, Parent = Panel})
		NewInstance("UITextSizeConstraint", {MaxTextSize = 14, Parent = NewInstance("TextLabel", {Size = UDim2.fromScale(0.8588, 1), BackgroundTransparency = 1, Text = "Color Editor", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar})})
		local CloseButton = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromScale(0.1176, 0.8333), BackgroundTransparency = 1, AutoButtonColor = false, Text = "X", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Nunito, TextScaled = true, TextSize = 18, Parent = TitleBar})
		NewInstance("UITextSizeConstraint", {MaxTextSize = 18, Parent = CloseButton})

		local SatVal = NewInstance("Frame", {Position = UDim2.fromScale(0, 0.1345), Size = UDim2.fromScale(1, 0.6303), BackgroundColor3 = Color3.fromHSV(Hue, 1, 1), BorderSizePixel = 0, ClipsDescendants = true, Parent = Panel})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SatVal})

		local SatOverlay = NewInstance("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = SatVal})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SatOverlay})
		NewInstance("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)), Transparency = NumberSequence.new(0, 1), Parent = SatOverlay})

		local VibOverlay = NewInstance("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = SatVal})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = VibOverlay})
		NewInstance("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0)), Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = VibOverlay})

		local SatValCursor = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.0588, 0.0667), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 3, Parent = SatVal})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SatValCursor})
		NewInstance("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = SatValCursor})

		local HueBar = NewInstance("Frame", {Size = UDim2.fromScale(1, 0.0672), Position = UDim2.fromScale(0, 0.8067), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = Panel})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = HueBar})
		NewInstance("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))}), Parent = HueBar})

		local HueCursor = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.0235, 1.25), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 3, Parent = HueBar})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = HueCursor})
		NewInstance("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = HueCursor})

		local HexBox = NewInstance("TextBox", {Size = UDim2.fromScale(1, 0.1092), Position = UDim2.fromScale(0, 0.916), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Text = "#" .. (Config.DefaultColor or Color3.fromRGB(255, 255, 255)):ToHex(), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextScaled = true, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false, Parent = Panel})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = HexBox})
		NewInstance("UITextSizeConstraint", {MaxTextSize = 13, Parent = HexBox})
		local HexStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = HexBox})

		local function Refresh(FireCallback)
			local Color = Color3.fromHSV(Hue, Sat, Vib)
			Swatch.BackgroundColor3 = Color
			SatVal.BackgroundColor3 = Color3.fromHSV(Hue, 1, 1)
			SatValCursor.Position = UDim2.fromScale(Sat, 1 - Vib)
			HueCursor.Position = UDim2.fromScale(Hue, 0.5)
			if not HexBox:IsFocused() then
				HexBox.Text = "#" .. Color:ToHex()
			end
			if FireCallback then
				(Config.Callback or function() end)(Color)
			end
		end

		UIGesture:MakePannable(SatVal, nil, function(Offset)
			Sat = math.clamp(Offset.X / SatVal.AbsoluteSize.X, 0, 1)
			Vib = 1 - math.clamp(Offset.Y / SatVal.AbsoluteSize.Y, 0, 1)
			Refresh(true)
		end, {MoveMain = false, ClickToJump = true})

		UIGesture:MakePannable(HueBar, nil, function(Offset)
			Hue = math.clamp(Offset.X / HueBar.AbsoluteSize.X, 0, 1)
			Refresh(true)
		end, {LockAxis = "X", Radius = {0, HueBar.AbsoluteSize.X}, MoveMain = false, ClickToJump = true})

		HexBox.Focused:Connect(function()
			TweenService:Create(HexStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(173, 216, 255)}):Play()
		end)

		HexBox.FocusLost:Connect(function()
			TweenService:Create(HexStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(150, 150, 150)}):Play()
			local Ok, NewColor = pcall(Color3.fromHex, HexBox.Text)
			if Ok then
				Hue, Sat, Vib = NewColor:ToHSV()
				Refresh(true)
			else
				Refresh(false)
			end
		end)

		UIGesture:MakeDraggable(Panel, TitleBar)

		CloseButton.Activated:Connect(function()
			Panel.Visible = false
		end)

		Swatch.Activated:Connect(function()
			Panel.Visible = not Panel.Visible
		end)

		Refresh(false)
	end

	local MainFrame = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.65, 0.70), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, Visible = false, Parent = ScreenGui2})
	NewInstance("UIAspectRatioConstraint", {AspectRatio = 832 / 504, DominantAxis = Enum.DominantAxis.Width, Parent = MainFrame})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = MainFrame})
	NewInstance("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = MainFrame})

	local TitleBar = NewInstance("Frame", {Size = UDim2.fromScale(1, 0.0714), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = MainFrame})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = TitleBar})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 15, Parent = NewInstance("TextLabel", {Size = UDim2.fromScale(0.9447, 1), Position = UDim2.fromScale(0.0144, 0), BackgroundTransparency = 1, Text = "Settings", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar})})

	local CloseButton = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromScale(0.0288, 0.6667), Position = UDim2.fromScale(0.95, 0.5), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, AutoButtonColor = false, Text = "X", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Nunito, TextScaled = true, TextSize = 25, Parent = TitleBar})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = CloseButton})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 25, Parent = CloseButton})
	local CloseStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = CloseButton})

	CloseButton.Activated:Connect(function()
		MainFrame.Visible = false
	end)

	UIGesture:MakeHoverable(CloseButton, nil, function(Hovering)
		TweenService:Create(CloseStroke, TweenInfo.new(0.15), {Color = Hovering and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
	end)

	UIGesture:MakeDraggable(MainFrame, TitleBar)

	NewInstance("Frame", {Size = UDim2.fromScale(1, 0.0020), Position = UDim2.fromScale(0, 0.0714), BackgroundColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = MainFrame})
	NewInstance("Frame", {Size = UDim2.fromScale(0.0012, 0.9266), Position = UDim2.fromScale(0.28, 0.0734), BackgroundColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = MainFrame})

	local SidebarBackground = NewInstance("Frame", {Position = UDim2.fromScale(0, 0.0734), Size = UDim2.fromScale(0.28, 0.9266), BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, Parent = MainFrame})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SidebarBackground})

	local Sidebar = NewInstance("ScrollingFrame", {Position = UDim2.fromScale(0, 0.1528), Size = UDim2.fromScale(0.28, 0.8472), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = MainFrame})
	NewInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = Sidebar})
	NewInstance("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = Sidebar})

	local SearchBox = NewInstance("TextBox", {Position = UDim2.fromScale(0.0072, 0.0853), Size = UDim2.fromScale(0.2656, 0.0556), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Text = "", PlaceholderText = "Search", PlaceholderColor3 = Color3.fromRGB(150, 150, 150), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextScaled = true, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = MainFrame})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = SearchBox})
	local SearchStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = SearchBox})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 13, Parent = SearchBox})
	NewInstance("UIPadding", {PaddingLeft = UDim.new(0.0156, 0), PaddingRight = UDim.new(0.0156, 0), Parent = SearchBox})

	SearchBox.Focused:Connect(function()
		TweenService:Create(SearchStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(173, 216, 255)}):Play()
	end)

	SearchBox.FocusLost:Connect(function()
		TweenService:Create(SearchStroke, TweenInfo.new(1.2), {Color = Color3.fromRGB(150, 150, 150)}):Play()
	end)

	local Content = NewInstance("ScrollingFrame", {Position = UDim2.fromScale(0.28, 0.0734), Size = UDim2.fromScale(0.72, 0.9266), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = MainFrame})
	NewInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = Content})
	NewInstance("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = Content})

	local Tabs = {}

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		for _, ExistingTab in ipairs(Tabs) do
			ApplySearch(ExistingTab.Items, SearchBox.Text)
		end
	end)

	function UI.Settings.AddTab(Config)
		local TabButton = NewInstance("TextButton", {Size = UDim2.fromScale(1, 0.0796), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = Sidebar})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 8), Parent = TabButton})

		local Indicator = NewInstance("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromScale(0.0172, 0.4216), BackgroundColor3 = Color3.fromRGB(90, 150, 255), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = TabButton})
		NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Indicator})

		local IconLabel = NewInstance("ImageLabel", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.0601, 0.5), Size = UDim2.fromScale(0.0773, 0.4216), BackgroundTransparency = 1, Image = Config.Icon and Config.Icon.Deselected or "", Visible = false, Parent = TabButton})

		local TabLabel = NewInstance("TextLabel", {Size = UDim2.fromScale(0.9399, 1), Position = UDim2.fromScale(0.0601, 0), BackgroundTransparency = 1, Text = Config.Name or "", TextColor3 = Color3.fromRGB(190, 190, 190), Font = Enum.Font.Gotham, TextScaled = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = TabButton})
		NewInstance("UITextSizeConstraint", {MaxTextSize = 14, Parent = TabLabel})

		local TabContent = NewInstance("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = Content})
		NewInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = TabContent})

		local Tab = setmetatable({Button = TabButton, Indicator = Indicator, Label = TabLabel, Content = TabContent, IconLabel = IconLabel, Icon = Config.Icon, Selected = false, Items = {}}, Tab)

		if Config.Icon then
			task.spawn(function()
				local DeselectedValid = false
				local SelectedValid = false

				ContentProvider:PreloadAsync({Config.Icon.Deselected, Config.Icon.Selected}, function(ContentId, Status)
					if Status == Enum.AssetFetchStatus.Success then
						if ContentId == Config.Icon.Deselected then
							DeselectedValid = true
						elseif ContentId == Config.Icon.Selected then
							SelectedValid = true
						end
					end
				end)

				Tab.DeselectedIconValid = DeselectedValid
				Tab.SelectedIconValid = SelectedValid

				if DeselectedValid or SelectedValid then
					IconLabel.Visible = true
					TabLabel.Position = UDim2.fromScale(0.1631, 0)
					TabLabel.Size = UDim2.fromScale(0.8369, 1)

					if Tab.Selected and SelectedValid then
						IconLabel.Image = Config.Icon.Selected
					elseif DeselectedValid then
						IconLabel.Image = Config.Icon.Deselected
					else
						IconLabel.Image = Config.Icon.Selected
					end
				end
			end)
		end

		local function SelectTab()
			for _, ExistingTab in ipairs(Tabs) do
				TweenService:Create(ExistingTab.Indicator, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
				TweenService:Create(ExistingTab.Button, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
				ExistingTab.Label.TextColor3 = Color3.fromRGB(190, 190, 190)
				ExistingTab.Content.Visible = false
				ExistingTab.Selected = false
				if ExistingTab.DeselectedIconValid then
					ExistingTab.IconLabel.Image = ExistingTab.Icon.Deselected
				end
			end
			TweenService:Create(Indicator, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
			TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
			TabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			TabContent.Visible = true
			Tab.Selected = true
			if Tab.SelectedIconValid then
				IconLabel.Image = Tab.Icon.Selected
			end
			ApplySearch(Tab.Items, SearchBox.Text)
		end

		TabButton.Activated:Connect(SelectTab)
		table.insert(Tabs, Tab)

		if #Tabs == 1 then
			SelectTab()
		end

		return Tab
	end

	function UI.Settings.ShowWindow()
		MainFrame.Visible = true
	end
end

--[[ UIScale ]]--
do
	local Panel = NewInstance("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.35, 0.35), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, Visible = false, Parent = ScreenGui2})
	NewInstance("UIAspectRatioConstraint", {AspectRatio = 280 / 104, Parent = Panel})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Panel})
	NewInstance("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Panel})

	local TitleBar = NewInstance("Frame", {Size = UDim2.fromScale(1, 0.3462), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = Panel})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = TitleBar})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 15, Parent = NewInstance("TextLabel", {Size = UDim2.fromScale(0.8357, 1), Position = UDim2.fromScale(0.0429, 0), BackgroundTransparency = 1, Text = "UIScaler", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = TitleBar})})

	local CloseButton = NewInstance("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromScale(0.0714, 0.5556), Position = UDim2.fromScale(0.9714, 0.5), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, AutoButtonColor = false, Text = "X", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Nunito, TextScaled = true, TextSize = 25, Parent = TitleBar})
	NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = CloseButton})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 25, Parent = CloseButton})
	local CloseStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = CloseButton})

	NewInstance("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.3462), BackgroundColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = Panel})

	local Track = NewInstance("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5481), Size = UDim2.fromScale(0.8857, 0.2115), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Parent = Panel})
	NewInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Track})
	local TrackStroke = NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Track})

	local Fill = NewInstance("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 150, 255), BorderSizePixel = 0, ZIndex = 2, Parent = Track})

	local ValueLabel = NewInstance("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true, TextSize = 13, ZIndex = 4, Parent = Track})
	NewInstance("UITextSizeConstraint", {MaxTextSize = 13, Parent = ValueLabel})

	local IsDragging = false

	local function SetValue(NewValue, FireCallback)
		local Value = tonumber(string.format("%.2f", math.round(math.clamp(NewValue, 0.5, 2.5) / 0.05) * 0.05))
		local Alpha = (Value - 0.5) / (2.5 - 0.5)
		Fill.Size = UDim2.new(Alpha, 0, 1, 0)
		ValueLabel.Text = string.format("%.2fx", Value)
		if FireCallback then
			Scale.Scale = Value
			UI.ScaleSliderFn(Value)
		end
	end

	function UI.SetScale(Value)
		SetValue(Value, true)
	end

	function UI.OpenUIScale()
		Panel.Visible = true
	end

	local function CreateStepButton(Text, PositionX, Width)
		local Button = NewInstance("TextButton", {AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromScale(Width, 0.2115), Position = UDim2.fromScale(PositionX, 0.8365), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 0, AutoButtonColor = false, Text = Text, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextScaled = true, TextSize = 13, Parent = Panel})
		NewInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Button})
		NewInstance("UITextSizeConstraint", {MaxTextSize = 13, Parent = Button})
		NewInstance("UIStroke", {Color = Color3.fromRGB(150, 150, 150), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Button})
		return Button
	end

	CreateStepButton("-", 0.0571, 0.2286).Activated:Connect(function()
		SetValue(Scale.Scale - 0.05, true)
		UI.ScaleSliderDragEndFn(Scale.Scale)
	end)

	CreateStepButton("Reset", 0.3, 0.4).Activated:Connect(function()
		SetValue(1, true)
		UI.ScaleSliderDragEndFn(Scale.Scale)
	end)

	CreateStepButton("+", 0.7143, 0.2286).Activated:Connect(function()
		SetValue(Scale.Scale + 0.05, true)
		UI.ScaleSliderDragEndFn(Scale.Scale)
	end)

	UIGesture:MakePannable(Track, nil, function(Offset, _, Dragging)
		SetValue(0.5 + (Offset.X / Track.AbsoluteSize.X) * (2.5 - 0.5), true)
		if Dragging ~= IsDragging then
			IsDragging = Dragging
			TweenService:Create(TrackStroke, TweenInfo.new(0.15), {Color = Dragging and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
			if not Dragging then
				UI.ScaleSliderDragEndFn(Scale.Scale)
			end
		end
	end, {LockAxis = "X", Radius = {0, Track.AbsoluteSize.X}, MoveMain = false, ClickToJump = true})

	UIGesture:MakeHoverable(CloseButton, nil, function(Hovering)
		TweenService:Create(CloseStroke, TweenInfo.new(0.15), {Color = Hovering and Color3.fromRGB(173, 216, 255) or Color3.fromRGB(150, 150, 150)}):Play()
	end)

	CloseButton.Activated:Connect(function()
		Panel.Visible = false
	end)

	SetValue(Scale.Scale, false)
end

return UI
