local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Camera = workspace.CurrentCamera

export type GestureHandle = {
	Disconnect: (self: GestureHandle) -> (),
}

export type SwipeDirection = "Left" | "Right" | "Up" | "Down"

export type SwipeCallback = (direction: SwipeDirection, distance: number) -> ()

export type PanCallback = (delta: Vector2, magnitude: number) -> ()

export type HoverCallback = (Hovering: boolean) -> ()

export type PanConfig = {
	Radius: (number | Vector2 | {number})?,
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
	MakeZoomable: (self: UIGesture, Main: GuiObject, Handle: GuiObject, MinZoom: number?, MaxZoom: number?, ZoomStep: number?) -> GestureHandle,
	MakePannable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: PanCallback?, Config: PanConfig?) -> GestureHandle,
	MakeHoverable: (self: UIGesture, Main: GuiObject, Handle: GuiObject?, Callback: HoverCallback?) -> GestureHandle,
}

local UIGesture = {} :: UIGesture

local InputChangedListeners = {}
local InputEndedListeners = {}

UserInputService.InputChanged:Connect(function(input)
	for listener in pairs(InputChangedListeners) do
		listener(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	for listener in pairs(InputEndedListeners) do
		listener(input)
	end
end)

function UIGesture:MakeDraggable(Main, Handle)
	Main = Main or Handle
	Handle = Handle or Main
	assert(Main, "MakeDraggable: needs at least one GuiObject")

	Handle.Active = true

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
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	local function OnDragInputChanged(input)
		if dragging and input == DragInput then

			local delta = input.Position - DragStart
			local desiredAbsX = StartAbsPos.X + delta.X
			local desiredAbsY = StartAbsPos.Y + delta.Y

			local viewportSize = Camera.ViewportSize

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
	end

	local function OnDragInputEnded(input)
		if input == ActiveInput then
			dragging = false
			ActiveInput = nil
			DragInput = nil
		end
	end

	InputChangedListeners[OnDragInputChanged] = true
	InputEndedListeners[OnDragInputEnded] = true

	Conn[3] = { Disconnect = function()
		InputChangedListeners[OnDragInputChanged] = nil
	end }

	Conn[4] = { Disconnect = function()
		InputEndedListeners[OnDragInputEnded] = nil
	end }

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
	assert(Main, "MakeResizeable: needs at least one GuiObject")

	Handle.Active = true

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
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	local function OnResizeInputChanged(input)
		if resizing and input == DragInput then

			local delta = input.Position - DragStart
			local desiredAbsWidth = StartAbsSize.X + delta.X
			local desiredAbsHeight = StartAbsSize.Y + delta.Y

			local viewportSize = Camera.ViewportSize

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
	end

	local function OnResizeInputEnded(input)
		if input == ActiveInput then
			resizing = false
			ActiveInput = nil
			DragInput = nil
		end
	end

	InputChangedListeners[OnResizeInputChanged] = true
	InputEndedListeners[OnResizeInputEnded] = true

	Conn[3] = { Disconnect = function()
		InputChangedListeners[OnResizeInputChanged] = nil
	end }

	Conn[4] = { Disconnect = function()
		InputEndedListeners[OnResizeInputEnded] = nil
	end }

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
	assert(Main, "MakeSwipeable: needs at least one GuiObject")

	Handle.Active = true

	Threshold = Threshold or 50
	MaxTime = MaxTime or 0.5

	local swiping = false
	local ActiveInput, StartPos, StartTime

	local Conn = {}
	local self = {}

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if swiping then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			swiping = true
			ActiveInput = input
			StartPos = input.Position
			StartTime = os.clock()
		end
	end)

	local function OnSwipeInputEnded(input)
		if input ~= ActiveInput then return end

		swiping = false
		ActiveInput = nil

		local elapsed = os.clock() - StartTime
		if elapsed <= MaxTime then
			local delta = input.Position - StartPos

			if delta.Magnitude >= Threshold then
				local direction
				if math.abs(delta.X) > math.abs(delta.Y) then
					direction = delta.X > 0 and "Right" or "Left"
				else
					direction = delta.Y > 0 and "Down" or "Up"
				end

				local matches = true
				if Direction then
					if type(Direction) == "table" then
						matches = false
						for _, d in Direction do
							if d == direction then
								matches = true
								break
							end
						end
					else
						matches = direction == Direction
					end
				end

				if Callback and matches then
					Callback(direction, delta.Magnitude)
				end
			end
		end
	end

	InputEndedListeners[OnSwipeInputEnded] = true

	Conn[2] = { Disconnect = function()
		InputEndedListeners[OnSwipeInputEnded] = nil
	end }

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
	assert(Main, "MakeRotatable: needs at least one GuiObject")

	Handle.Active = true

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
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	local function OnRotateInputChanged(input)
		if rotating and input == DragInput then
			local currentAngle = GetAngle(input.Position)
			Main.Rotation = StartRotation + (currentAngle - StartAngle)
		end
	end

	local function OnRotateInputEnded(input)
		if input == ActiveInput then
			rotating = false
			ActiveInput = nil
			DragInput = nil
		end
	end

	InputChangedListeners[OnRotateInputChanged] = true
	InputEndedListeners[OnRotateInputEnded] = true

	Conn[3] = { Disconnect = function()
		InputChangedListeners[OnRotateInputChanged] = nil
	end }

	Conn[4] = { Disconnect = function()
		InputEndedListeners[OnRotateInputEnded] = nil
	end }

	function self:Disconnect()
		rotating = false
		ActiveInput = nil
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

