pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- perry the pedal the game

local perry
local frame
local gravity
local friction
local bullets

local PI = 3.14
local debug = ""
local BORDER_FLAGS = {
  TOP=0,
  BOTTOM=1,
  LEFT=2,
  RIGHT=3
}
local SCREEN_X = 128
local WORLD_X = SCREEN_X * 8

local cam

-- new updates from andrey

function _init()
  local jumpSpeed = 20
  perry = {
    position={0, 114 - 2 * jumpSpeed},
    size={16, 16},
    state="idle",
    acceleration=0.5,
    maxSpeed=2,
    currentSpeed=0,
    jumpSpeed=jumpSpeed,
    jumpDuration=10,
    direction={0, 0},
    impulse=getDefaultImpulse(),
    weaponDelay=5,
    weaponSpeed=4,
    lastShotFrame=-100
  }
  frame = 0
  gravity = 2.4
  friction = 0.6
  bullets = { }
  cam = {0,0}
end

function _update()
  frame += 1

  perry.state = "idle"

  local direction = {perry.direction[1], 0}
  local movement = {0, 0}

  if btn(0) then
    direction[1] = -1
  end

  if btn(1) then
    direction[1] = 1
  end

  if btn(2) then
    direction[2] = -1
  end

  if btn(3) then
    direction[2] = 1
  end

  if direction[1] == 0 and direction[2] == 0 then
    direction[1] = 1
  end

  perry.direction = direction

  local pos = roundPosition(perry.position)
  perry.position = pos

  local isJumping = perry.impulse.frame + perry.jumpDuration > frame

  local isOnGround = checkMap(
    pos,
    perry.size,
    { 0, 1 },
    BORDER_FLAGS.TOP
  )

  if not isOnGround then
    movement[2] += gravity
  end

  if btn(5) and perry.lastShotFrame + perry.weaponDelay < frame then
    local startX = 9

    if sgn(direction[1]) < 0 then
      startX = 0
    end

    local bullet = {
      direction={ direction[1], direction[2] },
      start={ pos[1] + startX, pos[2] + 7 },
      frame=frame,
      speed=perry.weaponSpeed
    }
    add(bullets, bullet)
    perry.lastShotFrame = frame
  end

  if (btnp(4) and not isJumping and isOnGround) then
    perry.impulse = {
      frame=frame,
      start={ perry.position[1], perry.position[2] },
      speed=perry.jumpSpeed
    }
  end

  if isJumping then
    local jumpProgress = (
      frame - perry.impulse.frame
    ) / perry.jumpDuration

    local jumpProgressPrev = max(
      0,
      (frame -  1 - perry.impulse.frame) / perry.jumpDuration
    )

    perry.jumpProgress = jumpProgress

    movement[2] = -perry.jumpSpeed * (
      easeJump(jumpProgress) - easeJump(jumpProgressPrev)
    )
  end

  perry.currentSpeed *= friction
  if btn(0) then
    perry.currentSpeed -= perry.acceleration
  end

  if btn(1) then
    perry.currentSpeed += perry.acceleration
  end

  perry.currentSpeed = mid(
    -perry.maxSpeed,
    perry.currentSpeed,
    perry.maxSpeed
  )

  if (abs(perry.currentSpeed) < 0.1) then
    perry.currentSpeed = 0
  end

  movement[1] = perry.currentSpeed

  if not btn(0) and not btn(1) and abs(perry.currentSpeed) > 0.01 then
    perry.state = "sliding"
  end

  if (btn(0) or btn(1)) and abs(perry.currentSpeed) > 0.01 then
    perry.state = "running"
  end

  if isJumping then
    perry.state = "jumping"
  end

  local newPos = { pos[1], pos[2] }
  local hDir = sgn(movement[1])
  local vDir = sgn(movement[2])

  for i = 0, movement[1], hDir do
    if movement[1] == 0 then
      break
    end

    local flag = BORDER_FLAGS.LEFT

    if (hDir > 0) then
      flag = BORDER_FLAGS.RIGHT
    end

    local didCollide = checkMap(
      newPos,
      perry.size,
      { hDir, 0 },
      flag
    )

    if didCollide then
      perry.currentSpeed = 0
      break
    end

    newX = newPos[1] + hDir

    if newX < 0 or newX > WORLD_X - perry.size[1] then
      perry.currentSpeed = 0
    end


    newX = max(0, newX)
    newX = min(WORLD_X - perry.size[1], newX)
    newPos = { newX, newPos[2] }
  end

  for j = 0, movement[2], vDir do
    if movement[2] == 0 then
      break
    end

    local flag = BORDER_FLAGS.TOP

    if (vDir < 0) then
      flag = BORDER_FLAGS.DOWN
    end

    local didCollide = checkMap(
      newPos,
      perry.size,
      { 0, vDir },
      flag
    )

    if didCollide and vDir < 0 then
      perry.impulse = getDefaultImpulse()
      break
    end

    if didCollide then
      break
    end

    newPos = { newPos[1], newPos[2] + vDir }
  end

  perry.position = newPos

  for bullet in all(bullets) do
    local frames = frame - bullet.frame

    progress = flr(frames * bullet.speed)
    bullet.position = {
      bullet.start[1] +
      progress * bullet.direction[1] +
      bullet.direction[1],
      bullet.start[2] +
      progress * bullet.direction[2] +
      bullet.direction[2]
    }

    if (
      bullet.position[1] > WORLD_X or
      bullet.position[2] > WORLD_X or
      bullet.position[1] < 0 or
      bullet.position[2] < 0
    ) then
      bullet.isRemoved = true
    end

  end

  bullets = filter(bullets, isNotRemoved)
  camX = perry.position[1] - 64 - perry.size[1] / 2
  camX = max(0, camX)
  camX = min(WORLD_X - SCREEN_X, camX)
  cam = { camX, 0 }
