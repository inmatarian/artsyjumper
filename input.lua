
Input = {
  tap = {},
  hold = {},
  translator = {
    [" "] = {"space", "jump"},
    up = {"jump"},
    w = {"up", "jump"},
    a = {"left"},
    s = {"down"},
    d = {"right"},
    z = {"jump"},
    lctrl = {"ctrl"},
    rctrl = {"ctrl"},
    lalt = {"alt"},
    ralt = {"alt"},
    lshift = {"shift"},
    rshift = {"shift"},
    ["return"] = {"enter"},
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
  love.keyboard.setKeyRepeat( 0.500, 0.125 )
  return setmetatable(self, mt)
end

function Input:translate(key, value)
  self.tap[key] = value
  self.hold[key] = value
  local tr = self.translator[key]
  if tr then
    for _, v in ipairs(tr) do
      self.tap[v] = value
      self.hold[v] = value
    end
  end
  return key
end

function Input:keypressed(key)
  return self:translate(key, true)
end

function Input:update(dt)
  for k, _ in pairs(self.hold) do
    self.tap[k] = nil
  end
end

function Input:keyreleased(key)
  return self:translate(key, nil)
end

