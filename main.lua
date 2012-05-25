
floor = math.floor
NULLFUNC = function() return end

----------------------------------------

require 'object'
require 'util'
require 'graphics'
require 'input'
require 'statemachine'

----------------------------------------

debugMode = {
  enabled = false,
  dt = 1,
  fps = 0,
  garbage = 0,
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
      Graphics:write( 4, 4, Color.WHITE, "fps:%i mem:%ik", self.fps, self.garbage )
    end
  end
}

----------------------------------------

PlayState = State:clone()

function PlayState:enter()

end

function PlayState:update(dt)

end

function PlayState:draw(dt)

end

----------------------------------------

TitleState = State:clone()

function TitleState:enter()

end

function TitleState:update(dt)

end

function TitleState:draw(dt)

end

----------------------------------------


function love.load()
  Graphics:init()
  Input:init()
  StateMachine:push( TitleState() )
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
end

function love.draw()
  Graphics:start()
  StateMachine:send( "draw", Graphics.deltaTime )
  debugMode:draw( Graphics.deltaTime )
  love.graphics.rectangle( "fill", 0, 0, 4, 4 )
  Graphics:stop()
end

function love.keypressed(k, u)
  Input:keypressed(k, u)
end

function love.keyreleased(k)
  Input:keyreleased(k)
end

