local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

export type GestureHandle = {
	Disconnect: (self: GestureHandle) -> (),
}

export type SwipeDirection = "Left" | "Right" | "Up" | "Down"

export type SwipeCallback = (direction: SwipeDirection, distance: number) -> ()

export type PanCallback = (delta: Vector2, magnitude: number) -> ()

export type UIGesture = {
	MakeDraggable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeResizeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, MinSize: Vector2?, MaxSize: Vector2?) -> GestureHandle,
	MakeSwipeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: SwipeCallback?, Threshold: number?, MaxTime: number?) -> GestureHandle,
	MakeRotatable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeZoomable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Content: GuiObject?, MinZoom: number?, MaxZoom: number?, ZoomStep: number?) -> GestureHandle,
	MakePannable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: PanCallback?, Radius: number?, ReturnToCenter: boolean?, LockAxis: ("X" | "Y")?) -> GestureHandle,
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

function UIGesture:MakeZoomable(Main, Handle, Content, MinZoom, MaxZoom, ZoomStep)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakeZoomable: needs at least one GuiObject")
	assert(Content, "MakeZoomable: needs a Content GuiObject to scale")

	if not Handle.Active then
		Handle.Active = true
	end

	MinZoom = MinZoom or 0.3
	MaxZoom = MaxZoom or 1
	ZoomStep = ZoomStep or 0.1

	local ContentScale = Content:FindFirstChildOfClass("UIScale")
	if not ContentScale then
		ContentScale = Instance.new("UIScale")
		ContentScale.Parent = Content
	end

	local function GetFitScale()
		local currentScale = ContentScale.Scale
		if currentScale <= 0 then
			currentScale = 1
		end

		local baseContentSize = Content.AbsoluteSize / currentScale
		if baseContentSize.X <= 0 or baseContentSize.Y <= 0 then
			return 1
		end

		return math.min(
			Main.AbsoluteSize.X / baseContentSize.X,
			Main.AbsoluteSize.Y / baseContentSize.Y
		)
	end

	local pinching = false
	local TouchA, TouchB, StartDistance, StartScale, StartAbsSize, StartPos, StartAbsPos

	local Conn = {}
	local self = {}

	local function ApplyZoom(factor, baseScale, baseAbsSize, basePos, baseAbsPos)
		local fitScale = GetFitScale()
		local zoomInLimit = (MinZoom > 0) and MinZoom or 1
		local zoomOutLimit = (MaxZoom > 0) and MaxZoom or 1

		local minAllowedScale = fitScale / zoomOutLimit
		local maxAllowedScale = fitScale / zoomInLimit

		local clampedScale = math.clamp(baseScale * factor, minAllowedScale, maxAllowedScale)

		local center = baseAbsPos + baseAbsSize / 2
		local newAbsSize = baseAbsSize * (clampedScale / baseScale)

		local desiredAbsX = center.X - newAbsSize.X / 2
		local desiredAbsY = center.Y - newAbsSize.Y / 2

		local anchor = Content.AnchorPoint
		local sizeDelta = newAbsSize - baseAbsSize

		Content.Position = UDim2.new(
			basePos.X.Scale,
			basePos.X.Offset + (desiredAbsX - baseAbsPos.X) + anchor.X * sizeDelta.X,
			basePos.Y.Scale,
			basePos.Y.Offset + (desiredAbsY - baseAbsPos.Y) + anchor.Y * sizeDelta.Y
		)

		ContentScale.Scale = clampedScale
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
			StartScale = ContentScale.Scale
			StartAbsSize = Content.AbsoluteSize
			StartPos = Content.Position
			StartAbsPos = Content.AbsolutePosition
		end
	end)

	Conn[2] = UserInputService.InputChanged:Connect(function(input)
		if not pinching then return end
		if input ~= TouchA and input ~= TouchB then return end

		local currentDistance = (TouchA.Position - TouchB.Position).Magnitude
		local factor = currentDistance / StartDistance

		ApplyZoom(factor, StartScale, StartAbsSize, StartPos, StartAbsPos)
	end)

	Conn[3] = Handle.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end

		local direction = input.Position.Z
		local factor = 1 + (direction * ZoomStep)

		ApplyZoom(factor, ContentScale.Scale, Content.AbsoluteSize, Content.Position, Content.AbsolutePosition)
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

function UIGesture:MakePannable(Main, Handle, Callback, Radius, ReturnToCenter, LockAxis)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakePannable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	local panning = false
	local ActiveInput, DragInput, DragStart, StartPos

	local Conn = {}
	local self = {}

	local function ApplyPan(offset)
		Main.Position = UDim2.new(
			StartPos.X.Scale,
			StartPos.X.Offset + offset.X,
			StartPos.Y.Scale,
			StartPos.Y.Offset + offset.Y
		)

		if Callback then
			Callback(offset, offset.Magnitude)
		end
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if panning then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			panning = true
			ActiveInput = input
			DragStart = input.Position
			StartPos = Main.Position

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					panning = false
					ActiveInput = nil
					DragInput = nil

					if ReturnToCenter then
						ApplyPan(Vector2.new(0, 0))
					end
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
		if panning and input == DragInput then
			local delta = input.Position - DragStart
			local offset = Vector2.new(delta.X, delta.Y)

			if LockAxis == "X" then
				offset = Vector2.new(offset.X, 0)
			elseif LockAxis == "Y" then
				offset = Vector2.new(0, offset.Y)
			end

			if Radius and offset.Magnitude > Radius then
				offset = offset.Unit * Radius
			end

			ApplyPan(offset)
		end
	end)

	function self:Disconnect()
		panning = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

return UIGesture
