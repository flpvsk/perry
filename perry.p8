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
0000000000000000000000000000000000000000000000000000b2b0000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000007bbb7000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000007777700d000000000000000000000000000000000000000000000000000000000000000000000
000b22b00000000000000000000000000000000000000000000777770ddd00000000222200000000000022220000000000000000000000000000000000000000
007bbbb700000000000b22b000000000000000000000000000222222222222000002222220000000000222222000000000000000000000000000000000000000
00777777000dd000007bbbb700000000000222200000000002220070707002200007777bb000dd000007777bb000dd0000000000000000000000000000000000
0077777700dddd0000777777000dd0000022222200000000022200707070022000022222200dddd000022222200dddd000000000000000000000000000000000
02222222222222200077777700dddd0000222222000dd00002200000000000200022222222222222002222222222222200000000000000000000000000000000
222222222222222202222222222222200022222200dddd0002207000000070200222222222222222022222222222222200000000000000000000000000000000
22220070707002222222222222222222022222222222222002222222222222202222200707070022222222222222202200000000000000000000000000000000
22207000000070222222007070700222222222222222222202020d000d0d02002222070000000702222222222227000200000000000000000000000000000000
22207070707070222220700000007022222222222222222202020d000d0d02002222070707070702222222222207000200000000000000000000000000000000
022222222222222022207070707070222222722222227222002020d0d0d020000222222222222222022222222222222200000000000000000000000000000000
002020d00d0d020002222222222222202220707070707022000000000000000002020d000d0d020002020d000d0d020000000000000000000000000000000000
02020d0000d0d020002020d00d0d0200022222222222222000000000000000002020d000d0d020002020d000d0d0200000000000000000000000000000000000
02020d0000d0d02022020d0000d0d022202020d00d0d02020000000000000000020d000d0d020000020d000d0d02000000000000000000000000000000000000
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
33333333666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b3b3b3b666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
444444446666666600000000000000000000000000000000000000000000000000000000000000cccc0000000000000000000000000000000000000000000000
444444446666666600000000000000000000000000000000000000000000000000000000000cccccccc000000000000000000000000000cccc00000000000000
44444444666666660000000000000000000000000000000000000000000000000000000000000ffffff000000000000000000000000cccccccc0000000000000
4444444466666666000000000000000000000000000000000000000000000000000000000000ffffffff0000000000000000000000000ffffff0000000000000
44444444666666660000000000000000000000000000000000000000000000000000000000000f0ff0f0000000000000000000000000ffffffff000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000ffffff00000000000000000000000000f0ff0f0000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000fffff00000000000000000000000000ffffff0000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000000000fffff0000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000ff000000000000000000000000000000ff00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000eeeee000000000000000000000000000ff00000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000eeeeeeee0000000000000000000000000eeee000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000eff8e88ee00000000000000000000000eeeeeeee000000000
0000000000000000000000000000000000000000000000000000000000000000000008080f0000e8fff888ee00000000000000000000000eeeeeeeee00000000
0000000000000000000000000000000000000000000000000000000000000000000088888ff888888fff888e00000000000000000000000e888e88ee00000000
0000000000000000000000000000000000000000000000000000000000000000000088888ff8888888ffffff00000000000008080000f0e8888fffff00000000
0000000000000000000000000000000000000000000000000000000000000000000008080ff000088888ffff00000000000088888888ff8888ffffff00000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000e888e880000000000000088888888ff888fff888000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000ccccccc0000000000000008080000ff08fff8888000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc0000000000000000000000000eff8e880000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc0000000000000000000000000ccccccc0000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc00000000000000000000000000cccccc0000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc0000000000000000000000000ccc00ccc000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc000000000000000000000000ccc0000ccc00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc00000000000000000000000ccc000000ccc0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc000000000000000000000000ccc0000ccc00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc0000000000000000000000000ccc00ccc000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc00000000000000000000000000cc00cc0000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000002220022200000000000000000000000022200222000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000222020020222000000000000000000002220200202220000000
66666666cccccccc001111cc666666666666666e6666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc001111cc66666eee66ee6666666eee6600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc001111cc6eee6e666eee6ee666eeee6600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc001111cc6e6e6e666e6e6eee66eeee6600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc22ddddee6e6e6e666e6e6e6e66eee66600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc22ddddee6e6e6e666e6e6e6e666ee66600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc22ddddee6e6e6e666e6e6e6e666e666600000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666cccccccc22ddddee6e6e6e666e6e6e6e6666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006eee6ee66eee6eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006e6e66eeee6e6ee60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006e6e666e6e6e6e6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006e6ee66e666e6e6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006e66e66e666e6e6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555cccccccc000000006666e66e6e6e6eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555000000006e66e66e666e6e660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000066e6e66666666e660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
9191919191919191919191919191919100707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707070707000
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808384808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080809394858080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808085808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9090909090909090909090909090909000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
