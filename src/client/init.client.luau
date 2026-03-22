local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local AUTO_RUN_SPEED = 26
local AUTO_RUN_MAX_SPEED = 52
local AUTO_RUN_ACCEL_PER_SEC = 0.55
local AUTO_RUN_ACCEL_PER_100_SCORE = 0.8
local SIDE_MOVE_SPEED = 16
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
local BOUNCE_UPWARD_SPEED = 42
local BOUNCE_COOLDOWN = 0.16
local RUNNER_SPAWN_NAME = "SpawnLocation"
local EXPLORE_SPAWN_NAME = "ExploreSpawn"
local MODE_RUNNER = "Runner"
local MODE_EXPLORE = "Explore"

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
local runElapsedTime = 0
local currentRunSpeed = AUTO_RUN_SPEED
local currentMode: string? = nil
local clearBodyConnections: () -> ()
local wireBodyTouchEvents: (Model) -> ()
local lastBounceAt = 0

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

local modeSelectFrame = Instance.new("Frame")
modeSelectFrame.Name = "ModeSelect"
modeSelectFrame.AnchorPoint = Vector2.new(0.5, 0.5)
modeSelectFrame.Position = UDim2.fromScale(0.5, 0.5)
modeSelectFrame.Size = UDim2.fromOffset(420, 260)
modeSelectFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
modeSelectFrame.BackgroundTransparency = 0.08
modeSelectFrame.Visible = true
modeSelectFrame.Parent = gameGui

local modeTitle = Instance.new("TextLabel")
modeTitle.Name = "Title"
modeTitle.BackgroundTransparency = 1
modeTitle.Position = UDim2.fromOffset(24, 18)
modeTitle.Size = UDim2.fromOffset(372, 48)
modeTitle.Font = Enum.Font.GothamBlack
modeTitle.TextSize = 46
modeTitle.TextColor3 = Color3.fromRGB(248, 248, 248)
modeTitle.Text = "Temple Run"
modeTitle.Parent = modeSelectFrame

local buttonRunner = Instance.new("TextButton")
buttonRunner.Name = "Runner"
buttonRunner.Position = UDim2.fromOffset(24, 106)
buttonRunner.Size = UDim2.fromOffset(178, 110)
buttonRunner.BackgroundColor3 = Color3.fromRGB(52, 117, 214)
buttonRunner.Font = Enum.Font.GothamBold
buttonRunner.TextSize = 32
buttonRunner.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonRunner.Text = "Runner"
buttonRunner.Parent = modeSelectFrame

local buttonExplore = Instance.new("TextButton")
buttonExplore.Name = "Explore"
buttonExplore.Position = UDim2.fromOffset(218, 106)
buttonExplore.Size = UDim2.fromOffset(178, 110)
buttonExplore.BackgroundColor3 = Color3.fromRGB(45, 156, 102)
buttonExplore.Font = Enum.Font.GothamBold
buttonExplore.TextSize = 32
buttonExplore.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonExplore.Text = "Explore"
buttonExplore.Parent = modeSelectFrame

local function getSpawnByName(name: string): SpawnLocation?
	local candidate = workspace:FindFirstChild(name)
	if candidate and candidate:IsA("SpawnLocation") then
		return candidate
	end

	return nil
end

local function teleportToSpawn(spawnName: string)
	if not rootPart then
		return
	end

	local spawn = getSpawnByName(spawnName)
	if not spawn then
		return
	end

	local targetPosition = spawn.Position + Vector3.new(0, 3.5, 0)
	rootPart.CFrame = CFrame.new(targetPosition)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function updateScoreLabel()
	scoreLabel.Text = string.format("Score: %d", currentScore)
end

local function syncScoreFromDistance()
	local distance = rootPart.Position:Dot(forwardDir)
	currentScore = math.max(0, math.floor(distance - scoreStartDistance))
	updateScoreLabel()
end

local function updateRunSpeed(deltaTime: number)
	runElapsedTime += deltaTime

	local scorePressure = (currentScore / 100) * AUTO_RUN_ACCEL_PER_100_SCORE
	local timePressure = runElapsedTime * AUTO_RUN_ACCEL_PER_SEC
	local targetSpeed = AUTO_RUN_SPEED + timePressure + scorePressure
	currentRunSpeed = math.min(AUTO_RUN_MAX_SPEED, targetSpeed)
	humanoid.WalkSpeed = currentRunSpeed
end

