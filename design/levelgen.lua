
ROOM_WIDTH = 20
ROOM_HEIGHT = 15
STYLE = select(1,...) or "shapes"
TIMES = select(2,...) or 1
LEVEL_WIDTH = tonumber(select(3,...) or ROOM_WIDTH)
LEVEL_HEIGHT = tonumber(select(4,...) or ROOM_HEIGHT)
OPTION = select(5,...)
if OPTION then OPTION = tonumber(OPTION) end
OPTION2 = select(6,...)
if OPTION2 then OPTION2 = tonumber(OPTION2) end

SEED = tonumber(select(7, ...) or os.time())
math.randomseed( SEED )
for i = 1, 10 do math.random() end

print( "Width", LEVEL_WIDTH, "Height", LEVEL_HEIGHT )
print( "Style", STYLE, "Times", TIMES )
print( "Option", OPTION, "Seed", SEED )

----------------------------------------

Datum = {}
Datum.__index = Datum

function Datum.new( w, h, d )
  local self = setmetatable({}, Datum)
  for y = 0, h-1 do
    for x = 0, w-1 do
      self:set(x, y, d or 1)
    end
  end
  return self
end

function Datum:set( x, y, v )
  local row = self[y+1] or {}
  self[y+1] = row
  row[x+1] = v
end

function Datum:get( x, y )
  return (self[y+1] or {})[x+1] or 0
end

function Datum:deepcopy()
  local other = setmetatable({}, Datum)
  for y, row in ipairs(self) do
    for x, v in ipairs(row) do
      other:set(x-1, y-1, v)
    end
  end
  return other
end

----------------------------------------

Level = { data = {} }

function Level:init( w, h )
  self.width = w
  self.height = h
  self.data = Datum.new(w, h)
end

function Level:dump()
  for y = 0, self.height-1 do
    for x = 0, self.width-1 do
      io.write( self.data:get(x, y)==1 and '#' or ' ' )
    end
    io.write("\n")
  end
end

Level.carveShapes = {
  { { 0, -1 }, { 0, -1 }, { -1, 0 } },
  { { 0, -1 }, { 0, -1 }, { 1, 0 } },
  { { 1, 0 }, { 1, 0 }, { 0, -1 } },
  { { 1, 0 }, { 1, 0 }, { 0, 1 } },
  { { 0, 1 }, { 0, 1 }, { 1, 0 } },
  { { 0, 1 }, { 0, 1 }, { -1, 0 } },
  { { -1, 0 }, { -1, 0 }, { 0, -1 } },
  { { -1, 0 }, { -1, 0 }, { 0, 1 } },
  { { 0, -1 }, { -1, 0 } },
  { { 0, -1 }, { 1, 0 } },
  { { -1, 0 }, { 0, -1 } },
  { { -1, 0 }, { 0, 1 } },
  { { 1, 0 }, { 0, 1 } },
  { { 1, 0 }, { 0, -1 } },
  { { 0, 1 }, { -1, 0 } },
  { { 0, 1 }, { 1, 0 } },
}

function Level:carveOutShape( x, y, o )
  self.data:set( x, y, 0 )
  local shape = self.carveShapes[o] or self.carveShapes[1]
  for _, k in ipairs(shape) do
    x, y = x + k[1], y + k[2]
    self.data:set( x, y, 0 )
  end
  return x, y
end

function Level:finalize()
  local data = self.data
  for x = 0, self.width-1 do
    data:set( x, 0, 1 )
    data:set( x, self.height-1, 1 )
  end
  for y = 0, self.height-1 do
    data:set( 0, y, 1 )
    data:set( self.width-1, y, 1 )
  end
end

----------------------------------------

function shapesStep(level, x, y, w, h)
  x, y = level:carveOutShape( x, y, math.random(#level.carveShapes))
  if (math.random(10)==1) or (x<0) or (y<0) or
     (x>=level.width) or (y>=level.height) then
    x, y = math.random(0, w-1), math.random(0, h-1)
  end
  return x, y
end

function automataStep(level, w, h)
  local lastMap = level.data:deepcopy()
  for y = 0, h-1 do
    for x = 0, w-1 do
      local neighbors = 0
      for ny = y-1, y+1 do
        for nx = x-1, x+1 do
          neighbors = neighbors + lastMap:get(nx, ny)
        end
      end
      level.data:set(x, y, ((neighbors<5) and 0 or 1))
    end
  end
end

----------------------------------------

run = {
  shapes = function( count )
    count = count or math.random(100)+25
    Level:init( LEVEL_WIDTH, LEVEL_HEIGHT )
    local x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)
    for i = 1, count do
      x, y = shapesStep(Level, x, y, LEVEL_WIDTH, LEVEL_HEIGHT)
    end
    Level:finalize()
    Level:dump()
  end,

  automata = function( count )
    count = count or math.random(2,4)
    local w, h = LEVEL_WIDTH, LEVEL_HEIGHT
    Level:init(w, h)

    for y = 0, h-1 do
      for x = 0, w-1 do
        Level.data:set(x, y, math.random(0, 1))
      end
    end

    for i = 1, count do automataStep(Level, w, h) end
    Level:finalize()
    Level:dump()
  end,

  dual = function( shapes, iterations )
    shapes = shapes or math.random(100)+25
    iterations = iterations or math.random(2,4)
    local w, h = LEVEL_WIDTH, LEVEL_HEIGHT
    Level:init(w, h)

    local x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)
    for i = 1, shapes do
      x, y = shapesStep(Level, x, y, LEVEL_WIDTH, LEVEL_HEIGHT)
    end
    for i = 1, iterations do automataStep(Level, w, h) end

    Level:finalize()
    Level:dump()
  end
}

for i = 1, TIMES do
  print( "---" )
  run[STYLE](OPTION, OPTION2)
end