end

function _draw()
  cls()
  map(0, 0, 0, 0)

  print(debug, cam[1], cam[2])
  local perrySprite = mod(flr(frame / 10), 2)

  if perry.state == "jumping" and perry.jumpProgress < 0.3 then
    perrySprite = 2
  end

  if perry.state == "jumping" and perry.jumpProgress >= 0.3 then
    perrySprite = 3
  end

  if perry.state == "running" then
    perrySprite = 5
  end

  local hasShotRecently = false
  if #bullets > 0 then
    if frame - bullets[#bullets].frame < 6 then
      hasShotRecently = true
    end
  end

  if perry.state == "running" and hasShotRecently then
    perrySprite = 4
  end

  if perry.state == "idle" and hasShotRecently then
    perrySprite = 6
  end

  spr(
    16 + 2 * perrySprite,
    perry.position[1],
    perry.position[2],
    2,
    2,
    sgn(perry.direction[1]) == -1
  )

  for bullet in all(bullets) do
    spr(2, bullet.position[1], bullet.position[2])
  end

  camera(cam[1], cam[2])
end


function mod(x, base)
  return x - flr(x / base) * base
end

function easeJump(progress)
  local u0 = 0
  local u1 = 0.75
  local u2 = 0.95
  local u3 = 1
  return (
    u0 * (1 - progress) ^ 3 +
    u1 * 3 * progress * (1 - progress) ^ 2 +
    u2 * 3 * progress ^ 2 * (1 - progress) +
    u3 * progress ^ 3
  )
end

function roundPosition(pos)
  return {
    flr(pos[1] + 0.5),
    flr(pos[2] + 0.5)
  }
end

function filter(arr, func)
  local newArr = {}
  for oldIndex, v in pairs(arr) do
    if func(v, oldIndex) then
      add(newArr, v)
    end
  end
  return newArr
end

function isNotRemoved(v)
  return not v.isRemoved
end

function drawCheckMap(position, size, direction, flag)
  local x = position[1]
  local y = position[2]
  local w = size[1]
  local h = size[2]

  local x1 = 0
  local x2 = 0
  local y1 = 0
  local y2 = 0

  if direction[1] < 0 then
    x1 = x - 1
    y1 = y
    x2 = x
    y2 = y + h - 1
  end

  if direction[1] > 0 then
    x1 = x + w - 1
    y1 = y
    x2 = x + w
    y2 = y + h - 1
  end

  if direction[2] < 0 then
    x1 = x + sgn(direction[1])
    y1 = y - 1
    x2 = x + w - sgn(direction[1])
    y2 = y
  end

  if direction[2] > 0 then
    x1 = x + sgn(direction[1])
    y1 = y + h
    x2 = x + w - sgn(direction[1])
    y2 = y + h
  end

  rect(x1, y1, x2, y2, 5)

  local xs = { x1 }
  local ys = { y1 }

  while xs[#xs] < x2 do
    local last = xs[#xs]
    add(xs, last + min(8, x2 - last))
  end

  while ys[#ys] < y2 do
    local last = ys[#ys]
    add(ys, last + min(8, y2 - last))
  end


  for xx in all(xs) do
    for yy in all(ys) do
      mapx = xx / 8
      mapy = yy / 8
      if fget(mget(mapx, mapy), flag) then
        rect(xx - 1, yy - 1, xx + 1, yy + 1, 9)
      end
    end
  end
end

function checkMap(position, size, direction, flag)
  local x = position[1]
  local y = position[2]
  local w = size[1]
  local h = size[2]

  local x1 = 0
  local x2 = 0
  local y1 = 0
  local y2 = 0

  if direction[1] < 0 then
    x1 = x - 1
    y1 = y
    x2 = x
    y2 = y + h - 1
  end

  if direction[1] > 0 then
    x1 = x + w - 1
    y1 = y
    x2 = x + w
    y2 = y + h - 1
  end

  if direction[2] < 0 then
    x1 = x + sgn(direction[1])
    y1 = y - 1
    x2 = x + w - sgn(direction[1])
    y2 = y
  end

  if direction[2] > 0 then
    x1 = x + sgn(direction[1])
    y1 = y + h
    x2 = x + w - sgn(direction[1])
    y2 = y + h
  end

  local xs = { x1 }
  local ys = { y1 }

  while xs[#xs] < x2 do
    local last = xs[#xs]
    add(xs, last + min(8, x2 - last))
  end

  while ys[#ys] < y2 do
    local last = ys[#ys]
    add(ys, last + min(8, y2 - last))
  end

  for xx in all(xs) do
    for yy in all(ys) do
      mapx = xx / 8
      mapy = yy / 8
      if fget(mget(mapx, mapy), flag) then
        return true
      end
    end
  end

  return false
end


function getDefaultImpulse()
  return {
    frame=-1000,
    start={0, 0},
    direction={0, 0},
    speed=0
  }
end

function ceil(v)
  return flr(v + 0.9999999999)
end

__gfx__
77777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70077007700770070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70707707700700070008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70077007707777070088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70077007700770070008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70700707707007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000007700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000b2b0000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000007bbb7000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000007777700d000000000000000000000000000000000000000000000000000000000000000000000
000b22b00000000000000000000000000000000000000000000777770ddd00000000222200000000000022220000000000000000000000000000000000000000
007bbbb700000000000b22b000000000000b22b00000000000222222222222000002222220000000000222222000000000022220000000000000000000000000
00777777000dd000007bbbb700000000007bbbb70000000002220070707002200007777bb000dd000007777bb000dd00002777b2000000000000000000000000
0077777700dddd0000777777000dd00000777777000dd000022200707070022000022222200dddd000022222200dddd0007777bb000dd0000000000000000000
02222222222222200077777700dddd000077777700dddd000220000000000020002222222222222200222222222222220077777700dddd000000000000000000
22222222222222220222222222222220022222222222222002207000000070200222222222222222022222222222222202222222222222200000000000000000
22220070707002222222222222222222222222222222222202222222222222202222222222222222222220070707002222222222222222220000000000000000
22207000000070222222007070700222222200707070022202020d000d0d02002222222222222002222207000000070222222222222200000000000000000000
22207070707070222220700000007022222070000000702202020d000d0d02002222222222222002222207070707070222222222222200000000000000000000
022222222222222022207070707070222220707070707022002020d0d0d020000222222222222222022222222222222222222222222222220000000000000000
002020d00d0d020002222222222222200222222222222220000000000000000002020d000d0d020002020d000d0d020002222222222222200000000000000000
02020d0000d0d020002020d00d0d0200000000000000000000000000000000002020d000d0d020002020d000d0d0200002020d0000d0d0200000000000000000
02020d0000d0d02022020d0000d0d02200000000000000000000000000000000020d000d0d020000020d000d0d0200002020d000000d0d020000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b3b3b3b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
7070707070707070707070707070707000707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000414141410000000000000000000000000040404040000000000000000000000000404040400000000000000000000000004040404000000000000000000000000040404040000000000000000000000000404040400000000000000000000000004040404000000000000000000000404040400000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000707000000000000000000000000000000070700000000000000000000000000070707000000000000000000000000000007070000000000000000000000000007070700000000000000000000000000000707000000000000000000000000000707070000000000000000000000000707070000000000000000000
0000000000000000404040000000000000000000000000000040404000000000000000000000000000404040000000000000000000000000004040400000000000000000000000000040404000000000000000000070700000404040000000000000000000007070004040400000000000000070707000404040000000000000
0000000000004040404000000000000000000000000000404040400000000000000000000000004040404000000000000000000000000040404040000000000000000000000000404040400000000000000000000000004040404000000000000000000000000040404040000000000000000000004040404000000000000000
4040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070707070707070707070000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070707070707070707070000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070700000000000000000
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001807518055180251801500000000000f0000f0000f0750f0550f0250f0150f0000000000000000001f0751f0551f0351f0251f0150000000000000000000000000000000000000000000000000000000
011000000c053000000c00324605286250c0030c053000000c053000000000024605286250000000000000000c053000000000028635286050000000000000000000000000000000000028635000000000000000
01100000183221c3221e322213221b3221c3221c3221c3221833218332183320f3310f3320f3320f3320000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 01020344

