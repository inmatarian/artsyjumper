
floor, abs = math.floor, math.abs
sign = function(x) return (x<0) and -1 or 1 end
NULLFUNC = function() return end

----------------------------------------

require 'object'
require 'util'
require 'graphics'
require 'input'
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
  str = str:format(...)
  if y == "center" then
    local lines = 0
    for _ in str:gmatch("[^\r\n]+") do lines = lines + 1 end
    y = floor((Graphics.gameHeight-(Graphics.fontHeight+2)*lines)/2)
  end
  for line in str:gmatch("[^\r\n]+") do
    local lx = (x == "center") and floor((Graphics.gameWidth/2)-(line:len()*4)) or x
    table.insert( self.block, { x=lx, y=y, c=color, t=line } )
    y = y + Graphics.fontHeight + 2
  end
end

function TextBlock:draw(dt)
  for i = 1, #self.block do
    local line = self.block[i]
    Graphics:write( line.x, line.y, line.c, line.t )
  end
end

----------------------------------------

MeterDisplay = Object:clone()

function MeterDisplay:init( x, y, color )
  self.x, self.y = x, y
  self.color = color or Color.WHITE
  self.text = ""
  self.clock = 0
end

function MeterDisplay:refresh( text )
  self.text = text
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
  return Util.rectOverlaps( self.x, self.y, self.width, self.height,
      other.x, other.y, other.width, other.height )
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
  tangible = true, hurts = true
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
  end
end


function Mobile:update(dt)
  self:applyPhysics(dt)
end

function Mobile:doJump()
  if self.onFloor then
    self.dy = -self.jumpHeight
    self.onFloor = false
  end
end

function Mobile:flipGravity()
  self.upsideDown = not self.upsideDown
  self.gravity = -1 * self.gravity
  self.jumpHeight = -1 * self.jumpHeight
end

----------------------------------------

Enemy = Mobile:clone {
  walk = 0
}

function Enemy:init(...)
  self.thread = coroutine.wrap( self.run )
  self.anim = self.stillAnim or self.anim
  Enemy:superinit(self, ...)
end

function Enemy:update(dt)
  self.thread(self, dt)
  if self.walk ~= 0 then
    self.dx = self.walk
  end
  Enemy:super().update(self, dt)
end

function Enemy:wait( seconds )
  repeat
    local _, dt = coroutine.yield(true)
    seconds = seconds - dt
  until seconds <= 0
end

function Enemy:doWalk( dir, seconds )
  if dir ~= "I" then
    self:setAnim( self.movingAnim )
    if dir == "W" then
      self.walk = -self.speed
      self.flipped = true
    elseif dir == "E" then
      self.walk = self.speed
      self.flipped = false
    end
  end
  self:wait( seconds )
  self.walk = 0
  self:setAnim( self.stillAnim )
end

function Enemy:run()
  while true do
    self:wait(2.5)
    self:doJump()
    self:doWalk( Util.randomPick( "I", "W", "E" ), 0.5 )
  end
end

function Enemy:handleTouched()
  self.parent:restartLevel()
end

----------------------------------------

