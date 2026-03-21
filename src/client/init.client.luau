local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local AUTO_RUN_SPEED = 26
local SIDE_MOVE_SPEED = 16
local SIDE_INPUT_SCALE = SIDE_MOVE_SPEED / AUTO_RUN_SPEED
local JUMP_POWER = 60
local CAMERA_DISTANCE = 14
local CAMERA_HEIGHT = 6
local CAMERA_LOOK_AHEAD = 30
local CAMERA_FOV = 78
local CAMERA_SHAKE_DURATION = 0.45
local CAMERA_SHAKE_MAGNITUDE = 0.42
local GAME_OVER_DELAY = 1.0
local CRASH_COOLDOWN = 1.2
local OBSTACLE_NAME = "Obstacle"

local player = localPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local forwardDir = Vector3.new(0, 0, -1)
local rightDir = Vector3.new(1, 0, 0)
local leftHeld = false
local rightHeld = false
local scoreStartDistance = 0
local currentScore = 0
local isCrashed = false
local isGameOver = false
local shakeTimeLeft = 0
local hitLockUntil = 0
local bodyConnections = {}

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = Instance.new("ScreenGui")
gameGui.Name = "RunHud"
gameGui.ResetOnSpawn = false
gameGui.IgnoreGuiInset = true
gameGui.Parent = playerGui

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreLabel"
scoreLabel.AnchorPoint = Vector2.new(0, 0)
scoreLabel.Position = UDim2.fromOffset(24, 18)
scoreLabel.Size = UDim2.fromOffset(260, 44)
scoreLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
scoreLabel.BackgroundTransparency = 0.2
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextStrokeTransparency = 0.7
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 24
scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
scoreLabel.Text = "Score: 0"
scoreLabel.Parent = gameGui

local gameOverFrame = Instance.new("Frame")
gameOverFrame.Name = "GameOver"
gameOverFrame.AnchorPoint = Vector2.new(0.5, 0.5)
gameOverFrame.Position = UDim2.fromScale(0.5, 0.5)
gameOverFrame.Size = UDim2.fromOffset(360, 220)
gameOverFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
gameOverFrame.BackgroundTransparency = 0.12
gameOverFrame.Visible = false
gameOverFrame.Parent = gameGui

local gameOverTitle = Instance.new("TextLabel")
gameOverTitle.Name = "Title"
gameOverTitle.BackgroundTransparency = 1
gameOverTitle.Position = UDim2.fromOffset(20, 16)
gameOverTitle.Size = UDim2.fromOffset(320, 44)
gameOverTitle.Font = Enum.Font.GothamBlack
gameOverTitle.TextSize = 34
gameOverTitle.TextColor3 = Color3.fromRGB(255, 108, 91)
gameOverTitle.Text = "GAME OVER"
gameOverTitle.Parent = gameOverFrame

local gameOverScore = Instance.new("TextLabel")
gameOverScore.Name = "Score"
gameOverScore.BackgroundTransparency = 1
gameOverScore.Position = UDim2.fromOffset(20, 62)
gameOverScore.Size = UDim2.fromOffset(320, 30)
gameOverScore.Font = Enum.Font.GothamSemibold
gameOverScore.TextSize = 24
gameOverScore.TextColor3 = Color3.fromRGB(238, 238, 238)
gameOverScore.Text = "Score: 0"
gameOverScore.Parent = gameOverFrame

local buttonContinue = Instance.new("TextButton")
buttonContinue.Name = "Continue"
buttonContinue.Position = UDim2.fromOffset(20, 126)
buttonContinue.Size = UDim2.fromOffset(150, 56)
buttonContinue.BackgroundColor3 = Color3.fromRGB(34, 148, 99)
buttonContinue.Font = Enum.Font.GothamBold
buttonContinue.TextSize = 22
buttonContinue.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonContinue.Text = "Continue"
buttonContinue.Parent = gameOverFrame

local buttonRetry = Instance.new("TextButton")
buttonRetry.Name = "Retry"
buttonRetry.Position = UDim2.fromOffset(190, 126)
buttonRetry.Size = UDim2.fromOffset(150, 56)
buttonRetry.BackgroundColor3 = Color3.fromRGB(53, 88, 189)
buttonRetry.Font = Enum.Font.GothamBold
buttonRetry.TextSize = 22
buttonRetry.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonRetry.Text = "Retry"
buttonRetry.Parent = gameOverFrame

local function updateScoreLabel()
	scoreLabel.Text = string.format("Score: %d", currentScore)
end

local function syncScoreFromDistance()
	local distance = rootPart.Position:Dot(forwardDir)
	currentScore = math.max(0, math.floor(distance - scoreStartDistance))
	updateScoreLabel()
end

