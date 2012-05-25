
Input = {
  tap = {},
  hold = {},
  translator = {
    [" "] = "space",
    lctrl = "ctrl",
    rctrl = "ctrl",
    lalt = "alt",
    ralt = "alt",
    lshift = "shift",
    rshift = "shift",
    ["return"] = "enter",
  }
}

local mt = {}

function mt.__index(self, key)
  if self.tap[key] then
    return "tap"
  elseif self.hold[key] then
    return "hold"
  end
  return nil
end

function Input:init()
  print("Input:init()")
  love.keyboard.setKeyRepeat( 0.500, 0.125 )
  return setmetatable(self, mt)
end

function Input:keypressed(key)
  key = self.translator[key] or key
  self.tap[key] = true
  self.hold[key] = true
  return key
end

function Input:update(dt)
  for k, _ in pairs(self.hold) do
    self.tap[k] = nil
  end
end

function Input:keyreleased(key)
  key = self.translator[key] or key
  self.tap[key] = nil
  self.hold[key] = nil
  return key
end

