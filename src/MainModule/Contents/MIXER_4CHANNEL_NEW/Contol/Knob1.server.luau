local uis = game:GetService("UserInputService")
local master = script:FindFirstAncestor("mixer")
local knob = master.LEDS["BEATFX FX SELECTION KNOB"]
local gui = knob.Screen

local knobControl = master:WaitForChild("KnobControl")
local camera = workspace.CurrentCamera

local angles = {-145, -125, -99, -77, -55, -33, -11, 12, 33, 56, 80, 103, 124, 148}
local angleIndex = 1
local range = .5
local currentAngle = 1

local angleCount = #angles
local dragging = false

local function onMouseMove(input: InputObject)
	local knobPosition = camera:WorldToScreenPoint(knob.CFrame.Position)
	local distance = (knobPosition.Y - input.Position.Y) / angleCount
	
	angleIndex = math.clamp(math.floor(distance / range) + angleCount, 1, angleCount)
	knob.CFrame = CFrame.new(knob.Position) * CFrame.Angles(0, math.rad(angles[math.clamp(angleIndex, 1, angleCount)]), 0)
end

uis.InputChanged:Connect(function(input: InputObject)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		onMouseMove(input)
	end
end)

gui.Frame.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				knobControl:FireServer({
					index = angleCount - math.clamp(angleIndex, 1, angleCount) + 1,
					knobType = 1
				})
			end
		end)
	end
end)

gui.Frame.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		currentAngle = angleIndex
	end
end)
