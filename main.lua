
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

Sprite = Object:clone {
  x = 0, y = 0,
  width = 4, height = 4,
  touchX=0, touchY=0, touchW=4, touchH=4
}

function Sprite:init( x, y, parent )
  self.parent = parent
  self.x = x or self.x
  self.y = y or self.y
end

function Sprite:touches( other )
  return Util.rectOverlaps( self.x+self.touchX, self.y+self.touchY,
      self.touchW, self.touchH,
      other.x+other.touchX, other.y+other.touchY,
      other.touchW, other.touchH )
end

----------------------------------------

Mobile = Sprite:clone {
  jump = 0, jumpHeight = 152,
  gravity = 640, speed = 96, terminalVelocity = 256
}

function Mobile:init( x, y, parent )
  self.dx = 0
  self.dy = 0
  Mobile:superinit(self, x, y, parent)
end

function Mobile:center()
  return self.x + floor(self.width / 2), self.y + floor(self.height / 2)
end

function Mobile:applyPhysics(dt)
  local newX, newY = self.x, self.y
  self.jump = self.jump + dt

  newX = newX + self.dx
  if floor(newX) ~= floor(self.x) then
    local dir = sign(newX-self.x)
    for tx = floor(self.x+dir), floor(newX), dir do
      if self.parent:mapCollisionAt( tx+self.touchX, newY+self.touchY,
            self.touchW, self.touchH ) then
        newX = tx - dir
        self.dx = 0
        break
      end
    end
  end

  newY = newY + self.dy*dt
  if floor(newY) ~= floor(self.y) then
    local dir = sign(newY-self.y)
    for ty = floor(self.y+dir), floor(newY), dir do
      if self.parent:mapCollisionAt( newX+self.touchX, ty+self.touchY,
            self.touchW, self.touchH ) then
        newY = ty - dir
        if dir == 1 then
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
  if self.dy > self.terminalVelocity then self.dy = self.terminalVelocity end
  if self.jump > 0.1 then self.onFloor = false end

  self.dx = self.dx * ((self.onFloor) and 0.25 or 0.5) * dt/60
  self.dy = self.dy + self.gravity*dt
end


function Mobile:update(dt)
  self:applyPhysics(dt)
end

function Mobile:draw(dt)
  if self.parent:isVisible(self) then
    local ox, oy = self.parent:visibilityOffset()
    Graphics:setColor( Color.RED )
    love.graphics.rectangle( "fill", floor(self.x-ox), floor(self.y-oy), self.width, self.height )
  end
end

function Mobile:doJump()
  if self.onFloor then
    self.dy = -self.jumpHeight
    self.onFloor = false
  end
end

----------------------------------------

Enemy = Mobile:clone {
  walk = 0
}

function Enemy:init(...)
  self.thread = coroutine.wrap( self.run )
  Enemy:superinit(self, ...)
end

function Enemy:update(dt)
  self.thread(self, dt)
  if self.walk ~= 0 then
    self.dx = self.walk * dt
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
  if dir == "W" then self.walk = -self.speed
  elseif dir == "E" then self.walk = self.speed end
  self:wait( seconds )
  self.walk = 0
end

function Enemy:run()
  while true do
    self:wait(2.5)
    self:doJump()
    self:doWalk( Util.randomPick( "I", "W", "E" ), 0.5 )
  end
end

----------------------------------------

Player = Mobile:clone {
  width = 6, height = 12,
  touchX = 0, touchY = 6, touchW = 6, touchH = 6
}

function Player:update(dt)
  if Input.hold.jump then self:doJump() end
  if self.dy < 0 and not Input.hold.jump then self.dy = self.dy * 0.25 end

  if Input.hold.left and not Input.hold.right then
    self.dx = -self.speed*dt
  elseif Input.hold.right and not Input.hold.left then
    self.dx = self.speed*dt
  end
  Player:super().update(self, dt)

  debugMode.x, debugMode.y = self.x, self.y
  debugMode.f = self.onFloor
end

----------------------------------------

