local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

export type GestureHandle = {
	Disconnect: (self: GestureHandle) -> (),
}

export type SwipeDirection = "Left" | "Right" | "Up" | "Down"

export type SwipeCallback = (direction: SwipeDirection, distance: number) -> ()

export type PanCallback = (delta: Vector2, magnitude: number) -> ()

export type HoverCallback = (Hovering: boolean) -> ()

export type PanConfig = {
	Radius: (number | {number})?,
	ReturnToCenter: boolean?,
	LockAxis: ("X" | "Y")?,
	MoveMain: boolean?,
	Momentum: boolean?,
	Friction: number?,
	PanButton: Enum.UserInputType?,
}

export type UIGesture = {
	MakeDraggable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeResizeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, MinSize: Vector2?, MaxSize: Vector2?) -> GestureHandle,
	MakeSwipeable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: SwipeCallback?, Threshold: number?, MaxTime: number?, Direction: (SwipeDirection | {SwipeDirection})?) -> GestureHandle,
	MakeRotatable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?) -> GestureHandle,
	MakeZoomable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Content: GuiObject?, MinZoom: number?, MaxZoom: number?, ZoomStep: number?) -> GestureHandle,
	MakePannable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: PanCallback?, Config: PanConfig?) -> GestureHandle,
	MakeHoverable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: HoverCallback?) -> GestureHandle,
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

function UIGesture:MakeSwipeable(Main, Handle, Callback, Threshold, MaxTime, Direction)
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

	local function MatchesDirection(direction, filter)
		if not filter then
			return true
		end

		if type(filter) == "table" then
			for _, d in filter do
				if d == direction then
					return true
				end
			end
			return false
		end

		return direction == filter
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

						if direction and Callback and MatchesDirection(direction, Direction) then
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

function UIGesture:MakePannable(Main, Handle, Callback, Config)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakePannable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	Config = Config or {}

	local Radius = Config.Radius
	local ReturnToCenter = Config.ReturnToCenter
	local LockAxis = Config.LockAxis
	local Momentum = Config.Momentum
	local Friction = Config.Friction or 4
	local PanButton = Config.PanButton or Enum.UserInputType.MouseButton1
	local MoveMain = if Config.MoveMain == nil then true else Config.MoveMain

	assert(not (type(Radius) == "table" and not LockAxis), "MakePannable: Radius table (Min/Max) requires LockAxis to be set")

	local panning = false
	local ActiveInput, DragInput, DragStart
	local BasePos = Main.Position
	local CurrentOffset, DragStartOffset = Vector2.new(0, 0), Vector2.new(0, 0)
	local LastOffset, LastSampleTime, Velocity = Vector2.new(0, 0), 0, Vector2.new(0, 0)
	local MomentumConn

	local Conn = {}
	local self = {}

	local function ApplyPan(offset)
		if MoveMain then
			Main.Position = UDim2.new(
				BasePos.X.Scale,
				BasePos.X.Offset + offset.X,
				BasePos.Y.Scale,
				BasePos.Y.Offset + offset.Y
			)
		end

		if Callback then
			Callback(offset, offset.Magnitude)
		end
	end

	local function ClampOffset(offset)
		if LockAxis == "X" or LockAxis == "Y" then
			local value = if LockAxis == "X" then offset.X else offset.Y
			local min, max = -math.huge, math.huge

			if type(Radius) == "table" then
				min, max = Radius[1], Radius[2]
			elseif Radius then
				min, max = -Radius, Radius
			end

			value = math.clamp(value, min, max)

			return if LockAxis == "X" then Vector2.new(value, 0) else Vector2.new(0, value)
		end

		if Radius and offset.Magnitude > Radius then
			offset = offset.Unit * Radius
		end

		return offset
	end

	local function StopMomentum()
		if MomentumConn then
			MomentumConn:Disconnect()
			MomentumConn = nil
		end
	end

	local function StartMomentum()
		StopMomentum()

		local velocity = Velocity
		local offset = CurrentOffset

		MomentumConn = RunService.Heartbeat:Connect(function(dt)
			velocity = velocity * math.exp(-Friction * dt)

			if velocity.Magnitude < 1 then
				StopMomentum()

				if ReturnToCenter then
					CurrentOffset = Vector2.new(0, 0)
					ApplyPan(CurrentOffset)
				end

				return
			end

			offset = ClampOffset(offset + velocity * dt)
			CurrentOffset = offset
			ApplyPan(offset)
		end)
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if panning then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == PanButton
			or input.UserInputType == Enum.UserInputType.Touch then
			StopMomentum()

			panning = true
			ActiveInput = input
			DragStart = input.Position
			DragStartOffset = CurrentOffset
			LastOffset = CurrentOffset
			LastSampleTime = os.clock()
			Velocity = Vector2.new(0, 0)

			input.Changed:Connect(function()
				if input ~= ActiveInput then return end

				if input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel then
					panning = false
					ActiveInput = nil
					DragInput = nil

					if Momentum then
						StartMomentum()
					elseif ReturnToCenter then
						CurrentOffset = Vector2.new(0, 0)
						ApplyPan(CurrentOffset)
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
			local offset = ClampOffset(DragStartOffset + Vector2.new(delta.X, delta.Y))

			local now = os.clock()
			local dt = now - LastSampleTime
			if dt > 0 then
				Velocity = (offset - LastOffset) / dt
			end
			LastOffset = offset
			LastSampleTime = now
			CurrentOffset = offset

			ApplyPan(offset)
		end
	end)

	function self:Disconnect()
		panning = false
		ActiveInput = nil
		StopMomentum()
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeHoverable(Main, Handle, Callback)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main and Handle, "MakeHoverable: needs at least one GuiObject")

	if not Handle.Active then
		Handle.Active = true
	end

	local Conn = {}
	local self = {}

	Conn[1] = Handle.MouseEnter:Connect(function()
		if Callback then
			Callback(true)
		end
	end)

	Conn[2] = Handle.MouseLeave:Connect(function()
		if Callback then
			Callback(false)
		end
	end)

	function self:Disconnect()
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

return UIGesture
