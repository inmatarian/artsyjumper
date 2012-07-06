
floor, abs = math.floor, math.abs
sign = function(x) return (x<0) and -1 or 1 end
NULLFUNC = function() return end

----------------------------------------

require 'object'
require 'util'
require 'graphics'
require 'input'
require 'sound'
require 'statemachine'
require 'gametexts'
require 'levelmaps'

----------------------------------------

debugMode = {
  enabled = false,
  dt = 1,
  fps = 0,
  garbage = 0,
  x = 0, y = 0, j = 0, f = "--", coll = 0,
  toggle = function(self)
    self.enabled = not self.enabled
    print("debugMode", self.enabled)
  end,
  draw = function(self, dt)
    if self.enabled then
      self.dt = self.dt - dt
      if self.dt <= 0 then
        self.fps = love.timer.getFPS()
        self.garbage = collectgarbage("count")
        self.dt = self.dt + 1
      end
      Graphics:write( 4, 4, Color.BLUE, "fps:%i mem:%ik\nx:%.01f y:%.01f f:%s\nc:%i",
        self.fps, self.garbage, self.x, self.y, tostring(self.f), self.coll )
    end
  end
}

----------------------------------------

TextBlock = Object:clone()

function TextBlock:init( x, y, color, str, ... )
  self.block = {}
  str = Util.reflow(str:format(...), 19)
  local lines, ly = 0, 0
  for line in str:gmatch("[^\r\n]+") do
    local lx = (x == "center") and floor((Graphics.gameWidth/2)-(line:len()*4)) or x
    table.insert( self.block, { x=lx, y=ly, c=color, t=line } )
    ly = ly + Graphics.fontHeight + 2
    lines = lines + 1
  end
  if y == "center" then
    y = floor((Graphics.gameHeight-(Graphics.fontHeight+2)*lines)/2)
  end
  for _, v in ipairs(self.block) do v.y = v.y + y end
end

function TextBlock:draw(dt)
  for i = 1, #self.block do
    local line = self.block[i]
    Graphics:write( line.x, line.y, line.c, line.t )
  end
end

----------------------------------------

MeterDisplay = Object:clone {
  text = ""
}

function MeterDisplay:init( x, y, color, text, ... )
  self.x, self.y = x, y
  self.color = color or Color.WHITE
  if text then self.text = Util.reflow(text:format(...), 19) end
  self.clock = 0
end

function MeterDisplay:refresh( text, ... )
  if text then self.text = Util.reflow(text:format(...), 19) end
  self.clock = 3
end

function MeterDisplay:draw(dt)
  if self.clock > 0 then
    self.clock = self.clock - dt
    Graphics:write( self.x, self.y, self.color, self.text )
  end
end

----------------------------------------

CallbackTimer = Object:clone()

function CallbackTimer:init( time, object, callback )
  self.time = time
  self.object = object
  self.callback = callback
  self.enabled = true
end

function CallbackTimer:update(dt)
  if self.enabled then
    self.time = self.time - dt
    if self.time <= 0 then
      self.callback(self.object)
      self.enabled = false
    end
  end
end

----------------------------------------

Sprite = Object:clone {
  x = 0, y = 0,
  width = 4, height = 4,
  anim = { frame = { 0 }, time = { 0 } },
  animClock = 0, animCurrent = 1,
  frame = 0, flipped = false, upsideDown = false,
}

function Sprite:init( x, y, parent )
  self.parent = parent
  self.x = x or self.x
  self.y = y or self.y
end

function Sprite:touches( other )
  local x1 = self.x + 1
  local y1 = self.y + 1
  local w1 = self.width - 2
  local h1 = self.height - 2
  local x2 = other.x + 1
  local y2 = other.y + 1
  local w2 = other.width - 2
  local h2 = other.height - 2
  return Util.rectOverlaps( x1, y1, w1, h1, x2, y2, w2, h2 )
end