Collectable = Sprite:clone {
  width = 8, height = 8,
  touchX = 2, touchY = 2, touchW = 4, touchH = 4
}

function Collectable:draw(dt)
  if self.parent:isVisible(self) then
    local ox, oy = self.parent:visibilityOffset()
    Graphics:setColor( Color.YELLOW )
    love.graphics.rectangle( "fill",
        floor(self.x-ox+self.touchX),
        floor(self.y-oy+self.touchY),
        self.touchW, self.touchY )
  end
end

----------------------------------------

PlayState = State:clone {
  offsetX = 0, offsetY = 0
}

function PlayState:init( mapNum )
  self.mapNum = mapNum
  self.deathDisplay = MeterDisplay( 4, 4, Color.RED )
end

function PlayState:enter()
  self:parseMap( LevelMap[self.mapNum] )
  if self.mapNum == 1 then Game.deaths = 0 end
end

function PlayState:parseMap( map )
  self.map = {}
  self.collections = {}
  self.enemies = {}

  local x, y = 1, 1
  for ch in map:gmatch(".") do
    if ch == '@' then
      self.playerX, self.playerY = (x-1)*8, (y-1)*8
      self.player = Player(self.playerX, self.playerY, self)
      ch = ' '
    elseif ch == '$' then
      table.insert(self.collections, Collectable((x-1)*8, (y-1)*8, self))
      ch = ' '
    elseif ch == 'E' then
      table.insert(self.enemies, Enemy((x-1)*8, (y-1)*8, self))
      ch = ' '
    end
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
    return
  elseif Input.tap.n then
    self.timerToStop = 0.1
  end

  self:runFrame(dt)
end

function PlayState:runFrame(dt)
  for _, enemy in ipairs(self.enemies) do
    enemy:update(dt)
  end
  self.player:update(dt)

  local x, y = self.player:center()
  self.offsetX = floor( x / Graphics.gameWidth ) * Graphics.gameWidth
  self.offsetY = floor( y / Graphics.gameHeight ) * Graphics.gameHeight

  self:runStopTimer(dt)

  for _, enemy in ipairs(self.enemies) do
    if enemy:touches(self.player) then
      self:restartLevel(dt)
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
  Game.deaths = Game.deaths + 1
  self.deathDisplay:refresh( string.format("%i", Game.deaths) )
  self.player.x = self.playerX
  self.player.y = self.playerY
end

function PlayState:runStopTimer(dt)
  if not self.timerToStop then
    local i, N = 1, #self.collections
    while i <= N do
      if self.player:touches( self.collections[i] ) then
        table.remove(self.collections, i)
        N = N - 1
      else
        i = i + 1
      end
    end
    if N == 0 then
      self.timerToStop = 1
    end
  else
    self.timerToStop = self.timerToStop - dt
    if self.timerToStop < 0 then
      StateMachine:pop()
      StateMachine:push( Game.newNextLevel( self.mapNum ) )
    end
  end
end

function PlayState:draw(dt)
  Graphics:setColor( Color.WHITE )
  Graphics:drawBackdrop()
  local ox, oy = self:visibilityOffset()
  ox, oy = floor(ox/8), floor(oy/8)
  for y = 0, 14 do
    for x = 0, 19 do
      local t = self:getTile(x+ox, y+oy)
      if t==1 then
        Graphics:drawTile(x*8, y*8, 1, Color.WHITE)
      end
    end
  end
  for _, coin in ipairs(self.collections) do
    coin:draw(dt)
  end
  for _, enemy in ipairs(self.enemies) do
    enemy:draw(dt)
  end
  self.player:draw(dt)
  self.deathDisplay:draw(dt)
end

function PlayState:isVisible( sprite )
  return true
end

function PlayState:visibilityOffset()
  return self.offsetX, self.offsetY
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
  local s = string.format( "%s\n \n \nDIED %i TIMES",
      GameTexts.gameOverScreen, Game.deaths )
  return TextState(s, Game.newTitleState())
end

----------------------------------------

function love.load()
  Graphics:init()
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

