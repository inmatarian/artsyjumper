
ROOM_WIDTH = 20
ROOM_HEIGHT = 15
STYLE = select(1,...) or "shapes"
TIMES = select(2,...) or 1
LEVEL_WIDTH = tonumber(select(3,...) or ROOM_WIDTH)
LEVEL_HEIGHT = tonumber(select(4,...) or ROOM_HEIGHT)

SEED = os.time()
math.randomseed( SEED )
for i = 1, 10 do math.random() end

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
      other:set(x, y, v)
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

run = {
  shapes = function()
    Level:init( LEVEL_WIDTH, LEVEL_HEIGHT )
    local x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)
    for i = 1, math.random(100)+25 do
      x, y = Level:carveOutShape( x, y, math.random(#Level.carveShapes))
      if (math.random(10)==1) or (x<0) or (y<0) or
         (x>=Level.width) or (y>=Level.height) then
        x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)
      end
    end
    Level:finalize()
    Level:dump()
  end,

  automata = function()
    local w, h = LEVEL_WIDTH, LEVEL_HEIGHT
    Level:init(w, h)

    for y = 0, h-1 do
      for x = 0, w-1 do
        Level.data:set(x, y, math.random(0, 1))
      end
    end

    for i = 1, math.random(2,4) do
      local lastMap = Level.data:deepcopy()
      for y = 1, h-2 do
        for x = 1, w-2 do
          local neighbors = 0
          for ny = y-1, y+1 do
            for nx = x-1, x+1 do
              neighbors = neighbors + ((lastMap:get(nx, ny)==0) and 0 or 1)
            end
          end
          Level.data:set(x, y, ((neighbors<5) and 0 or 1))
        end
      end
    end

    Level:finalize()
    Level:dump()
  end
}

for i = 1, TIMES do run[STYLE]() end

