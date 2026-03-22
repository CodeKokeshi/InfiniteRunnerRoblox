local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SEGMENT_LENGTH = 64
local SEGMENT_WIDTH = 22
local SEGMENT_THICKNESS = 1.5
local SEGMENT_Y = -1
local SEGMENTS_AHEAD = 20
local SEGMENTS_BEHIND = 5
local TRACK_X = 0
local LANE_OFFSET_X = 6
local OBSTACLE_CHANCE = 0.72
local SAFE_START_SEGMENTS = 2
local MIN_SEGMENTS_BETWEEN_OBSTACLES = 0
local MAX_SEGMENTS_BETWEEN_OBSTACLES = 1

local OBSTACLE_TEMPLATE_NAMES = { "car", "truck", "car2" }
local HIDDEN_OBSTACLE_CFRAME = CFrame.new(0, -500, 0)
local OBSTACLE_YAW_OFFSET = math.rad(180)
local OBSTACLE_MOVE_SPEED_MIN = 32
local OBSTACLE_MOVE_SPEED_MAX = 40
local OBSTACLE_SPEED_PLAYER_FACTOR = 0.45
local SCORE_MILESTONE_BOOST = 2000
local OBSTACLE_MILESTONE_MULTIPLIER = 1.9
local OBSTACLE_POST_MILESTONE_GROWTH = 0.00035
local OBSTACLE_POST_MILESTONE_MAX_MULTIPLIER = 2.45
local OBSTACLE_RECYCLE_BEHIND_DISTANCE = 26
local OBSTACLE_RESPAWN_MIN_AHEAD_SEGMENTS = 6
local FRONT_TRIGGER_THICKNESS = 1.2

local EXPLORE_SPAWN_NAME = "ExploreSpawn"
local EXPLORE_SPAWN_POSITION = Vector3.new(-39, 0.5, 106)

local TRACK_FOLDER_NAME = "TrackSegments"
local TRACK_FORWARD = Vector3.new(0, 0, -1)
local RUNNER_SPAWN_POSITION = Vector3.new(0, 0.5, 0)
local rng = Random.new()
local nextForcedObstacleIndex = SAFE_START_SEGMENTS + 1
local obstacleTemplates = {}

local totalSegments = SEGMENTS_AHEAD + SEGMENTS_BEHIND + 1
local trackFolder = workspace:FindFirstChild(TRACK_FOLDER_NAME)

if not trackFolder then
	trackFolder = Instance.new("Folder")
	trackFolder.Name = TRACK_FOLDER_NAME
	trackFolder.Parent = workspace
end

for _, child in ipairs(trackFolder:GetChildren()) do
	child:Destroy()
end

local function hideBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if not baseplate or not baseplate:IsA("BasePart") then
		return
	end

	baseplate.Transparency = 0
	baseplate.CanCollide = true
	baseplate.CanTouch = true
	baseplate.CanQuery = true
end

local function ensureExploreSpawn()
	local existing = workspace:FindFirstChild(EXPLORE_SPAWN_NAME)
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = EXPLORE_SPAWN_NAME
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = EXPLORE_SPAWN_POSITION
	spawn.BrickColor = BrickColor.new("Cyan")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = workspace
	return spawn
end

local function cacheObstacleTemplates()
	table.clear(obstacleTemplates)

	for _, templateName in ipairs(OBSTACLE_TEMPLATE_NAMES) do
		local candidate = workspace:FindFirstChild(templateName)
		if candidate and candidate:IsA("Model") then
			table.insert(obstacleTemplates, candidate)
		end
	end
end

local function createSegment(index: number)
	local segment = Instance.new("Part")
	segment.Name = "Segment"
	segment.Anchored = true
	segment.Material = Enum.Material.Concrete
	segment.Color = Color3.fromRGB(67, 67, 75)
	segment.TopSurface = Enum.SurfaceType.Smooth
	segment.BottomSurface = Enum.SurfaceType.Smooth
	segment.Size = Vector3.new(SEGMENT_WIDTH, SEGMENT_THICKNESS, SEGMENT_LENGTH)
	segment.Parent = trackFolder
	segment:SetAttribute("TrackIndex", index)
	return segment
end

