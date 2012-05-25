
floor = math.floor
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
  x = 0, y = 0,
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
      Graphics:write( 4, 4, Color.BLUE, "fps:%i mem:%ik\nx:%i y:%i",
        self.fps, self.garbage, self.x, self.y )
    end
  end
}

----------------------------------------

Sprite = Object:clone {
  x = 0, y = 0,
  width = 1, height = 1,
  touchX=0, touchY=0, touchW=1, touchH=1
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
  jump = 0, jumpHeight = 128, onFloor = false,
  gravity = 512, speed = 96
}

function Mobile:init( x, y, parent )
  self.dx = 0
  self.dy = 0
  Mobile:superinit(self, x, y, parent)
end

function Mobile:center()
  return self.x + floor(self.width / 2), self.y + floor(self.height / 2)
end

function Mobile:update(dt)
  self.dy = self.dy + self.gravity*dt
  local newY = self.y + self.dy*dt

  local newX = self.x + self.dx
  self.dx = self.dx * 0.33

  local dx = (newX >= self.x) and 1 or -1
  local dy = (newY >= self.y) and 1 or -1

  local lx, rx = self.x, self.x+self.width-1
  local lastY = self.y

  for ty = floor(self.y), floor(newY), dy do
    if self.parent:mapCollisionAt( self.x, ty, self.width, self.height ) then
      newY = lastY
      self.dy = 0
      break
    else
      lastY = ty
    end
  end
  if not self.onFloor then self.jump = self.jump + dt end

  local lastX = self.x
  for tx = floor(self.x), floor(newX), dx do
    if self.parent:mapCollisionAt( tx, newY, self.width, self.height ) then
      newX = lastX
      self.dx = 0
      break
    else
      lastX = tx
    end
  end

  self.x, self.y = newX, newY

  if self.parent:mapCollisionAt( self.x, self.y, self.width, self.height+1) then
    self.onFloor = true
    self.jump = 0
  else
    self.onFloor = false
  end
end

function Mobile:draw(dt)
  if self.parent:isVisible(self) then
    local ox, oy = self.parent:visibilityOffset()
    Graphics:setColor( Color.RED )
    love.graphics.rectangle( "fill", floor(self.x-ox), floor(self.y-oy), self.width, self.height )
  end
end

----------------------------------------

Player = Mobile:clone {
  width = 6, height = 12,
  touchX = 0, touchY = 0, touchW = 6, touchH = 12
}

function Player:update(dt)
  if Input.tap.up and self.onFloor then
    self.dy = -self.jumpHeight
  elseif Input.hold.up and (self.dy < 0) and (self.jump < 0.1) then
    self.dy = self.dy - (self.jumpHeight*dt)
  end

  if Input.hold.left and not Input.hold.right then
    self.dx = -self.speed*dt
  elseif Input.hold.right and not Input.hold.left then
    self.dx = self.speed*dt
  end
  Player:super().update(self, dt)

  debugMode.x, debugMode.y = self.x, self.y
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
  self:parseMap( LevelMap[mapNum] )
end

function PlayState:parseMap( map )
  self.map = {}
  self.monies = { x={}, y={} }
  local x, y = 1, 1
  for ch in map:gmatch(".") do
    if ch == '@' then
      self.playerStartX, self.playerStartY = x, y
      ch = ' '
    elseif ch == '$' then
      table.insert(self.monies.x, x)
      table.insert(self.monies.y, y)
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
  local row = self.map[y]
  if (not row) or (not row[x]) then return 0 end
  return row[x]
end

function PlayState:mapCollisionAt( x, y, w, h )
  local y1, y2 = floor(y/8)+1, floor((y+h-1)/8)+1
  local x1, x2 = floor(x/8)+1, floor((x+w-1)/8)+1
  for ty = y1, y2 do
    for tx = x1, x2 do
      if self:getTile(tx, ty) ~= 0 then return true end
    end
  end
  return false
end

function PlayState:enter()
  self.player = Player((self.playerStartX-1)*8, (self.playerStartY-1)*8, self)
  self.collections = {}
  for i, x in ipairs(self.monies.x) do
    table.insert(self.collections,
        Collectable( (x-1)*8, (self.monies.y[i]-1)*8, self ))
  end
end

function PlayState:update(dt)
  if Input.tap.r then
    StateMachine:pop()
    StateMachine:push( PlayState(self.mapNum) )
  else
    self:runFrame(dt)
  end
end

function PlayState:runFrame(dt)
  self.player:update(dt)

  local x, y = self.player:center()
  self.offsetX = floor( x / Graphics.gameWidth ) * Graphics.gameWidth
  self.offsetY = floor( y / Graphics.gameHeight ) * Graphics.gameHeight

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
      StateMachine:push( newNextLevel( self.mapNum ) )
    end
  end
end

function PlayState:draw(dt)
  Graphics:setColor( Color.WHITE )
  local ox, oy = self:visibilityOffset()
  ox, oy = floor(ox/8), floor(oy/8)
  for y = 1, 15 do
    for x = 1, 20 do
      local t = self:getTile(x+ox, y+oy)
      if t==1 then
        love.graphics.rectangle("fill", (x-1)*8, (y-1)*8, 7, 7)
      end
    end
  end
  self.player:draw(dt)
  for _, coin in ipairs(self.collections) do
    coin:draw(dt)
  end
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
  self.text = text
  self.nextState = nextState
end

function TextState:update(dt)
  if Input.tap.enter or Input.tap.escape then
    StateMachine:pop()
    StateMachine:push( self.nextState )
  end
end

function TextState:draw(dt)
  Graphics:write( "center", "center", Color.WHITE, self.text )
end

----------------------------------------

function newNextLevel( index )
  local followingState
  index = index + 1
  if index < #GameTexts.levels then
    followingState = PlayState(index)
  else
    followingState = newTitleState()
  end
  return TextState( GameTexts.levels[index], followingState )
end

function newTitleState()
  return TextState( GameTexts.titleScreen, newNextLevel(0) )
end

----------------------------------------

function love.load()
  Graphics:init()
  Input:init()
  StateMachine:push( newTitleState() )
end

function love.update(dt)
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

