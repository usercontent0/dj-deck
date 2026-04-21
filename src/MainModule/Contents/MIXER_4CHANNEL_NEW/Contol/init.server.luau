math.randomseed(os.time())
local runService = game:GetService("RunService")

local Master = script.Parent
local DECK = Master.Parent

local Body = script.Parent.Body
local LEDS = script.Parent.LEDS
local INDICATORS = LEDS["VOLUME INDICATORS"]

local volumeMeter = script.Parent:WaitForChild("VolumeMeter")
local faderStatus = script.Parent:WaitForChild("FaderStatus")
local knobControl = script.Parent:WaitForChild("KnobControl")
local faderControl = script.Parent:WaitForChild("FaderControl")

local updateFps = 1/20
local updateCounter = 0
local peakHoldTime = 2
local pDecayRate, pExpFactor = 5, 1
local vuSize, maxSize = 15, 100

local USBColor = DECK:GetAttribute("USBColor")

local LEVELTABS = {["CHANNEL1"] = {}, ["CHANNEL2"] = {}, ["CHANNEL3"] = {}, ["CHANNEL4"] = {}, ["MASTER1"] = {}, ["MASTER2"] = {}}
local LEVELS = {0, 0, 0, 0}
local channelActive = {false, false, false, false}
local peakLevels = {0, 0, 0, 0, 0, 0}
local peakTimers = {0, 0, 0, 0, 0, 0}
local masterDiv = {0, 0}

local CHANNELS = {
	["CHANNEL1"] = INDICATORS["CHANNEL 1"],
	["CHANNEL2"] = INDICATORS["CHANNEL 2"],
	["CHANNEL3"] = INDICATORS["CHANNEL 3"],
	["CHANNEL4"] = INDICATORS["CHANNEL 4"],
	["MASTER1"] = INDICATORS["MASTER L"],
	["MASTER2"] = INDICATORS["MASTER R"]
}

