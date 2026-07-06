--Connected Discord-GitHub
--Discord: pepc84
--Roblox: PepC84
--==================================================
-- Services
--==================================================

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--==================================================
-- References
--==================================================

local player
local playerHitbox
local leftBall
local rightBall
local body

local scene
local enemies
local fakeBullets
local bulletDespawners

local knifeTemplate
local specialTemplate

local instanceScripts

--==================================================
-- Constants
--==================================================

local MOVE_SPEED = 24
local SHIFT_MULTIPLIER = 0.5

local NORMAL_BULLET_SPEED = 100
local SPECIAL_BULLET_SPEED = 75

local NORMAL_FIRE_RATE = 0.075
local SPECIAL_FIRE_RATE = 0.5

local BULLET_ARRAYS = 5

local HITBOX_SIZE = 1

local SIN_45 = math.sqrt(2) / 2

local NORMAL_BULLET_TRANSPARENCY = 0.5
local SPECIAL_BULLET_TRANSPARENCY = 0.25

local BORDER_DOWN
local BORDER_UP
local BORDER_LEFT
local BORDER_RIGHT

local DEFAULT_BALL_OFFSET = Vector3.new(0, 0, 3)
local FOCUS_BALL_OFFSET = Vector3.new(0, 3, 1)

--==================================================
-- State
--==================================================

local State = {

	keys = {

		W = false,
		A = false,
		S = false,
		D = false,

		Shift = false,
		Space = false,
		X = false,
		Backspace = false,

	},

	previousNormalShot = 0,
	previousSpecialShot = 0,

	extraShots = 10,

	amplitude = 0.20,

	shiftMultiplier = 1

}

--==================================================
-- Lookup Tables
--==================================================

local KeyMap = {
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.A] = "A",
	[Enum.KeyCode.S] = "S",
	[Enum.KeyCode.D] = "D",

	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "Shift",

	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.Backspace] = "Backspace",
}

local DirectionMap = {
	W = Vector3.new(0, 1, 0),
	A = Vector3.new(0, 0, -1),
	S = Vector3.new(0, -1, 0),
	D = Vector3.new(0, 0, 1),
}

--==================================================
-- Tween Objects
--==================================================

local tweenValue
local tweenForward
local tweenBack

--==================================================
-- Utility
--==================================================

local function calculateNearestEven(number)
	if number % 2 == 0 then
		return number
	end

	return number - 1
end

local function rotationToDirection(rotation)
	return Vector3.new(
		0,
		math.sin(math.rad(rotation + 90)),
		math.cos(math.rad(rotation + 90))
	).Unit
end

local function isEnemy(hit)
	return hit and hit:IsDescendantOf(enemies)
end

local function bulletHit(hit, bulletType)
	-- TODO:
	-- Damage enemy
	-- Spawn particles
	-- Play sounds
	-- Award score
end

local function canFireNormal()
	return time() - State.previousNormalShot >= NORMAL_FIRE_RATE
end

local function canFireSpecial()
	return time() - State.previousSpecialShot >= SPECIAL_FIRE_RATE
end

local function getMoveDirection()
	local direction = Vector3.zero

	for key, vector in pairs(DirectionMap) do
		if State.keys[key] then
			direction += vector
		end
	end

	if direction.Magnitude > 0 then
		direction = direction.Unit
	end

	return direction
end

local function clampPlayerPosition(position)
	return Vector3.new(
		position.X,
		math.clamp(
			position.Y,
			BORDER_DOWN + HITBOX_SIZE,
			BORDER_UP - HITBOX_SIZE
		),
		math.clamp(
			position.Z,
			BORDER_LEFT + HITBOX_SIZE,
			BORDER_RIGHT - HITBOX_SIZE
		)
	)
end
--==================================================
-- Player
--==================================================

local function updateBalls()
	leftBall.Position = playerHitbox.Position + tweenValue.Value

	rightBall.Position =
		playerHitbox.Position +
		Vector3.new(
			0,
			tweenValue.Value.Y,
			-tweenValue.Value.Z
		)

	body.Position = playerHitbox.Position
end

local function updateShiftState()
	if State.keys.Shift then
		State.shiftMultiplier = SHIFT_MULTIPLIER
		tweenForward:Play()
	else
		State.shiftMultiplier = 1
		tweenBack:Play()
	end
end

local function updateTween()
	updateShiftState()
end

local function movePlayer(dt)
	local direction = getMoveDirection()

	if direction.Magnitude == 0 then
		updateBalls()
		return
	end

	local velocity =
		direction *
		MOVE_SPEED *
		State.shiftMultiplier

	local targetPosition =
		playerHitbox.Position +
		velocity * dt

	playerHitbox.Position =
		clampPlayerPosition(targetPosition)

	updateBalls()
end
--==================================================
-- Bullet System
--==================================================

local function destroyBullet(bullet)
	if bullet and bullet.Parent then
		bullet:Destroy()
	end
end

local function destroySpecialBullet(bullet, followScript)
	if followScript and followScript.Parent then
		followScript:Destroy()
	end

	destroyBullet(bullet)
end

local function connectBulletCollision(bullet, bulletType)
	bullet.Touched:Connect(function(hit)

		if hit:IsDescendantOf(bulletDespawners) then
			destroyBullet(bullet)
			return
		end

		if isEnemy(hit) then
			bulletHit(hit, bulletType)
			destroyBullet(bullet)
		end

	end)
end