function UIGesture:MakeZoomable(Main, Handle, MinZoom, MaxZoom, ZoomStep)
	assert(Main, "MakeZoomable: needs a GuiObject to scale")
	assert(Handle, "MakeZoomable: needs a Handle GuiObject")

	Handle.Active = true

	MinZoom = MinZoom or 0.3
	MaxZoom = MaxZoom or 1
	ZoomStep = ZoomStep or 0.1

	local ContentScale = Main:FindFirstChildOfClass("UIScale")
	if not ContentScale then
		ContentScale = Main.Parent:FindFirstChildOfClass("UIScale")
	end
	if not ContentScale then
		ContentScale = Instance.new("UIScale")
		ContentScale.Parent = Main
	end

	local function GetFitScale()
		local currentScale = ContentScale.Scale
		if currentScale <= 0 then
			currentScale = 1
		end

		local baseContentSize = Main.AbsoluteSize / currentScale
		if baseContentSize.X <= 0 or baseContentSize.Y <= 0 then
			return 1
		end

		return math.min(
			Handle.AbsoluteSize.X / baseContentSize.X,
			Handle.AbsoluteSize.Y / baseContentSize.Y
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

		local anchorScreen = Handle.AbsolutePosition + Handle.AbsoluteSize / 2
		local newAbsSize = baseAbsSize * (clampedScale / baseScale)

		local fractionX = (anchorScreen.X - baseAbsPos.X) / baseAbsSize.X
		local fractionY = (anchorScreen.Y - baseAbsPos.Y) / baseAbsSize.Y

		local desiredAbsX = anchorScreen.X - fractionX * newAbsSize.X
		local desiredAbsY = anchorScreen.Y - fractionY * newAbsSize.Y

		local anchor = Main.AnchorPoint
		local sizeDelta = newAbsSize - baseAbsSize

		Main.Position = UDim2.new(
			basePos.X.Scale,
			basePos.X.Offset + (desiredAbsX - baseAbsPos.X) + anchor.X * sizeDelta.X,
			basePos.Y.Scale,
			basePos.Y.Offset + (desiredAbsY - baseAbsPos.Y) + anchor.Y * sizeDelta.Y
		)

		ContentScale.Scale = clampedScale
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

		if TouchA and TouchB then
			pinching = true
			StartDistance = (TouchA.Position - TouchB.Position).Magnitude
			StartScale = ContentScale.Scale
			StartAbsSize = Main.AbsoluteSize
			StartPos = Main.Position
			StartAbsPos = Main.AbsolutePosition
		end
	end)

	local function OnZoomInputEnded(input)
		if input == TouchA then
			TouchA = nil
			pinching = false
		elseif input == TouchB then
			TouchB = nil
			pinching = false
		end
	end

	local function OnZoomInputChanged(input)
		if not pinching then return end
		if input ~= TouchA and input ~= TouchB then return end

		local currentDistance = (TouchA.Position - TouchB.Position).Magnitude
		local factor = currentDistance / StartDistance

		ApplyZoom(factor, StartScale, StartAbsSize, StartPos, StartAbsPos)
	end

	InputEndedListeners[OnZoomInputEnded] = true
	InputChangedListeners[OnZoomInputChanged] = true

	Conn[2] = { Disconnect = function()
		InputEndedListeners[OnZoomInputEnded] = nil
	end }

	Conn[3] = { Disconnect = function()
		InputChangedListeners[OnZoomInputChanged] = nil
	end }

	Conn[4] = Handle.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end

		local direction = input.Position.Z
		local factor = 1 + (direction * ZoomStep)

		ApplyZoom(factor, ContentScale.Scale, Main.AbsoluteSize, Main.Position, Main.AbsolutePosition)
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
	assert(Main, "MakePannable: needs at least one GuiObject")

	Handle.Active = true

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
		local ContentScale = Main:FindFirstChildOfClass("UIScale")
		if not ContentScale then
			ContentScale = Main.Parent:FindFirstChildOfClass("UIScale")
		end
		local scale = if ContentScale then ContentScale.Scale else 1

		if LockAxis == "X" or LockAxis == "Y" then
			local value = if LockAxis == "X" then offset.X else offset.Y
			local min, max = -math.huge, math.huge

			if type(Radius) == "table" then
				min, max = Radius[1] * scale, Radius[2] * scale
			elseif Radius then
				min, max = -Radius * scale, Radius * scale
			end

			value = math.clamp(value, min, max)

			return if LockAxis == "X" then Vector2.new(value, 0) else Vector2.new(0, value)
		end

		if typeof(Radius) == "Vector2" then
			return Vector2.new(
				math.clamp(offset.X, -Radius.X * scale, Radius.X * scale),
				math.clamp(offset.Y, -Radius.Y * scale, Radius.Y * scale)
			)
		end

		if Radius and offset.Magnitude > Radius * scale then
			offset = offset.Unit * (Radius * scale)
		end

		return offset
	end

	local function StopMomentum()
		if MomentumConn then
			MomentumConn:Disconnect()
			MomentumConn = nil
		end
	end

	Conn[1] = Handle.InputBegan:Connect(function(input)
		if panning then
			if input.UserInputType == Enum.UserInputType.Touch and ActiveInput.UserInputType == Enum.UserInputType.Touch then
				panning = false
				ActiveInput = nil
				DragInput = nil
			end
			return
		end
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
		end
	end)

	Conn[2] = Handle.InputChanged:Connect(function(input)
		if input == ActiveInput
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			DragInput = input
		end
	end)

	local function OnPanInputChanged(input)
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
	end

	local function OnPanInputEnded(input)
		if input ~= ActiveInput then return end

		panning = false
		ActiveInput = nil
		DragInput = nil

		if Momentum then
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
		elseif ReturnToCenter then
			CurrentOffset = Vector2.new(0, 0)
			ApplyPan(CurrentOffset)
		end
	end

	InputChangedListeners[OnPanInputChanged] = true
	InputEndedListeners[OnPanInputEnded] = true

	Conn[3] = { Disconnect = function()
		InputChangedListeners[OnPanInputChanged] = nil
	end }

	Conn[4] = { Disconnect = function()
		InputEndedListeners[OnPanInputEnded] = nil
	end }

	Conn[5] = Main:GetPropertyChangedSignal("Position"):Connect(function()
		BasePos = UDim2.new(
			Main.Position.X.Scale,
			Main.Position.X.Offset - CurrentOffset.X,
			Main.Position.Y.Scale,
			Main.Position.Y.Offset - CurrentOffset.Y
		)
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
	assert(Main, "MakeHoverable: needs at least one GuiObject")
	assert(Callback, "MakeHoverable: needs a Callback")

	Handle.Active = true

	local Conn = {}
	local self = {}

	Conn[1] = Handle.MouseEnter:Connect(function()
		Callback(true)
	end)

	Conn[2] = Handle.MouseLeave:Connect(function()
		Callback(false)
	end)

	function self:Disconnect()
		for _, c in Conn do
			c:Disconnect()
		end
	end

	return self
end

return UIGesture