local function resetRunState(resetScore: boolean)
	isCrashed = false
	isGameOver = false
	shakeTimeLeft = 0
	hitLockUntil = time() + CRASH_COOLDOWN
	lastBounceAt = 0
	humanoid.PlatformStand = false
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = JUMP_POWER
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	if resetScore then
		runElapsedTime = 0
		currentRunSpeed = AUTO_RUN_SPEED
		scoreStartDistance = rootPart.Position:Dot(forwardDir)
		currentScore = 0
		updateScoreLabel()
	else
		scoreStartDistance = rootPart.Position:Dot(forwardDir) - currentScore
		runElapsedTime = (currentRunSpeed - AUTO_RUN_SPEED) / AUTO_RUN_ACCEL_PER_SEC
	end

	humanoid.WalkSpeed = currentRunSpeed

	gameOverFrame.Visible = false
	scoreLabel.Visible = true
end

local function activateExploreMode()
	currentMode = MODE_EXPLORE
	modeSelectFrame.Visible = false
	gameOverFrame.Visible = false
	scoreLabel.Visible = true
	leftHeld = false
	rightHeld = false
	clearBodyConnections()

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = 16
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end

	teleportToSpawn(EXPLORE_SPAWN_NAME)
end

local function activateRunnerMode(resetScore: boolean)
	currentMode = MODE_RUNNER
	modeSelectFrame.Visible = false
	teleportToSpawn(RUNNER_SPAWN_NAME)
	updateTrackDirections()
	resetRunState(resetScore)
	wireBodyTouchEvents(character)
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

local function isObstacleContact(hit: BasePart): boolean
	local node: Instance? = hit

	for _ = 1, 8 do
		if not node then
			break
		end

		if node.Name == OBSTACLE_NAME or node:GetAttribute("IsObstacle") == true then
			return true
		end

		node = node.Parent
	end

	return false
end

local function onBodyTouched(hit: BasePart)
	if not hit then
		return
	end

	if not isObstacleContact(hit) then
		return
	end

	triggerCrash()
end

local function pollObstacleCollision()
	if isCrashed or isGameOver then
		return
	end

	local checkSize = Vector3.new(rootPart.Size.X * 1.45, rootPart.Size.Y * 1.25, rootPart.Size.Z * 1.45)
	local touchingParts = workspace:GetPartBoundsInBox(rootPart.CFrame, checkSize)

	for _, part in ipairs(touchingParts) do
		if part:IsA("BasePart") and not part:IsDescendantOf(character) and isObstacleContact(part) then
			triggerCrash()
			return
		end
	end
end

clearBodyConnections = function()
	for _, connection in ipairs(bodyConnections) do
		connection:Disconnect()
	end
	table.clear(bodyConnections)
end

wireBodyTouchEvents = function(targetCharacter: Model)
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

	if currentMode == MODE_EXPLORE then
		activateExploreMode()
	elseif currentMode == MODE_RUNNER then
		activateRunnerMode(true)
	else
		modeSelectFrame.Visible = true
		scoreLabel.Visible = true
		gameOverFrame.Visible = false
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		clearBodyConnections()
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
modeSelectFrame.Visible = true
scoreLabel.Visible = true
gameOverFrame.Visible = false
humanoid.AutoRotate = true
humanoid.WalkSpeed = 0
humanoid.JumpPower = 0
clearBodyConnections()

buttonRunner.MouseButton1Click:Connect(function()
	activateRunnerMode(true)
end)

buttonExplore.MouseButton1Click:Connect(function()
	activateExploreMode()
end)

buttonRetry.MouseButton1Click:Connect(function()
	if currentMode ~= MODE_RUNNER then
		return
	end

	gameOverFrame.Visible = false
	leftHeld = false
	rightHeld = false
	player:LoadCharacter()
end)

buttonContinue.MouseButton1Click:Connect(function()
	if currentMode ~= MODE_RUNNER or not isGameOver then
		return
	end

	local pos = rootPart.Position
	rootPart.CFrame = CFrame.lookAt(pos, pos + forwardDir)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	resetRunState(false)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if currentMode ~= MODE_RUNNER then
		return
	end

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
	if currentMode ~= MODE_RUNNER then
		return
	end

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

	pollObstacleCollision()

	if currentMode ~= MODE_RUNNER then
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
		return
	end

	if not scoreLabel.Visible then
		scoreLabel.Visible = true
	end

	syncScoreFromDistance()

	if not isCrashed and not isGameOver then
		updateRunSpeed(deltaTime)
		local sideInput = currentSideInput()
		local sideInputScale = SIDE_MOVE_SPEED / math.max(1, currentRunSpeed)
		local desiredDirection = (forwardDir + (rightDir * sideInput * sideInputScale)).Unit
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