local function resetRunState(resetScore: boolean)
	isCrashed = false
	isGameOver = false
	shakeTimeLeft = 0
	hitLockUntil = time() + CRASH_COOLDOWN
	humanoid.PlatformStand = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = AUTO_RUN_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = JUMP_POWER
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	if resetScore then
		scoreStartDistance = rootPart.Position:Dot(forwardDir)
		currentScore = 0
		updateScoreLabel()
	else
		scoreStartDistance = rootPart.Position:Dot(forwardDir) - currentScore
	end

	gameOverFrame.Visible = false
end

local function showGameOver()
	if not isCrashed then
		return
	end

	isGameOver = true
	gameOverScore.Text = string.format("Score: %d", currentScore)
	gameOverFrame.Visible = true
end

local function triggerCrash()
	if isCrashed or isGameOver then
		return
	end

	if time() < hitLockUntil then
		return
	end

	isCrashed = true
	shakeTimeLeft = CAMERA_SHAKE_DURATION
	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 18, 0) + (forwardDir * 8)
	rootPart.AssemblyAngularVelocity = Vector3.new(
		math.random(-22, 22),
		math.random(-30, 30),
		math.random(-22, 22)
	)

	task.delay(GAME_OVER_DELAY, showGameOver)
end

local function onBodyTouched(hit: BasePart)
	if not hit or hit.Name ~= OBSTACLE_NAME then
		return
	end

	triggerCrash()
end

local function clearBodyConnections()
	for _, connection in ipairs(bodyConnections) do
		connection:Disconnect()
	end
	table.clear(bodyConnections)
end

local function wireBodyTouchEvents(targetCharacter: Model)
	clearBodyConnections()

	local function hookPart(part: Instance)
		if not part:IsA("BasePart") then
			return
		end

		table.insert(bodyConnections, part.Touched:Connect(function(hit)
			onBodyTouched(hit)
		end))
	end

	for _, descendant in ipairs(targetCharacter:GetDescendants()) do
		hookPart(descendant)
	end

	table.insert(bodyConnections, targetCharacter.DescendantAdded:Connect(hookPart))
end

local function updateTrackDirections()
	local look = rootPart.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.001 then
		forwardDir = flatLook.Unit
		rightDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X)
	end
end

local function currentSideInput()
	if leftHeld == rightHeld then
		return 0
	end

	if leftHeld then
		return -1
	end

	return 1
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = AUTO_RUN_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = JUMP_POWER
	updateTrackDirections()
	resetRunState(true)
	wireBodyTouchEvents(character)
end

player.CharacterAdded:Connect(onCharacterAdded)
humanoid.AutoRotate = false
humanoid.WalkSpeed = AUTO_RUN_SPEED
humanoid.UseJumpPower = true
humanoid.JumpPower = JUMP_POWER
updateTrackDirections()
resetRunState(true)
wireBodyTouchEvents(character)

buttonRetry.MouseButton1Click:Connect(function()
	gameOverFrame.Visible = false
	leftHeld = false
	rightHeld = false
	player:LoadCharacter()
end)

buttonContinue.MouseButton1Click:Connect(function()
	if not isGameOver then
		return
	end

	local pos = rootPart.Position
	rootPart.CFrame = CFrame.lookAt(pos, pos + forwardDir)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	resetRunState(false)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		leftHeld = true
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		rightHeld = true
	elseif input.KeyCode == Enum.KeyCode.Space and not isCrashed and not isGameOver then
		humanoid.Jump = true
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		leftHeld = false
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		rightHeld = false
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	syncScoreFromDistance()

	if not isCrashed and not isGameOver then
		local sideInput = currentSideInput()
		local desiredDirection = (forwardDir + (rightDir * sideInput * SIDE_INPUT_SCALE)).Unit
		humanoid:Move(desiredDirection, false)
	else
		humanoid:Move(Vector3.zero, false)
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CAMERA_FOV

		local target = rootPart.Position + Vector3.new(0, 2.5, 0)
		local cameraPosition = target - (forwardDir * CAMERA_DISTANCE) + Vector3.new(0, CAMERA_HEIGHT, 0)
		local cameraLookAt = target + (forwardDir * CAMERA_LOOK_AHEAD)

		if shakeTimeLeft > 0 then
			shakeTimeLeft = math.max(0, shakeTimeLeft - deltaTime)
			local t = shakeTimeLeft / CAMERA_SHAKE_DURATION
			local strength = CAMERA_SHAKE_MAGNITUDE * t
			local shakeOffset = Vector3.new(
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength
			)
			cameraPosition += shakeOffset
			cameraLookAt += shakeOffset * 0.35
		end

		camera.CFrame = CFrame.lookAt(cameraPosition, cameraLookAt)
	end
end)
