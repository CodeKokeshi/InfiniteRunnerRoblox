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

local OBSTACLE_HEIGHT_MIN = 3.8
local OBSTACLE_HEIGHT_MAX = 8
local OBSTACLE_WIDTH_MIN = 2.5
local OBSTACLE_WIDTH_MAX = 6.5
local OBSTACLE_DEPTH_MIN = 2.2
local OBSTACLE_DEPTH_MAX = 5.8

local TRACK_FOLDER_NAME = "TrackSegments"
local TRACK_FORWARD = Vector3.new(0, 0, -1)
local rng = Random.new()
local nextForcedObstacleIndex = SAFE_START_SEGMENTS + 1

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

	baseplate.Transparency = 1
	baseplate.CanCollide = false
	baseplate.CanTouch = false
	baseplate.CanQuery = false
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
	local obstacle = Instance.new("Part")
	obstacle.Name = "Obstacle"
	obstacle.Anchored = true
	obstacle.Material = Enum.Material.Basalt
	obstacle.Color = Color3.fromRGB(120, 44, 37)
	obstacle.TopSurface = Enum.SurfaceType.Smooth
	obstacle.BottomSurface = Enum.SurfaceType.Smooth
	obstacle.Size = Vector3.new(OBSTACLE_WIDTH_MAX, OBSTACLE_HEIGHT_MAX, OBSTACLE_DEPTH_MAX)
	obstacle.Parent = trackFolder
	obstacle:SetAttribute("TrackIndex", index)
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

local function hideObstacle(obstacle: BasePart)
	obstacle.Transparency = 1
	obstacle.CanCollide = false
	obstacle.CanTouch = false
	obstacle.CanQuery = false
end

local function showObstacle(obstacle: BasePart)
	obstacle.Transparency = 0
	obstacle.CanCollide = true
	obstacle.CanTouch = true
	obstacle.CanQuery = true
end

local function placeObstacle(obstacle: BasePart, index: number)
	obstacle:SetAttribute("TrackIndex", index)

	if index <= SAFE_START_SEGMENTS then
		hideObstacle(obstacle)
		return
	end

	local shouldForce = index >= nextForcedObstacleIndex
	local shouldSpawn = shouldForce or (rng:NextNumber() <= OBSTACLE_CHANCE)
	if not shouldSpawn then
		hideObstacle(obstacle)
		return
	end

	local nextGap = rng:NextInteger(MIN_SEGMENTS_BETWEEN_OBSTACLES, MAX_SEGMENTS_BETWEEN_OBSTACLES)
	nextForcedObstacleIndex = index + nextGap + 1

	local obstacleWidth = rng:NextNumber(OBSTACLE_WIDTH_MIN, OBSTACLE_WIDTH_MAX)
	local obstacleHeight = rng:NextNumber(OBSTACLE_HEIGHT_MIN, OBSTACLE_HEIGHT_MAX)
	local obstacleDepth = rng:NextNumber(OBSTACLE_DEPTH_MIN, OBSTACLE_DEPTH_MAX)
	obstacle.Size = Vector3.new(obstacleWidth, obstacleHeight, obstacleDepth)

	local lanePick = rng:NextInteger(-1, 1)
	local laneX = TRACK_X + (lanePick * LANE_OFFSET_X)
	local laneZJitter = rng:NextNumber(-0.24, 0.24) * SEGMENT_LENGTH
	local topY = SEGMENT_Y + (SEGMENT_THICKNESS * 0.5)
	local obstacleY = topY + (obstacleHeight * 0.5)
	local obstacleZ = (-index * SEGMENT_LENGTH) + laneZJitter

	obstacle.CFrame = CFrame.new(laneX, obstacleY, obstacleZ)
	showObstacle(obstacle)
end

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
	}
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

RunService.Heartbeat:Connect(function()
	local rootPart = getRunnerRootPart()
	if not rootPart then
		return
	end

	local forwardDistance = rootPart.Position:Dot(TRACK_FORWARD)
	local currentIndex = math.floor(forwardDistance / SEGMENT_LENGTH)
	local desiredCenter = currentIndex

	while desiredCenter > (firstIndex + SEGMENTS_BEHIND) do
		recycleForward()
	end

	while desiredCenter < (firstIndex + SEGMENTS_BEHIND) do
		recycleBackward()
	end
end)