local function connectSpecialBulletCollision(bullet, followScript)
	bullet.Touched:Connect(function(hit)

		if hit:IsDescendantOf(bulletDespawners) then
			destroySpecialBullet(bullet, followScript)
			return
		end

		if isEnemy(hit) then
			bulletHit(hit, "special")
			destroySpecialBullet(bullet, followScript)
		end

	end)
end

local function createBullet(positionOffset, rotation, single)
	local bullet = normalBulletTemplate:Clone()

	bullet.Name = "normalShot"

	bullet.Position =
		playerHitbox.Position +
		Vector3.new(0, 0, positionOffset)

	local direction = rotationToDirection(rotation)

	bullet.CFrame =
		CFrame.lookAt(
			bullet.Position,
			bullet.Position + direction
		)

	if single then
		bullet.Orientation += Vector3.new(0, 90, 0)
	end

	bullet.Velocity = direction * NORMAL_BULLET_SPEED
	bullet.CollisionGroup = "ignore"

	bullet.bulletShape.Transparency = NORMAL_BULLET_TRANSPARENCY

	bullet.Parent = fakeBullets

	connectBulletCollision(bullet, "normal")
end

local function createSpecialBullet(originPart, cosine)
	local bullet = specialBulletTemplate:Clone()

	bullet.Name = "specialShot"
	bullet.Position = originPart.Position

	local direction = Vector3.new(0, SIN_45, cosine)

	bullet.CFrame =
		CFrame.lookAt(
			bullet.Position,
			bullet.Position + direction
		)

	bullet.Velocity = direction * SPECIAL_BULLET_SPEED

	bullet.CollisionGroup = "ignore"
	bullet.bulletShape.Transparency = SPECIAL_BULLET_TRANSPARENCY

	bullet.Parent = fakeBullets.special

	local followScript = ReplicatedStorage.followNearestEnemy:Clone()

	followScript.Parent = instanceScripts
	followScript.whatever.Value = bullet
	followScript.savedVector.Value = direction
	followScript.Disabled = false

	connectSpecialBulletCollision(bullet, followScript)
end
--==================================================
-- Weapon System
--==================================================

local function fireNormalShot()
	if not canFireNormal() then
		return
	end

	if BULLET_ARRAYS % 2 ~= 0 then
		createBullet(0, 0, true)
		State.amplitude += 0.35
	end

	for i = 1, calculateNearestEven(BULLET_ARRAYS) do
		local sign = (-1) ^ i

		if sign == -1 then
			State.amplitude *= 3
		end

		createBullet(
			sign * 0.5,
			(State.amplitude * -sign) + (-sign * 0.10),
			false
		)
	end

	State.amplitude = 0.20
	State.extraShots += 1
	State.previousNormalShot = time()
end

local function fireSpecialShot()
	if not canFireSpecial() then
		return
	end

	createSpecialBullet(leftBall, SIN_45)
	createSpecialBullet(rightBall, -SIN_45)

	State.previousSpecialShot = time()
end

local function updateShooting()
	if not State.keys.Space and State.extraShots >= 3 then
		return
	end

	fireNormalShot()
	fireSpecialShot()
end
--==================================================
-- Input
--==================================================

local function setKeyState(keyCode, isPressed)
	local key = KeyMap[keyCode]

	if not key then
		return
	end

	State.keys[key] = isPressed

	if key == "Space" and not isPressed then
		State.extraShots = 1
	end
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then
		return
	end

	setKeyState(input.KeyCode, true)
end

local function onInputEnded(input, gameProcessed)
	if gameProcessed then
		return
	end

	setKeyState(input.KeyCode, false)
end

--==================================================
-- Runtime
--==================================================

local function onHeartbeat(dt)
	updateTween()
	movePlayer(dt)
	updateShooting()
end
--==================================================
-- Setup
--==================================================
local function setupReferences()

	player = workspace.player

	playerHitbox = player.playerHitbox
	leftBall = playerHitbox.leftBall
	rightBall = playerHitbox.rightBall
	body = playerHitbox.body

	scene = workspace.scene
	enemies = workspace.enemies
	fakeBullets = workspace.fakeBullets
	bulletDespawners = workspace.bulletDespawners

	normalBulletTemplate =
		ReplicatedStorage.Assets.bulletAssets:WaitForChild("knifeHitbox")

	specialBulletTemplate =
		ReplicatedStorage.Assets.bulletAssets:WaitForChild("smallCircleHitbox")

	-- Exactly like the original script
	instanceScripts = script.Parent:WaitForChild("instanceScripts")

	BORDER_DOWN = scene.borderDown.Position.Y
	BORDER_UP = scene.borderUp.Position.Y
	BORDER_LEFT = scene.borderLeft.Position.Z
	BORDER_RIGHT = scene.borderRight.Position.Z

end

local function setupTweens()
	tweenValue = playerHitbox.tweenValue

	local tweenInfo = TweenInfo.new(
		0.10,
		Enum.EasingStyle.Linear
	)

	tweenForward = TweenService:Create(
		tweenValue,
		tweenInfo,
		{
			Value = FOCUS_BALL_OFFSET
		}
	)

	tweenBack = TweenService:Create(
		tweenValue,
		tweenInfo,
		{
			Value = DEFAULT_BALL_OFFSET
		}
	)
end

local function connectEvents()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	RunService.Heartbeat:Connect(onHeartbeat)
end

local function initialize()
	setupReferences()
	setupTweens()
	connectEvents()
end

initialize()