local function createObstacle(index: number)
	if #obstacleTemplates == 0 then
		local fallback = Instance.new("Part")
		fallback.Name = "Obstacle"
		fallback.Anchored = true
		fallback.Material = Enum.Material.Basalt
		fallback.Color = Color3.fromRGB(120, 44, 37)
		fallback.TopSurface = Enum.SurfaceType.Smooth
		fallback.BottomSurface = Enum.SurfaceType.Smooth
		fallback.Size = Vector3.new(5, 5, 5)
		fallback.Parent = trackFolder
		fallback:SetAttribute("TrackIndex", index)
		fallback:SetAttribute("IsObstacle", true)
		fallback:SetAttribute("ObstacleActive", false)
		return fallback
	end

	local template = obstacleTemplates[rng:NextInteger(1, #obstacleTemplates)]
	local obstacle = template:Clone()
	obstacle.Name = "Obstacle"
	obstacle.Parent = trackFolder
	obstacle:SetAttribute("TrackIndex", index)
	obstacle:SetAttribute("IsObstacle", true)
	obstacle:SetAttribute("ObstacleActive", false)

	for _, descendant in ipairs(obstacle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant:SetAttribute("IsObstacle", true)
		end
	end

	local frontTrigger = Instance.new("Part")
	frontTrigger.Name = "FrontTrigger"
	frontTrigger.Anchored = true
	frontTrigger.CanCollide = false
	frontTrigger.CanQuery = false
	frontTrigger.CanTouch = false
	frontTrigger.Transparency = 1
	frontTrigger.Material = Enum.Material.SmoothPlastic
	frontTrigger.Color = Color3.fromRGB(255, 0, 0)
	frontTrigger:SetAttribute("IsObstacle", true)
	frontTrigger:SetAttribute("IsObstacleFront", true)
	frontTrigger.Parent = obstacle

	return obstacle
end

local function segmentCenter(index: number)
	return Vector3.new(
		TRACK_X,
		SEGMENT_Y,
		-index * SEGMENT_LENGTH
	)
end

local function placeSegment(segment: BasePart, index: number)
	segment:SetAttribute("TrackIndex", index)
	segment.CFrame = CFrame.new(segmentCenter(index))
end

local function setObstacleCollisionEnabled(obstacle: Instance, isEnabled: boolean)
	if obstacle:IsA("BasePart") then
		local isFrontTrigger = obstacle:GetAttribute("IsObstacleFront") == true
		if isFrontTrigger then
			obstacle.CanCollide = false
			obstacle.CanTouch = isEnabled
			obstacle.CanQuery = false
			obstacle.Transparency = 1
		else
			obstacle.CanCollide = isEnabled
			obstacle.CanTouch = isEnabled
			obstacle.CanQuery = isEnabled
			obstacle.Transparency = isEnabled and 0 or 1
		end
		return
	end

	for _, descendant in ipairs(obstacle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local isFrontTrigger = descendant:GetAttribute("IsObstacleFront") == true
			if isFrontTrigger then
				descendant.CanCollide = false
				descendant.CanTouch = isEnabled
				descendant.CanQuery = false
				descendant.Transparency = 1
			else
				descendant.CanCollide = isEnabled
				descendant.CanTouch = isEnabled
				descendant.CanQuery = isEnabled
				descendant.Transparency = isEnabled and 0 or 1
			end
		end
	end

	obstacle:SetAttribute("ObstacleActive", isEnabled)
end

local function updateFrontTrigger(obstacle: Instance, obstacleCFrame: CFrame)
	if not obstacle:IsA("Model") then
		return
	end

	local trigger = obstacle:FindFirstChild("FrontTrigger")
	if not trigger or not trigger:IsA("BasePart") then
		return
	end

	trigger.Size = Vector3.new(0.2, 0.2, 0.2)
	trigger.CFrame = obstacleCFrame

	local _, bounds = obstacle:GetBoundingBox()
	local triggerHeight = math.max(2.2, bounds.Y * 0.65)
	local triggerWidth = math.max(2.0, bounds.X * 0.9)
	local triggerDepth = FRONT_TRIGGER_THICKNESS
	local yOffset = (-bounds.Y * 0.5) + (triggerHeight * 0.5)
	local zOffset = (bounds.Z * 0.5) + (triggerDepth * 0.5)

	trigger.Size = Vector3.new(triggerWidth, triggerHeight, triggerDepth)
	trigger.CFrame = obstacleCFrame * CFrame.new(0, yOffset, zOffset)
end

local function hideObstacle(obstacle: Instance)
	setObstacleCollisionEnabled(obstacle, false)

	if obstacle:IsA("Model") then
		obstacle:PivotTo(HIDDEN_OBSTACLE_CFRAME)
	elseif obstacle:IsA("BasePart") then
		obstacle.CFrame = HIDDEN_OBSTACLE_CFRAME
	end
end

local function showObstacle(obstacle: Instance)
	setObstacleCollisionEnabled(obstacle, true)
end

local function placeObstacle(obstacle: Instance, index: number, forceSpawn: boolean?)
	obstacle:SetAttribute("TrackIndex", index)

	if index <= SAFE_START_SEGMENTS then
		hideObstacle(obstacle)
		return
	end

	local shouldForce = index >= nextForcedObstacleIndex
	local shouldSpawn = forceSpawn == true or shouldForce or (rng:NextNumber() <= OBSTACLE_CHANCE)
	if not shouldSpawn then
		hideObstacle(obstacle)
		return
	end

	if forceSpawn ~= true then
		local nextGap = rng:NextInteger(MIN_SEGMENTS_BETWEEN_OBSTACLES, MAX_SEGMENTS_BETWEEN_OBSTACLES)
		nextForcedObstacleIndex = index + nextGap + 1
	end

	local lanePick = rng:NextInteger(-1, 1)
	local laneX = TRACK_X + (lanePick * LANE_OFFSET_X)
	local laneZJitter = rng:NextNumber(-0.24, 0.24) * SEGMENT_LENGTH
	local topY = SEGMENT_Y + (SEGMENT_THICKNESS * 0.5)
	local obstacleHeight = 5

	if obstacle:IsA("Model") then
		local _, bounds = obstacle:GetBoundingBox()
		obstacleHeight = bounds.Y
	elseif obstacle:IsA("BasePart") then
		obstacleHeight = obstacle.Size.Y
	end

	local obstacleY = topY + (obstacleHeight * 0.5)
	local obstacleZ = (-index * SEGMENT_LENGTH) + laneZJitter
	local obstacleCFrame = CFrame.new(laneX, obstacleY, obstacleZ) * CFrame.Angles(0, OBSTACLE_YAW_OFFSET, 0)

	if obstacle:IsA("Model") then
		obstacle:PivotTo(obstacleCFrame)
		local trigger = obstacle:FindFirstChild("FrontTrigger")
		if trigger and trigger:IsA("BasePart") then
			trigger.Size = Vector3.new(0.2, 0.2, 0.2)
			trigger.CFrame = obstacleCFrame
		end

		local obstacleBoundsCFrame, obstacleBounds = obstacle:GetBoundingBox()
		local obstacleBottomY = obstacleBoundsCFrame.Position.Y - (obstacleBounds.Y * 0.5)
		local yCorrection = topY - obstacleBottomY
		if math.abs(yCorrection) > 0.001 then
			obstacleCFrame += Vector3.new(0, yCorrection, 0)
			obstacle:PivotTo(obstacleCFrame)
		end

		updateFrontTrigger(obstacle, obstacleCFrame)
	elseif obstacle:IsA("BasePart") then
		obstacle.CFrame = obstacleCFrame
	end

	showObstacle(obstacle)
end

cacheObstacleTemplates()

local segments = table.create(totalSegments)
local firstIndex = -SEGMENTS_BEHIND
local lastIndex = SEGMENTS_AHEAD

for i = 1, totalSegments do
	local segmentIndex = firstIndex + (i - 1)
	local segment = createSegment(segmentIndex)
	local obstacle = createObstacle(segmentIndex)
	placeSegment(segment, segmentIndex)
	placeObstacle(obstacle, segmentIndex)
	segments[i] = {
		ground = segment,
		obstacle = obstacle,
		moveSpeed = rng:NextNumber(OBSTACLE_MOVE_SPEED_MIN, OBSTACLE_MOVE_SPEED_MAX),
	}
end

local function calculateScoreMilestoneMultiplier(scoreEstimate: number): number
	if scoreEstimate < SCORE_MILESTONE_BOOST then
		return 1
	end

	local over = scoreEstimate - SCORE_MILESTONE_BOOST
	local growth = over * OBSTACLE_POST_MILESTONE_GROWTH
	return math.min(OBSTACLE_POST_MILESTONE_MAX_MULTIPLIER, OBSTACLE_MILESTONE_MULTIPLIER + growth)
end

local function moveObstacleTowardPlayer(segmentData, playerSpeed: number, scoreEstimate: number, deltaTime: number)
	if deltaTime <= 0 then
		return
	end

	local obstacle = segmentData.obstacle
	if not obstacle or obstacle:GetAttribute("ObstacleActive") ~= true then
		return
	end

	local milestoneMult = calculateScoreMilestoneMultiplier(scoreEstimate)
	local moveSpeed = (segmentData.moveSpeed + (playerSpeed * OBSTACLE_SPEED_PLAYER_FACTOR)) * milestoneMult
	local moveStep = (-TRACK_FORWARD) * moveSpeed * deltaTime

	if obstacle:IsA("Model") then
		obstacle:PivotTo(obstacle:GetPivot() + moveStep)
	elseif obstacle:IsA("BasePart") then
		obstacle.CFrame += moveStep
	end
end

local function getObstacleForwardDistance(obstacle: Instance): number?
	if obstacle:IsA("Model") then
		return obstacle:GetPivot().Position:Dot(TRACK_FORWARD)
	end

	if obstacle:IsA("BasePart") then
		return obstacle.Position:Dot(TRACK_FORWARD)
	end

	return nil
end

local function getRunnerRootPart(): BasePart?
	local player = Players:GetPlayers()[1]
	if not player then
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function recycleForward()
	local recycled = table.remove(segments, 1)
	if not recycled then
		return
	end

	firstIndex += 1
	lastIndex += 1
	placeSegment(recycled.ground, lastIndex)
	placeObstacle(recycled.obstacle, lastIndex)
	table.insert(segments, recycled)
end

local function recycleBackward()
	local recycled = table.remove(segments)
	if not recycled then
		return
	end

	firstIndex -= 1
	lastIndex -= 1
	placeSegment(recycled.ground, firstIndex)
	placeObstacle(recycled.obstacle, firstIndex)
	table.insert(segments, 1, recycled)
end

hideBaseplate()
ensureExploreSpawn()

RunService.Heartbeat:Connect(function(deltaTime)
	local rootPart = getRunnerRootPart()
	local playerSpeed = 0
	local scoreEstimate = 0
	local currentIndex = nil
	local furthestSafeRespawnIndex = nil
	local occupiedObstacleIndices = {}
	if rootPart then
		local horizontal = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
		playerSpeed = horizontal.Magnitude
		local runDistance = rootPart.Position:Dot(TRACK_FORWARD)
		local runStartDistance = RUNNER_SPAWN_POSITION:Dot(TRACK_FORWARD)
		scoreEstimate = math.max(0, math.floor(runDistance - runStartDistance))
		currentIndex = math.floor(runDistance / SEGMENT_LENGTH)
		furthestSafeRespawnIndex = math.max(firstIndex, currentIndex + OBSTACLE_RESPAWN_MIN_AHEAD_SEGMENTS)

		for _, segmentData in ipairs(segments) do
			local obstacle = segmentData.obstacle
			if obstacle and obstacle:GetAttribute("ObstacleActive") == true then
				local obstacleIndex = obstacle:GetAttribute("TrackIndex")
				if typeof(obstacleIndex) == "number" then
					occupiedObstacleIndices[obstacleIndex] = true
				end
			end
		end
	end

	for _, segmentData in ipairs(segments) do
		moveObstacleTowardPlayer(segmentData, playerSpeed, scoreEstimate, deltaTime)

		if rootPart and segmentData.obstacle and segmentData.obstacle:GetAttribute("ObstacleActive") == true then
			local obstacleForward = getObstacleForwardDistance(segmentData.obstacle)
			local playerForward = rootPart.Position:Dot(TRACK_FORWARD)
			if obstacleForward and obstacleForward < (playerForward - OBSTACLE_RECYCLE_BEHIND_DISTANCE) then
				local trackIndex = segmentData.obstacle:GetAttribute("TrackIndex")
				if typeof(trackIndex) == "number" and furthestSafeRespawnIndex then
					occupiedObstacleIndices[trackIndex] = nil
					local respawnIndex = nil
					for candidate = lastIndex, furthestSafeRespawnIndex, -1 do
						if not occupiedObstacleIndices[candidate] then
							respawnIndex = candidate
							break
						end
					end

					if not respawnIndex then
						respawnIndex = lastIndex
					end

					placeObstacle(segmentData.obstacle, respawnIndex, true)
					occupiedObstacleIndices[respawnIndex] = true
					segmentData.moveSpeed = rng:NextNumber(OBSTACLE_MOVE_SPEED_MIN, OBSTACLE_MOVE_SPEED_MAX)
				end
			end
		end
	end

	if not rootPart then
		return
	end

	local forwardDistance = rootPart.Position:Dot(TRACK_FORWARD)
	currentIndex = math.floor(forwardDistance / SEGMENT_LENGTH)
	local desiredCenter = currentIndex

	while desiredCenter > (firstIndex + SEGMENTS_BEHIND) do
		recycleForward()
	end

	while desiredCenter < (firstIndex + SEGMENTS_BEHIND) do
		recycleBackward()
	end
end)
