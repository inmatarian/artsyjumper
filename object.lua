
Object = setmetatable( {}, {
  __index = function(self, key)
    return self:unknownIndex(key)
  end
})

function Object:clone(body)
  assert(Object.isA(self, Object))
  return setmetatable(rawset(body or {}, "__prototype", self), Object)
end

function Object:init() return self end

function Object:initialize( body, ... )
  return self:clone(body):init(...) or body
end

function Object:__call(...)
  return self:initialize( {}, ...)
end

function Object:__index(key)
  return rawget(self, "__prototype")[key]
end

function Object:unknownIndex(key) --[[stub]] end

function Object:__newindex(key, value)
  self:newIndex(key, value)
end

function Object:newIndex(key, value)
  rawset(self, key, value)
end

function Object:become(obj)
  assert(Object.isA(obj, Object))
  return rawset(self, "__prototype", obj)
end

function Object:super()
  return rawget(self, "__prototype")
end

function Object:superinit(obj, ...)
  return rawget(self, "__prototype").init(obj, ...)
end

function Object:isA(ancestor)
  repeat
    if self == ancestor then return true end
    self = rawget(self, "__prototype")
  until not self
end

function Object:mixin(...)
  for i = 1, select('#', ...) do
    for k, v in pairs(select(i, ...)) do
      rawset(self, k, v)
    end
  end
  return self
end

local function unittest()
  local TestFoo = Object:clone()
  local Waka = { wakawaka = function(self) return 27 end }
  local TestBar = TestFoo:clone():mixin(Waka)
  local testbaz = TestBar()
  assert( not testbaz.undeclared )
  assert( testbaz:wakawaka() == 27 )
  assert( testbaz:isA(TestFoo) and testbaz:isA(Object) )
end