function Sprite:updateAnimations(dt)
  self.animClock = self.animClock - dt
  if self.animClock <= 0 then
    self.animCurrent = (self.animCurrent % #self.anim.frame) + 1
    self.frame = self.anim.frame[self.animCurrent]
    self.animClock = self.animClock + self.anim.time[self.animCurrent]
  end
end

function Sprite:draw(dt)
  self:updateAnimations(dt)
  if self.parent:isVisible(self) then
    local ox, oy = self.parent:visibilityOffset()
    local x, y = floor(self.x-ox), floor(self.y-oy)
    Graphics:drawTile( x, y, self.frame, Color.PUREWHITE, self.flipped, self.upsideDown )
    if debugMode.enabled then
      love.graphics.rectangle("line", x, y, self.width, self.height)
    end
  end
end

function Sprite:setAnim( anm )
  if anm ~= self.anim then
    self.anim = anm
    self.animCurrent = 1
    self.animClock = self.anim.time[self.animCurrent]
    self.frame = self.anim.frame[1]
  end
end

function Sprite:die()
  self.parent:removeSprite(self)
end

function Sprite:handleTouched() end
function Sprite:update(dt) end

----------------------------------------

Mobile = Sprite:clone {
  jump = 0, jumpHeight = 152,
  gravity = 640, speed = 96, terminalVelocity = 256,
  tangible = true, hurts = false
}

function Mobile:init( x, y, parent )
  self.dx = 0
  self.dy = 0
  if self.stillAnim then self.anim = self.stillAnim end
  Mobile:superinit(self, x, y, parent)
end

function Mobile:center()
  return self.x + floor(self.width / 2), self.y + floor(self.height / 2)
end

function Mobile:applyPhysics(dt)
  local newX, newY = self.x, self.y
  self.jump = self.jump + dt

  newX = newX + self.dx*dt
  if (floor(newX) ~= floor(self.x)) and self.tangible then
    local dir = sign(newX-self.x)
    for tx = floor(self.x+dir), floor(newX), dir do
      if self.parent:mapCollisionAt( tx, newY, self.width, self.height ) then
        newX = tx - dir
        self.dx = 0
        break
      end
    end
  end

  newY = newY + self.dy*dt
  if (floor(newY) ~= floor(self.y)) and self.tangible then
    local dir = sign(newY-self.y)
    for ty = floor(self.y+dir), floor(newY), dir do
      if self.parent:mapCollisionAt( newX, ty, self.width, self.height ) then
        newY = ty - dir
        if dir == sign(self.gravity) then
          self.dy = 0
          self.jump = 0
          self.onFloor = true
        else
          self.dy = self.dy * 0.75 * dt/60
        end
        break
      end
    end
  end

  self.x, self.y = newX, newY

  if self.dy > self.terminalVelocity then self.dy = self.terminalVelocity
  elseif self.dy < -self.terminalVelocity then self.dy = -self.terminalVelocity end

  if self.jump > 0.1 then self.onFloor = false end

  if self.tangible then
    self.dx = self.dx * ((self.onFloor) and 0.25 or 0.5) * dt/60
    self.dy = self.dy + self.gravity*dt
  else
    self.dx = self.dx * 0.5 * dt/60
    self.dy = self.dy * 0.5 * dt/60
  end
end


function Mobile:update(dt)
  self:applyPhysics(dt)
end

function Mobile:doJump()
  if self.onFloor then
    self.dy = -self.jumpHeight
    self.onFloor = false
    return true
  end
  return false
end

function Mobile:flipGravity()
  self.upsideDown = not self.upsideDown
  self.gravity = -1 * self.gravity
  self.jumpHeight = -1 * self.jumpHeight
end

----------------------------------------

MobileActor = Mobile:clone {
  walk = 0, fly = 0
}

function MobileActor:init(...)
  self.thread = coroutine.wrap( self.run )
  self.anim = self.stillAnim or self.anim
  MobileActor:superinit(self, ...)
end

function MobileActor:update(dt)
  self.thread(self, dt)
  if self.walk ~= 0 then
    self.dx = self.walk
  end
  if self.fly ~= 0 then
    self.dy = self.fly
  end
  MobileActor:super().update(self, dt)
end

function MobileActor:wait( seconds )
  repeat
    local _, dt = coroutine.yield(true)
    seconds = seconds - dt
  until seconds <= 0
end

function MobileActor:doWalk( dir, dir2, seconds )
  if (not seconds) then
   if type(dir2)=="number" then
      seconds, dir2 = dir2, nil
    else
      seconds = 0.5
    end
  end

  if dir ~= "I" then
    local animToSet = self.movingAnim or self.stillAnim
    if animToSet then self:setAnim( animToSet ) end
    local hdir, vdir = dir, dir2 or dir
    if hdir == "T" then
      local pl = self.parent.player
      local dx, dy = pl.x - self.x, pl.y - self.y
      local ax, ay = abs(dx), abs(dy)
      hdir = (((dx < 0) and "W") or (dx > 0 and "E")) or "I"
      vdir = (((dy < 0) and "N") or (dy > 0 and "S")) or "I"
      if ax > (ay * 2) then vdir = "I"
      elseif ay > (ax * 2) then hdir = "I" end
    end
    if hdir == "W" then
      self.walk = -self.speed
      self.flipped = true
    elseif hdir == "E" then
      self.walk = self.speed
      self.flipped = false
    end
    if vdir == "N" then
      self.fly = -self.speed
    elseif vdir == "S" then
      self.fly = self.speed
    end
  end
  self:wait( seconds )
  self.walk, self.fly = 0, 0
  if self.stillAnim then self:setAnim( self.stillAnim ) end
end

function MobileActor:run()
  while true do
    self:wait(1)
  end
end

----------------------------------------

Enemy = MobileActor:clone {
  hurts = true
}

function Enemy:handleTouched()
  self.parent:restartLevel()
end

----------------------------------------

BobEnemy = Enemy:clone {
  stillAnim = { frame = { "bobOne" }, time = { 0 } },
  movingAnim = { frame = { "bobOne", "bobTwo" }, time = { 0.1, 0.1 } },
}

function BobEnemy:run()
  while true do
    self:wait(2.5)
    self:doJump()
    self:doWalk( Util.randomPick( "I", "W", "E" ), 0.5 )
  end
end

----------------------------------------

LolEnemy = Enemy:clone {
  gravity = 0, tangible = false,
  width = 20, height = 7,
  stillAnim = { frame = { "lol" }, time = { 0 } },
}

RoflEnemy = Enemy:clone {
  gravity = 0, tangible = false,
  width = 27, height = 7,
  stillAnim = { frame = { "rofl" }, time = { 0 } },
}

----------------------------------------

VVVVVVEnemy = Enemy:clone {
  width = 8, height = 13,
  speed = math.floor(Enemy.speed / 2),
  stillAnim = { frame = { "vvvvvvOne" }, time = { 0 } },
  movingAnim = { frame = { "vvvvvvOne", "vvvvvvTwo" }, time = { 0.1, 0.1 } },
}

function VVVVVVEnemy:run()
  while true do
    self:wait(1)
    if math.random(1, 4)==1 then
      self:flipGravity()
    else
      self:doWalk( Util.randomPick("W", "E"), 0.5 )
    end
  end
end

----------------------------------------

EyeEnemy = Enemy:clone {
  width = 8, height = 12,
  stillAnim = { frame = { "eye" }, time = { 0 } },
  speed = math.floor(Enemy.speed / 3),
  gravity = 0, tangible = false
}

function EyeEnemy:run()
  local pl = self.parent.player
  while true do
    local dir = (pl.x < self.x) and "W" or "E"
    if math.random(1, 9)==1 then dir = Util.randomPick( "W", "E" ) end
    for i = 1, 4 do
      self:doWalk( dir, 0.35 )
      self:doWalk( dir, "N", 0.35 )
      self:doWalk( dir, 0.35 )
      self:doWalk( dir, "S", 0.35 )
    end
  end
end

----------------------------------------

DragonEnemy = Enemy:clone {
  gravity = 0, tangible = false,
  width = 10, height = 20,
  speed = math.floor(Enemy.speed / 2),
  stillAnim = { frame = { "dragon" }, time = { 0 } },
}

function DragonEnemy:run()
  local dir
  while true do
    self:wait(1)
    if math.random(1, 9)~=1 then
      dir = "T"
    else
      dir = Util.randomPick("N", "S", "W", "E")
    end
    self:doWalk( dir, 2 )
  end
end

----------------------------------------

Player = Mobile:clone {
  width = 6, height = 12,
  holdingMove = false
}

function Player:init( x, y, level, parent )
  local p1, p2
  if level == 14 then
    p1, p2 = "playerSeven", "playerEight"
  elseif (level >= 10) and (level < 14) then
    p1, p2 = "playerFive", "playerSix"
  elseif (level >= 7 ) and (level < 10) then
    p1, p2 = "playerThree", "playerFour"
  else
    p1, p2 = "playerOne", "playerTwo"
  end
  self.stillAnim = { frame = { p1 }, time = { 0 } }
  self.movingAnim = { frame = { p1, p2 }, time = { 0.1, 0.1 } }
  Player:superinit( self, x, y, parent )
end

function Player:update(dt)
  if Input.hold.jump then
    if self:doJump() then
      self.parent:sfxJump()
    end
  end
  if self.dy < 0 and not Input.hold.jump then self.dy = self.dy * 0.25 end

  if Input.tap.left or Input.tap.right then
    self.holdingMove = true
    self:setAnim( self.movingAnim )
  elseif self.holdingMove and not (Input.hold.left or Input.hold.right) then
    self.holdingMove = false
    self:setAnim( self.stillAnim )
  end

  if Input.hold.left and not Input.hold.right then
    self.dx = -self.speed
  elseif Input.hold.right and not Input.hold.left then
    self.dx = self.speed
  end

  self.flipped = (self.dx < 0)

  Player:super().update(self, dt)

  debugMode.x, debugMode.y = self.x, self.y
  debugMode.f = self.onFloor
end

----------------------------------------

PlayerDeath = MobileActor:clone {
  tangible = false, hurts = false, speed = 80
}

PlayerDeath.animStyle = {
  boom = {
    frame = { "deathBoomOne", "deathBoomTwo", "deathBoomThree", "deathBoomFour", 0 },
    time = { 0.1, 0.1, 0.1, 0.1, 1000 }
  },
  flash = {
    frame = { "deathFlashOne", "deathFlashTwo", "deathFlashThree", "deathFlashFour" },
    time = { 0.25, 0.25, 0.25, 0.25 }
  }
}

PlayerDeath.moveDir = {
  {"N"}, {"E","N"}, {"E"}, {"E","S"}, {"S"}, {"W","S"}, {"W"}, {"W","N"}
}

function PlayerDeath:init( x, y, option, parent )
  local style = (option == 0) and self.animStyle.boom or self.animStyle.flash
  self:setAnim(style)
  self.option = option
  if option >= 1 and option <= #self.moveDir then
    if #self.moveDir[option]==2 then
      self.speed = self.speed * 0.707106781
    end
  end
  PlayerDeath:superinit(self, x, y, parent)
end

function PlayerDeath:run()
  if self.option >= 1 then
    local d = self.moveDir[self.option]
    self:doWalk( d[1], d[2], 0.5 )
    self.hurts = true
    self:doWalk( d[1], d[2], 1.5 )
  else
    self:wait(0.5)
  end
  self:die()
  self:wait(1)
end

function PlayerDeath:handleTouched()
  if self.hurts then
    self.parent:restartLevel()
    self.parent.doubleKilledDisplay:refresh()
  end
end

----------------------------------------

Collectable = Sprite:clone {
  width = 8, height = 8,
  anim = { frame = {"coinOne", "coinTwo", "coinThree", "coinFour"},
           time = {0.1, 0.1, 0.1, 0.1} }
}

function Collectable:init( x, y, parent )
  self.anim = self.anim
  Collectable:superinit( self, x, y, parent )
end

function Collectable:handleTouched()
  self.parent:collectedCoin()
  self:die()
end

----------------------------------------

PlayState = State:clone {
  offsetX = 0, offsetY = 0,
}

function PlayState:init( mapNum )
  self.mapNum = mapNum
  self.deathDisplay = MeterDisplay( 4, 4, Color.RED )
  self.coinDisplay = MeterDisplay( 4, 12, Color.GREEN )
  self.doubleKilledDisplay = MeterDisplay( "center", "center", Color.BLUE, "wtf is wrong\nwith you?" )
  self.timers = {}
  self.spritesToRemove = {}
end

function PlayState:enter()
  self:parseMap( LevelMap[self.mapNum] )
  if self.mapNum == 1 then Game.deaths, Game.coins = 0, 0 end
end

function PlayState:placeObject( ch, x, y )
  if (ch == '#') or (ch == ' ') or (ch == '\n') then return ch end
  if ch == '@' then
    self.playerX, self.playerY = x, y
    self.player = Player(self.playerX, self.playerY, self.mapNum, self)
    return ' '
  end
  local spriteToAdd
  if ch == '$' then
    self.coins = self.coins + 1
    spriteToAdd = Collectable
  elseif ch == 'B' then
    spriteToAdd = BobEnemy
  elseif ch == 'R' then
    spriteToAdd = RoflEnemy
  elseif ch == 'L' then
    spriteToAdd = LolEnemy
  elseif ch == 'V' then
    spriteToAdd = VVVVVVEnemy
  elseif ch == 'E' then
    spriteToAdd = EyeEnemy
  elseif ch == 'D' then
    spriteToAdd = DragonEnemy
  end
  if spriteToAdd then
    x = floor((x+4) - spriteToAdd.width/2)
    y = floor((y+4) - spriteToAdd.height/2)
    table.insert(self.sprites, spriteToAdd(x, y, self))
  end
  return ' '
end

function PlayState:parseMap( map )
  self.map = {}
  self.player = nil
  self.sprites = {}
  self.coins = 0

  local levelTile = 1
  if self.mapNum > 10 and self.mapNum < 14 then levelTile = 2
  elseif self.mapNum == 14 then levelTile = 3 end

  local x, y = 1, 1
  for ch in map:gmatch(".") do
    ch = self:placeObject( ch, (x-1)*8, (y-1)*8 )
    if ch == "\n" then
      if x > 1 then x, y = 1, y + 1 end
    else
      local row = self.map[y] or {}
      row[x] = ((ch==' ') and 0) or levelTile
      self.map[y] = row
      x = x + 1
    end
  end
end

function PlayState:getTile( x, y )
  local row = self.map[y+1]
  if (not row) or (not row[x+1]) then return 0 end
  return row[x+1]
end

function PlayState:blockedAt( x, y )
  return (self:getTile( x, y ) ~= 0)
end

function PlayState:mapCollisionAt( x, y, w, h )
  local y1, y2 = floor(y/8), floor((y+h-1)/8)
  local x1, x2 = floor(x/8), floor((x+w-1)/8)
  for ty = y1, y2 do
    for tx = x1, x2 do
      self.collisionCount = (self.collisionCount or 0) + 1
      if self:blockedAt(tx, ty) then return true end
    end
  end
  return false
end

function PlayState:update(dt)
  if Input.tap.r then
    self:restartLevel()
  elseif Input.tap.n then
    self:handleStopTimer()
    return
  end

  self:runFrame(dt)
end

function PlayState:runFrame(dt)
  for i = 1, #self.timers do
    self.timers[i]:update(dt)
  end
  for i = #self.timers, 1, -1 do
    if not self.timers[i].enabled then table.remove(self.timers, i) end
  end

  for _, sprite in ipairs(self.sprites) do
    sprite:update(dt)
  end

  if not self.restarting then
    self.player:update(dt)
  end

  local x, y = self.player:center()
  self.offsetX = floor( x / Graphics.gameWidth ) * Graphics.gameWidth
  self.offsetY = floor( y / Graphics.gameHeight ) * Graphics.gameHeight

  if not self.restarting then
    for _, sprite in ipairs(self.sprites) do
      if self.player:touches(sprite) then
        sprite:handleTouched()
      end
    end
  end

  for i = #self.spritesToRemove, 1, -1 do
    local spr = table.remove(self.spritesToRemove)
    for i = #self.sprites, 1, -1 do
      if self.sprites[i]==spr then table.remove(self.sprites, i) end
    end
  end

  self.collisionCountDt = (self.collisionCountDt or 0) + dt
  if self.collisionCountDt > 1 then
    debugMode.coll = self.collisionCount
    self.collisionCountDt = self.collisionCountDt - 1
    self.collisionCount = 0
  end
end

function PlayState:restartLevel()
  if not self.restarting then
    self:sfxDeath()
    Game.deaths = Game.deaths + 1
    self.deathDisplay:refresh("%i", Game.deaths)
    table.insert(self.timers, CallbackTimer( 0.5, self, self.handleRestartTimer ) )
    self.restarting = true
    local x, y = self.player:center()
    if math.random(0,1)==0 then
      table.insert(self.sprites, PlayerDeath(x-3, y-3, 0, self))
    else
      for i = 1, 8 do
        table.insert(self.sprites, PlayerDeath(x-3, y-3, i, self))
      end
    end
  end
end

function PlayState:collectedCoin()
  self:sfxCoin()
  Game.coins = Game.coins + 1
  self.coins = self.coins - 1
  self.coinDisplay:refresh("%i", Game.coins)
  if self.coins == 0 and not self.stopping then
    self.stopping = true
    table.insert(self.timers, CallbackTimer( 1, self, self.handleStopTimer ) )
  end
end

function PlayState:handleRestartTimer()
  self.restarting = false
  self.player.x = self.playerX
  self.player.y = self.playerY
end

function PlayState:handleStopTimer()
  StateMachine:pop()
  StateMachine:push( Game.newNextLevel( self.mapNum ) )
end

function PlayState:draw(dt)
  Graphics:setColor( Color.PUREWHITE )
  Graphics:drawBackdrop( 1+((self.mapNum-1)%#Graphics.backDrops) )
  local ox, oy = self:visibilityOffset()
  ox, oy = floor(ox/8), floor(oy/8)
  for y = 0, 14 do
    for x = 0, 19 do
      local tile = self:getTile(x+ox, y+oy)
      if tile > 0 then
        Graphics:drawTile(x*8, y*8, tile, Color.PUREWHITE)
      end
    end
  end
  for _, sprite in ipairs(self.sprites) do
    sprite:draw(dt)
  end
  if not self.restarting then
    self.player:draw(dt)
  end
  self.deathDisplay:draw(dt)
  self.coinDisplay:draw(dt)
  self.doubleKilledDisplay:draw(dt)
end

function PlayState:isVisible( sprite )
  return true
end

function PlayState:visibilityOffset()
  return self.offsetX, self.offsetY
end

function PlayState:removeSprite(spr)
  table.insert(self.spritesToRemove, spr)
end

function PlayState:sfxJump()
  local clip = Util.randomPick(Sound.JUMP1, Sound.JUMP2, Sound.JUMP3)
  Sound:playClip(clip)
end

function PlayState:sfxDeath()
  local clip = Util.randomPick(Sound.DEATH1, Sound.DEATH2)
  Sound:playClip(clip)
end

function PlayState:sfxCoin()
  Sound:playClip(Sound.COIN1)
end

----------------------------------------

TextState = State:clone()

function TextState:init( str, nextState )
  self.str = str
  self.text = TextBlock( "center", "center", Color.WHITE, str )
  self.nextState = nextState
end

function TextState:update(dt)
  if Input.tap.enter or Input.tap.escape or Input.tap.n then
    StateMachine:pop()
    StateMachine:push( self.nextState )
  elseif Input.tap.c then -- cheat mode, get different text
    local nextText = GameTexts.levels[1]
    for i = 2, #GameTexts.levels do
      if self.str == GameTexts.levels[i-1] then
        nextText = GameTexts.levels[i]
        break
      end
    end
    self.str = nextText
    self.text = TextBlock( "center", "center", Color.WHITE, nextText )
  end
end

function TextState:draw(dt)
  self.text:draw(dt)
end

----------------------------------------

Game = {
  deaths = 0, coins = 0
}

function Game.newNextLevel( index )
  local gameText = (index==0) and GameTexts.instructionScreen or GameTexts.levels[index]
  local followingState = (index<#LevelMap) and PlayState(index+1) or Game.newGameOverState()
  return TextState( gameText, followingState )
end

function Game.newTitleState()
  return TextState( GameTexts.titleScreen, Game.newNextLevel(0) )
end

function Game.newGameOverState()
  local d = Game.deaths
  local s = string.format( "%s\n \n \nDIED %i %s",
      GameTexts.gameOverScreen, d, d==1 and "TIME" or "TIMES" )
  return TextState(s, Game.newTitleState())
end

Game.artwork = {
  name = "tileset.png",
  tiles = {
    [1] = { 8, 0, 8, 8 };
    [2] = { 16, 0, 8, 8 };
    [3] = { 24, 0, 8, 8 };
    playerOne = { 0, 244, 7, 12 };
    playerTwo = { 8, 244, 7, 12 };
    playerThree = { 16, 244, 7, 12 };
    playerFour = { 24, 244, 7, 12 };
    playerFive = { 32, 244, 7, 12 };
    playerSix = { 40, 244, 7, 12 };
    playerSeven = { 48, 244, 7, 12 };
    playerEight = { 56, 244, 7, 12 };
    bobOne = { 222, 247, 5, 4 };
    bobTwo = { 222, 252, 5, 4 };
    vvvvvvOne = { 228, 243, 8, 13 };
    vvvvvvTwo = { 237, 243, 8, 13 };
    lol = { 194, 241, 20, 7 };
    rofl = { 194, 249, 27, 7 };
    eye = { 237, 230, 8, 12 };
    dragon = { 246, 236, 10, 20 };
    coinOne = { 0, 8, 8, 8 };
    coinTwo = { 8, 8, 8, 8 };
    coinThree = { 16, 8, 8, 8 };
    coinFour = { 24, 8, 8, 8 };
    deathBoomOne = { 0, 228, 7, 7 };
    deathBoomTwo = { 8, 228, 7, 7 };
    deathBoomThree = { 16, 228, 7, 7 };
    deathBoomFour = { 24, 228, 7, 7 };
    deathFlashOne = { 0, 236, 7, 7 };
    deathFlashTwo = { 8, 236, 7, 7 };
    deathFlashThree = { 16, 236, 7, 7 };
    deathFlashFour = { 24, 236, 7, 7 };
  }
}

----------------------------------------

function love.load()
  Graphics:init( Game.artwork )
  Input:init()
  Sound:init()
  StateMachine:push( Game.newTitleState() )
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  Graphics.deltaTime = dt

  if Input.tap.f10 then
    love.event.quit()
  elseif Input.tap.f3 then
    debugMode:toggle()
  elseif Input.tap.f5 then
    Graphics:setNextScale()
  elseif Input.tap.f2 then
    Graphics:saveScreenshot()
  end

  StateMachine:send( "update", dt )
  Input:update(dt)

  if StateMachine:isEmpty() then
    love.event.quit()
  end
end

function love.draw()
  Graphics:start()
  StateMachine:send( "draw", Graphics.deltaTime )
  debugMode:draw( Graphics.deltaTime )
  Graphics:stop()
end

function love.keypressed(k, u)
  Input:keypressed(k, u)
end

function love.keyreleased(k)
  Input:keyreleased(k)
end