local function mapNumber(l, inMin, inMax, outMin, outMax)
	if (inMax - inMin + outMin == 0) then return 0 end	
	return ((l - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin
end

local function getRandomAudioPeak(minDb, maxDb)
	local db = minDb + math.random() * (maxDb - minDb)
	return math.floor(100 * 10^(db / 20))
end

local function fillLevelTabs(t)
	for _,channel in t do
		for vuIndex = 1, vuSize do
			table.insert(LEVELTABS[channel], mapNumber(vuIndex, 1, vuSize, 0, maxSize))
		end
	end
end

fillLevelTabs({"CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4"})
fillLevelTabs({"MASTER1", "MASTER2"})

for _,channel in CHANNELS do
	for _,led in channel.LEDS:GetChildren() do if led:IsA("Frame") then led.Visible = true end end
end

runService.Heartbeat:Connect(function(deltaTime)
    for index = 1, 6 do peakTimers[index] += deltaTime end
    updateCounter += deltaTime

    if updateCounter >= updateFps then
        updateCounter -= updateFps

        local RANDOMS = {}
        for index = 1, 4 do RANDOMS[index] = channelActive[index] and getRandomAudioPeak(-6, -1) or 0 end

        for channel = 1, 4 do
            local newLevel = RANDOMS[channel]

            peakTimers[channel] += updateFps
            if (peakTimers[channel] >= peakHoldTime) or (newLevel > peakLevels[channel]) then
                peakLevels[channel], peakTimers[channel] = newLevel, 0
            end

            if newLevel <= 5 then
                local currentDecay = pDecayRate * (peakLevels[channel] ^ pExpFactor)
                peakLevels[channel] = math.max(peakLevels[channel] - (currentDecay * deltaTime), 0)
            end

            local peakIndex = math.floor(mapNumber(peakLevels[channel], 0, maxSize, 1, vuSize))
            for vuIndex = 1, vuSize do
                CHANNELS["CHANNEL"..channel].LEDS[vuIndex].BackgroundTransparency =
                    (LEVELTABS["CHANNEL"..channel][vuIndex] < newLevel
                    or (peakIndex > 1 and vuIndex == peakIndex)) and 0 or 1

                LEVELS[channel] = channelActive[channel] and newLevel or 0
            end
        end

        for channel = 1, 2 do
			local newLevel = (LEVELS[1] + LEVELS[2] + LEVELS[3] + LEVELS[4]) / masterDiv[channel]
			local masterIndex = channel + 4

			peakTimers[masterIndex] += updateFps
			if (peakTimers[masterIndex] >= peakHoldTime) or (newLevel > peakLevels[masterIndex]) then
				peakLevels[masterIndex], peakTimers[masterIndex] = newLevel, 0					
			end

			if newLevel <= 5 then
				local currentDecay = pDecayRate * (peakLevels[masterIndex] ^ pExpFactor)
				peakLevels[masterIndex] = math.max(peakLevels[masterIndex] - (currentDecay * deltaTime), 0)
			end

			local peakIndex = math.floor(mapNumber(peakLevels[masterIndex], 0, maxSize, 1, vuSize))
			for vuIndex = 1, vuSize do
				CHANNELS["MASTER"..channel].LEDS[vuIndex].BackgroundTransparency = 
                    (LEVELTABS["MASTER"..channel][vuIndex] < newLevel
                    or (peakIndex > 1 and vuIndex == peakIndex)) and 0 or 1
			end
		end
    end
end)

volumeMeter.Event:Connect(function(channelNumber: number, isVisible: boolean) channelActive[channelNumber] = isVisible end)

task.spawn(function()
	while task.wait(.5) do
		for index = 1, #masterDiv do
			masterDiv[index] = math.random(20, 30) / 10
		end
	end
end)

local blueOnColor = Color3.fromRGB(27, 99, 175)
local blueOffColor = Color3.fromRGB(41, 72, 100)

local cueOnColor = Color3.fromRGB(160, 116, 58)
local cueOffColor = Color3.fromRGB(100, 86, 69)

local beatFxLoop = nil
local beatFxDeb = false

local beatFxButton = LEDS["BEAT FX CHANNEL 1"]
local colorFxButton = nil
local micFxButton = nil

local whitelistedButtons = {
	["COLOR FX SPACE"] = true,
	["COLOR FX DUB ECHO"] = true,
	["COLOR FX SWEEP"] = true,
	["COLOR FX NOISE"] = true,
	["COLOR FX CRUSH"] = true,
	["COLOR FX FILTER"] = true,
}
local whitelistedBeatFxIndicators = {
	["BEAT FX 1"] = true,
	["BEAT FX 2"] = true,
	["BEAT FX 3"] = true,
	["BEAT FX 4"] = true,
	["BEAT FX MIC"] = true,
	["BEAT FX CF A"] = true,
	["BEAT FX CF B"] = true,
	["BEAT FX MST"] = true,
}
local whitelistedMicFxButtons = {
	["MIC FX ECHO"] = true,
	["MIC FX PITCH"] = true,
	["MIC FX MEGAPHONE"] = true,
}

local CDJs = {}
for _,model in DECK:GetChildren() do
	if model.Name:lower():find("cdj") then table.insert(CDJs, model) end
end
	
for _,CDJ in CDJs do
	if CDJ:GetAttribute("HasUSB") and not CDJ:GetAttribute("IsNewGeneration") then
		CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(43, 89, 130)
		CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.Neon
	end
	if CDJ:GetAttribute("IsNewGeneration") then
		CDJ.LEDS["TOP LED"].Color = USBColor
		CDJ.LEDS["SCREEN"].Screen.Background.Changable.SongInfo.SourceColor.BackgroundColor3 = USBColor
		CDJ.LEDS["SD CARD LED"].Color = Color3.fromRGB(120, 120, 120)
		CDJ.LEDS["SD CARD LED"].Material = Enum.Material.Neon

		if not CDJ:GetAttribute("HasUSB") then
			CDJ.LEDS["USB LED"].Color = Color3.fromRGB(120, 120, 120)
			CDJ.LEDS["USB LED"].Material = Enum.Material.Neon
		end
	end
end

local function disableAllBeatFxIndicators()
	for _,button in LEDS:GetChildren() do
		if button.Name:find("BEAT FX") and not whitelistedBeatFxIndicators[button.Name] and button.Name ~= "BEAT FX INDICATOR" then
			button.Color = Color3.fromRGB(100, 100, 100)
			button.Material = Enum.Material.SmoothPlastic
		end
	end
end
local function disableAllBeatFxButtons()
	for _,button in LEDS:GetChildren() do
		if button.Name:find("BEAT FX") and whitelistedBeatFxIndicators[button.Name] and button.Name ~= "BEAT FX INDICATOR" then
			button.Color = blueOffColor
		end
	end
end
local function disableAllMicFxButtons()
	for _,button in LEDS:GetChildren() do
		if button.Name:find("MIC FX") and whitelistedMicFxButtons[button.Name] then
			button.Color = blueOffColor
		end
	end
end
local function enableAllColorFxButtons(fromButton: string)
	for _,button in LEDS:GetChildren() do
		if button.Name ~= fromButton and whitelistedButtons[button.Name] then
			button.Color = Color3.fromRGB(150, 150, 165)
		end
	end
end

LEDS["BEAT FX 1"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX 1"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX CHANNEL 1"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)
LEDS["BEAT FX 2"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX 2"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX CHANNEL 2"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)
LEDS["BEAT FX 3"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX 3"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX CHANNEL 3"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)
LEDS["BEAT FX 4"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX 4"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX CHANNEL 4"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)
LEDS["BEAT FX MST"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX MST"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX MASTER"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)
LEDS["BEAT FX MIC"].ClickDetector.MouseClick:Connect(function()
    disableAllBeatFxIndicators(); disableAllBeatFxButtons()
	LEDS["BEAT FX MIC"].Color = blueOnColor
	beatFxButton = LEDS["BEAT FX MIC INDICATOR"]
	beatFxButton.Material = Enum.Material.Neon
	beatFxButton.Color = blueOnColor
end)

task.spawn(function()
	while true do
		if beatFxDeb then
			LEDS["BEAT FX INDICATOR"].Material = Enum.Material.SmoothPlastic
			LEDS["BEAT FX INDICATOR"].Color = Color3.fromRGB(100, 100, 100)
			beatFxButton.Color = Color3.fromRGB(100, 100, 100)
			beatFxButton.Material = Enum.Material.SmoothPlastic
		end
		if colorFxButton then colorFxButton.Color = Color3.fromRGB(85, 85, 85) end

		task.wait(.24)

		if beatFxDeb then
			LEDS["BEAT FX INDICATOR"].Material = Enum.Material.Neon
			LEDS["BEAT FX INDICATOR"].Color = blueOnColor
			beatFxButton.Color = blueOnColor
			beatFxButton.Material = Enum.Material.Neon
		end
		if colorFxButton then colorFxButton.Color = Color3.fromRGB(150, 150, 165) end

		task.wait(.24)
	end
end)

LEDS["BEAT FX INDICATOR"].ClickDetector.MouseClick:Connect(function()
	beatFxDeb = not beatFxDeb
	if not beatFxDeb then
		LEDS["BEAT FX INDICATOR"].Material = Enum.Material.Neon
		LEDS["BEAT FX INDICATOR"].Color = blueOnColor
		beatFxButton.Color = blueOnColor
		beatFxButton.Material = Enum.Material.Neon
	end
end)

for _,cueType in {"A", "B"} do
    LEDS[`CUE {cueType} CHANNEL 1`].ClickDetector.MouseClick:Connect(function()
        if LEDS[`CUE {cueType} CHANNEL 1`].Color == cueOffColor then
            LEDS[`CUE {cueType} CHANNEL 1`].Color = cueOnColor
        else
            LEDS[`CUE {cueType} CHANNEL 1`].Color = cueOffColor
        end
    end)
    LEDS[`CUE {cueType} CHANNEL 2`].ClickDetector.MouseClick:Connect(function()
        if LEDS[`CUE {cueType} CHANNEL 2`].Color == cueOffColor then
            LEDS[`CUE {cueType} CHANNEL 2`].Color = cueOnColor
        else
            LEDS[`CUE {cueType} CHANNEL 2`].Color = cueOffColor
        end
    end)
    LEDS[`CUE {cueType} CHANNEL 3`].ClickDetector.MouseClick:Connect(function()
        if LEDS[`CUE {cueType} CHANNEL 3`].Color == cueOffColor then
            LEDS[`CUE {cueType} CHANNEL 3`].Color = cueOnColor
        else
            LEDS[`CUE {cueType} CHANNEL 3`].Color = cueOffColor
        end
    end)
    LEDS[`CUE {cueType} CHANNEL 4`].ClickDetector.MouseClick:Connect(function()
        if LEDS[`CUE {cueType} CHANNEL 4`].Color == cueOffColor then
            LEDS[`CUE {cueType} CHANNEL 4`].Color = cueOnColor
        else
            LEDS[`CUE {cueType} CHANNEL 4`].Color = cueOffColor
        end
    end)
    LEDS[`CUE {cueType} MASTER`].ClickDetector.MouseClick:Connect(function()
        if LEDS[`CUE {cueType} MASTER`].Color == cueOffColor then
            LEDS[`CUE {cueType} MASTER`].Color = cueOnColor
        else
            LEDS[`CUE {cueType} MASTER`].Color = cueOffColor
        end
    end)
end

LEDS["LOW"].ClickDetector.MouseClick:Connect(function()
    if LEDS["LOW"].Color == blueOffColor then
        LEDS["LOW"].Color = blueOnColor
    else
        LEDS["LOW"].Color = blueOffColor
    end
end)
LEDS["MID"].ClickDetector.MouseClick:Connect(function()
    if LEDS["MID"].Color == blueOffColor then
        LEDS["MID"].Color = blueOnColor
    else
        LEDS["MID"].Color = blueOffColor
    end
end)
 LEDS["HI"].ClickDetector.MouseClick:Connect(function()
    if LEDS["HI"].Color == blueOffColor then
        LEDS["HI"].Color = blueOnColor
    else
        LEDS["HI"].Color = blueOffColor
    end
end)

for micFxName,_ in whitelistedMicFxButtons do
    LEDS[micFxName].ClickDetector.MouseClick:Connect(function()
        if micFxButton == LEDS[micFxName] then
            micFxButton.Color = blueOffColor
            micFxButton = nil
        else
            disableAllMicFxButtons()
            micFxButton = LEDS[micFxName]
            micFxButton.Color = blueOnColor
        end
    end)
end

LEDS["MIC REVERB"].ClickDetector.MouseClick:Connect(function()
    if LEDS["MIC REVERB"].Color == blueOffColor then
        LEDS["MIC REVERB"].Color = blueOnColor
    else
        LEDS["MIC REVERB"].Color = blueOffColor
    end
end)

LEDS[`HEADPHONES A LINK CUE`].ClickDetector.MouseClick:Connect(function()
    if LEDS[`HEADPHONES A LINK CUE`].Color == cueOffColor then
        LEDS[`HEADPHONES A LINK CUE`].Color = cueOnColor
    else
        LEDS[`HEADPHONES A LINK CUE`].Color = cueOffColor
    end
end)
LEDS[`HEADPHONES A MONO SPLIT`].ClickDetector.MouseClick:Connect(function()
    if LEDS[`HEADPHONES A MONO SPLIT`].Color == cueOffColor then
        LEDS[`HEADPHONES A MONO SPLIT`].Color = cueOnColor
    else
        LEDS[`HEADPHONES A MONO SPLIT`].Color = cueOffColor
    end
end)
LEDS[`HEADPHONES B LINK CUE`].ClickDetector.MouseClick:Connect(function()
    if LEDS[`HEADPHONES B LINK CUE`].Color == cueOffColor then
        LEDS[`HEADPHONES B LINK CUE`].Color = cueOnColor
    else
        LEDS[`HEADPHONES B LINK CUE`].Color = cueOffColor
    end
end)
LEDS[`HEADPHONES B MONO SPLIT`].ClickDetector.MouseClick:Connect(function()
    if LEDS[`HEADPHONES B MONO SPLIT`].Color == cueOffColor then
        LEDS[`HEADPHONES B MONO SPLIT`].Color = cueOnColor
    else
        LEDS[`HEADPHONES B MONO SPLIT`].Color = cueOffColor
    end
end)

for colorFx,_ in whitelistedButtons do
	LEDS[colorFx].ClickDetector.MouseClick:Connect(function()
		if colorFxButton == LEDS[colorFx] then
			local saved = colorFxButton
			colorFxButton = nil
			saved.Color = Color3.fromRGB(150, 150, 165)
		else
			colorFxButton = LEDS[colorFx]
			enableAllColorFxButtons(colorFxButton.Name)
		end
	end)
end

faderControl.Event:Connect(function(fType: string, args: {dragPosition: number, range: number})
	local faderValue = (args.dragPosition / args.range+1) / 2
	local deckNumber = tonumber(string.match(fType, "%d+"))

	faderStatus:Fire(deckNumber-1, (1-faderValue) * 1000)
end)

local FXLabels = {[1]="DELAY",[2]="ECHO",[3]="PING PONG",[4]="SPIRAL",[5]="HELIX",[6]="REVERB",[7]="FLANGER",[8]="PHASER",[9]="FILTER",[10]="TRIPLET FILTER",[11]="TRANS",[12]="ROLL",[13]="TRIPLET ROLL",[14]="MOBIUS"}

knobControl.OnServerEvent:Connect(function(fromPlayer: Player, data: {index: number, knobType: number})
	if data.knobType == 1 then
		local gui = LEDS["TOPSCREEN"].Screen.Background
		gui.CurrentFX.Text = FXLabels[data.index]
	end
end)

task.spawn(function()
	while true do
		for _,CDJ in CDJs do
			if CDJ:GetAttribute("HasUSB") then
				CDJ.LEDS["USB LED"].Color = CDJ:GetAttribute("IsNewGeneration") and USBColor or Color3.fromRGB(160, 160, 160)
				CDJ.LEDS["USB LED"].Material = Enum.Material.Neon
				if not CDJ:GetAttribute("IsNewGeneration") then
					CDJ.LEDS["USB BUTTON"].Color = Color3.fromRGB(143, 170, 70)
					CDJ.LEDS["USB BUTTON"].Material = Enum.Material.Neon
				end
			end
		end
		task.wait(.5)
		for _,CDJ in CDJs do
			if CDJ:GetAttribute("HasUSB") then
				CDJ.LEDS["USB LED"].Color = Color3.fromRGB(100, 100, 100)
				CDJ.LEDS["USB LED"].Material = Enum.Material.SmoothPlastic
				if not CDJ:GetAttribute("IsNewGeneration") then
					CDJ.LEDS["USB BUTTON"].Color = Color3.fromRGB(100, 100, 100)
					CDJ.LEDS["USB BUTTON"].Material = Enum.Material.SmoothPlastic
				end
			end
		end
		task.wait(.5)
	end
end)

task.spawn(function()
	while true do
		for _,CDJ in CDJs do
			if not CDJ:GetAttribute("HasUSB") and not CDJ:GetAttribute("IsNewGeneration") then
				CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(57, 115, 170)
				CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.Neon
			end
		end
		task.wait(.5)
		for _,CDJ in CDJs do
			if not CDJ:GetAttribute("HasUSB") and not CDJ:GetAttribute("IsNewGeneration") then
				CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(100, 100, 100)
				CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.SmoothPlastic
			end
		end
		task.wait(.5)
	end
end)

local headphones = script.DJHeadphones
script.Parent.Headphones.ClickDetector.MouseClick:Connect(function(player: Player)
	local character = player.Character
	if character:FindFirstChild(headphones.Name) then
		character[headphones.Name]:Destroy()
	else
		local clone = headphones:Clone()
		clone.Handle.Anchored = false
		character.Humanoid:AddAccessory(clone)
	end
end)

print(`mixer init (newgen)`)