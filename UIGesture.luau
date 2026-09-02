local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

export type GestureHandle = {
	Disconnect: (self: GestureHandle) -> (),
}

export type SwipeDirection = "Left" | "Right" | "Up" | "Down"

export type SwipeCallback = (direction: SwipeDirection, distance: number) -> ()

export type UIGesture = {
	MakeDraggable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeResizeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, MinSize: Vector2?, MaxSize: Vector2?) -> GestureHandle,
	MakeSwipeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: SwipeCallback?, Threshold: number?, MaxTime: number?) -> GestureHandle,
	MakeRotatable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeZoomable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, MinSize: Vector2?, MaxSize: Vector2?, ZoomStep: number?) -> GestureHandle,
}

local UIGesture = {} :: UIGesture

function UIGesture:MakeDraggable(Main, Handle)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main or Handle, "MakeDraggable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	local dragging = false
	local ActiveInput, DragInput, DragStart, StartPos, StartAbsPos

	local Conn = {}
	local self = {}

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if dragging then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			ActiveInput = input
			DragStart = input.Position
			StartPos = Main.Position
			StartAbsPos = Main.AbsolutePosition

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					dragging = false
					ActiveInput = nil
					DragInput = nil
				end
			end)
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	Conn[3] = UserInputService.InputChanged:Connect(function(input)
		if dragging and input == DragInput then

			local delta = input.Position - DragStart
			local desiredAbsX = StartAbsPos.X + delta.X
			local desiredAbsY = StartAbsPos.Y + delta.Y

			local viewportSize = workspace.CurrentCamera.ViewportSize

			local minX = 0
			local minY = -GuiService:GetGuiInset().Y
			local maxX = viewportSize.X - Main.AbsoluteSize.X
			local maxY = viewportSize.Y - Main.AbsoluteSize.Y

			local clampedAbsX = (minX > maxX) and minX or math.clamp(desiredAbsX, minX, maxX)
			local clampedAbsY = (minY > maxY) and minY or math.clamp(desiredAbsY, minY, maxY)

			Main.Position = UDim2.new(
				StartPos.X.Scale,
				StartPos.X.Offset + (clampedAbsX - StartAbsPos.X),
				StartPos.Y.Scale,
				StartPos.Y.Offset + (clampedAbsY - StartAbsPos.Y)
			)
		end
	end)

	function self:Disconnect()
		dragging = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeResizeable(Main, Handle, MinSize, MaxSize)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main or Handle, "MakeResizeable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	MinSize = MinSize or Vector2.new(5, 5)
	MaxSize = MaxSize or Vector2.new(math.huge, math.huge)

	local resizing = false
	local ActiveInput, DragInput, DragStart, StartSize, StartAbsSize, StartAbsPos

	local Conn = {}
	local self = {}

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if resizing then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			ActiveInput = input
			DragStart = input.Position
			StartSize = Main.Size
			StartAbsSize = Main.AbsoluteSize
			StartAbsPos = Main.AbsolutePosition

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					resizing = false
					ActiveInput = nil
					DragInput = nil
				end
			end)
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	Conn[3] = UserInputService.InputChanged:Connect(function(input)
		if resizing and input == DragInput then

			local delta = input.Position - DragStart
			local desiredAbsWidth = StartAbsSize.X + delta.X
			local desiredAbsHeight = StartAbsSize.Y + delta.Y

			local viewportSize = workspace.CurrentCamera.ViewportSize

			local maxWidth = math.min(viewportSize.X - StartAbsPos.X, MaxSize.X)
			local maxHeight = math.min(viewportSize.Y - StartAbsPos.Y, MaxSize.Y)

			local clampedAbsWidth = (MinSize.X > maxWidth) and MinSize.X or math.clamp(desiredAbsWidth, MinSize.X, maxWidth)
			local clampedAbsHeight = (MinSize.Y > maxHeight) and MinSize.Y or math.clamp(desiredAbsHeight, MinSize.Y, maxHeight)

			Main.Size = UDim2.new(
				StartSize.X.Scale,
				StartSize.X.Offset + (clampedAbsWidth - StartAbsSize.X),
				StartSize.Y.Scale,
				StartSize.Y.Offset + (clampedAbsHeight - StartAbsSize.Y)
			)
		end
	end)

	function self:Disconnect()
		resizing = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeSwipeable(Main, Handle, Callback, Threshold, MaxTime)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakeSwipeable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	Threshold = Threshold or 50
	MaxTime = MaxTime or 0.5

	local swiping = false
	local ActiveInput, StartPos, StartTime

	local Conn = {}
	local self = {}

	local function GetDirection(delta)
		if delta.Magnitude < Threshold then
			return nil
		end

		if math.abs(delta.X) > math.abs(delta.Y) then
			return delta.X > 0 and "Right" or "Left"
		else
			return delta.Y > 0 and "Down" or "Up"
		end
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if swiping then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			swiping = true
			ActiveInput = input
			StartPos = input.Position
			StartTime = os.clock()

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					swiping = false
					ActiveInput = nil

					local elapsed = os.clock() - StartTime
					if elapsed <= MaxTime then
						local delta = input.Position - StartPos
						local direction = GetDirection(delta)

						if direction and Callback then
							Callback(direction, delta.Magnitude)
						end
					end
				end
			end)
		end
	end)

	function self:Disconnect()
		swiping = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeRotatable(Main, Handle)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakeRotatable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	local rotating = false
	local ActiveInput, DragInput, StartAngle, StartRotation

	local Conn = {}
	local self = {}

	local function GetAngle(inputPosition)
		local center = Main.AbsolutePosition + Main.AbsoluteSize / 2
		local delta = Vector2.new(inputPosition.X, inputPosition.Y) - center
		return math.deg(math.atan2(delta.Y, delta.X))
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if rotating then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			rotating = true
			ActiveInput = input
			StartAngle = GetAngle(input.Position)
			StartRotation = Main.Rotation

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					rotating = false
					ActiveInput = nil
					DragInput = nil
				end
			end)
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	Conn[3] = UserInputService.InputChanged:Connect(function(input)
		if rotating and input == DragInput then
			local currentAngle = GetAngle(input.Position)
			Main.Rotation = StartRotation + (currentAngle - StartAngle)
		end
	end)

	function self:Disconnect()
		rotating = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeZoomable(Main, Handle, MinSize, MaxSize, ZoomStep)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakeZoomable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	MinSize = MinSize or Vector2.new(20, 20)
	MaxSize = MaxSize or Vector2.new(math.huge, math.huge)
	ZoomStep = ZoomStep or 0.1

	local pinching = false
	local TouchA, TouchB, StartDistance, StartSize, StartAbsSize, StartPos, StartAbsPos

	local Conn = {}
	local self = {}

	local function ApplyScale(scale, baseSize, baseAbsSize, basePos, baseAbsPos)
		local center = baseAbsPos + baseAbsSize / 2

		local desiredAbsWidth = baseAbsSize.X * scale
		local desiredAbsHeight = baseAbsSize.Y * scale

		local clampedAbsWidth = math.clamp(desiredAbsWidth, MinSize.X, MaxSize.X)
		local clampedAbsHeight = math.clamp(desiredAbsHeight, MinSize.Y, MaxSize.Y)

		local desiredAbsX = center.X - clampedAbsWidth / 2
		local desiredAbsY = center.Y - clampedAbsHeight / 2

		Main.Size = UDim2.new(
			baseSize.X.Scale,
			baseSize.X.Offset + (clampedAbsWidth - baseAbsSize.X),
			baseSize.Y.Scale,
			baseSize.Y.Offset + (clampedAbsHeight - baseAbsSize.Y)
		)

		Main.Position = UDim2.new(
			basePos.X.Scale,
			basePos.X.Offset + (desiredAbsX - baseAbsPos.X),
			basePos.Y.Scale,
			basePos.Y.Offset + (desiredAbsY - baseAbsPos.Y)
		)
	end

	local function EndTouch(input)
		if input == TouchA then
			TouchA = nil
		elseif input == TouchB then
			TouchB = nil
		end
		pinching = false
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if not TouchA then
			TouchA = input
		elseif not TouchB then
			TouchB = input
		else
			return
		end

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel then
				EndTouch(input)
			end
		end)

		if TouchA and TouchB then
			pinching = true
			StartDistance = (TouchA.Position - TouchB.Position).Magnitude
			StartSize = Main.Size
			StartAbsSize = Main.AbsoluteSize
			StartPos = Main.Position
			StartAbsPos = Main.AbsolutePosition
		end
	end)

	Conn[2] = UserInputService.InputChanged:Connect(function(input)
		if not pinching then return end
		if input ~= TouchA and input ~= TouchB then return end

		local currentDistance = (TouchA.Position - TouchB.Position).Magnitude
		local scale = currentDistance / StartDistance

		ApplyScale(scale, StartSize, StartAbsSize, StartPos, StartAbsPos)
	end)

	Conn[3] = Handle.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end

		local direction = input.Position.Z
		local scale = 1 + (direction * ZoomStep)

		ApplyScale(scale, Main.Size, Main.AbsoluteSize, Main.Position, Main.AbsolutePosition)
	end)

	function self:Disconnect()
		pinching = false
		TouchA = nil
		TouchB = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

return UIGesture

