local uis = game:GetService("UserInputService")
local master = script:FindFirstAncestor("mixer")
local knob = master.LEDS["BEATFX FX SELECTION KNOB"]
local gui = knob.Screen

local knobControl = master:WaitForChild("KnobControl")

local angles = {-145, -125, -99, -77, -55, -33, -11, 12, 33, 56, 80, 103, 124, 148}
local range = .5

local angleCount = #angles
local angleIndex = angleCount
local dragging = false

local mouseY = nil
local dragStartY = nil
local dragStartIndex = angleIndex

local function onMouseMove(input: InputObject)
	local y = input.Position.Y
	mouseY = y

	if not dragging then return end
	local startY = dragStartY
	if not startY then dragStartY = y; return end

	local steps = (startY - y) / angleCount / range
	angleIndex = math.clamp(dragStartIndex + math.round(steps), 1, angleCount)
	knob.CFrame = CFrame.new(knob.Position) * CFrame.Angles(0, math.rad(angles[angleIndex]), 0)
end

uis.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		onMouseMove(input)
	end
end)

gui.Frame.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStartY = mouseY
		dragStartIndex = angleIndex

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