BobEnemy = Enemy:clone {
  stillAnim = { frame = { "bobOne" }, time = { 0 } },
  movingAnim = { frame = { "bobOne", "bobTwo" }, time = { 0.1, 0.1 } },
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

Player = Mobile:clone {
  width = 6, height = 12,
  stillAnim = { frame = { "playerOne" }, time = { 0 } },
  movingAnim = { frame = { "playerOne", "playerTwo" }, time = { 0.1, 0.1 } },
  holdingMove = false
}

function Player:update(dt)
  if Input.hold.jump then self:doJump() end
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

PlayerDeath = Mobile:clone {
  tangible = false, hurts = false, speed = 64, style = {}
}

PlayerDeath.style.boom = {
  frame = { "deathBoomOne", "deathBoomTwo", "deathBoomThree", "deathBoomFour", 0 },
  time = { 0.1, 0.1, 0.1, 0.1, 1000 }
}

PlayerDeath.style.flash = {
  frame = { "deathFlashOne", "deathFlashTwo", "deathFlashThree", "deathFlashFour" },
  time = { 0.25, 0.25, 0.25, 0.25 }
}

function PlayerDeath:init( x, y, style, option, parent )
  self:setAnim(self.style[style])
  self.lifeClock = 2
  PlayerDeath:superinit(self, x, y, parent)

  if option > 0 then
    self.dx = self.speed * math.sin( option * math.pi / 4 )
    self.dy = self.speed * math.cos( option * math.pi / 4 )
  end
end

function PlayerDeath:update(dt)
  PlayerDeath:super().update(self, dt)
  self.lifeClock = self.lifeClock - dt
  if self.lifeClock <= 0 then self:die() end
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
  Game.coins = Game.coins + 1
  self.parent.coins = self.parent.coins - 1
  self.parent.coinDisplay:refresh(string.format("%i", Game.coins))
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
    self.player = Player(self.playerX, self.playerY, self)
  elseif ch == '$' then
    table.insert(self.sprites, Collectable(x, y, self))
    self.coins = self.coins + 1
  elseif ch == 'E' then
    table.insert(self.sprites, BobEnemy(x, y, self))
  elseif ch == 'V' then
    table.insert(self.sprites, VVVVVVEnemy(x, y, self))
  end
  return ' '
end

function PlayState:parseMap( map )
  self.map = {}
  self.player = nil
  self.sprites = {}
  self.coins = 0

  local x, y = 1, 1
  for ch in map:gmatch(".") do
    ch = self:placeObject( ch, (x-1)*8, (y-1)*8 )
    if ch == "\n" then
      if x > 1 then x, y = 1, y + 1 end
    else
      local row = self.map[y] or {}
      row[x] = (ch==' ') and 0 or 1
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

  if self.coins == 0 and not self.stopping then
    self.stopping = true
    table.insert(self.timers, CallbackTimer( 1, self, self.handleStopTimer ) )
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
    Game.deaths = Game.deaths + 1
    self.deathDisplay:refresh( string.format("%i", Game.deaths) )
    table.insert(self.timers, CallbackTimer( 0.5, self, self.handleRestartTimer ) )
    self.restarting = true
    local x, y = self.player:center()
    if math.random(0,1)==0 then
      table.insert(self.sprites, PlayerDeath(x-3, y-3, "boom", 0, self))
    else
      for i = 1, 8 do
        table.insert(self.sprites, PlayerDeath(x-3, y-3, "flash", i, self))
      end
    end
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
  Graphics:drawBackdrop()
  local ox, oy = self:visibilityOffset()
  ox, oy = floor(ox/8), floor(oy/8)
  for y = 0, 14 do
    for x = 0, 19 do
      local t = self:getTile(x+ox, y+oy)
      if t==1 then
        Graphics:drawTile(x*8, y*8, 1, Color.PUREWHITE)
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

----------------------------------------

TextState = State:clone()

function TextState:init( text, nextState )
  self.text = TextBlock( "center", "center", Color.WHITE, text )
  self.nextState = nextState
end

function TextState:update(dt)
  if Input.tap.enter or Input.tap.escape then
    StateMachine:pop()
    StateMachine:push( self.nextState )
  end
end

function TextState:draw(dt)
  self.text:draw(dt)
end

----------------------------------------

Game = {
  deaths = 0
}

function Game.newNextLevel( index )
  local followingState
  index = index + 1
  if index < #GameTexts.levels then
    followingState = PlayState(index)
  else
    followingState = Game.newGameOverState()
  end
  return TextState( GameTexts.levels[index], followingState )
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
    playerOne = { 0, 244, 7, 12 };
    playerTwo = { 8, 244, 7, 12 };
    bobOne = { 222, 247, 5, 4 };
    bobTwo = { 222, 252, 5, 4 };
    vvvvvvOne = { 228, 243, 8, 13 };
    vvvvvvTwo = { 237, 243, 8, 13 };
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

