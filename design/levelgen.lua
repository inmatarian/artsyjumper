
ROOM_WIDTH = 20
ROOM_HEIGHT = 15
LEVEL_WIDTH = select(1,...) or ROOM_WIDTH
LEVEL_HEIGHT = select(2,...) or ROOM_HEIGHT

SEED = os.time()
math.randomseed( SEED )

----------------------------------------

Level = { data = {} }

function Level:set( x, y, v )
  local row = self.data[y+1] or {}
  self.data[y+1] = row
  row[x+1] = v
end

function Level:get( x, y )
  return (self.data[y+1] or {})[x+1] or 0
end

function Level:init( w, h )
  self.width = w
  self.height = h
  for y = 0, h-1 do
    for x = 0, w-1 do
      self:set(x, y, 1)
    end
  end
end

function Level:dump()
  for y = 0, self.height-1 do
    for x = 0, self.width-1 do
      io.write( self:get(x, y)==1 and '#' or ' ' )
    end
    io.write("\n")
  end
end

Level.LShape = {
  { { 0, -1 }, { 0, -1 }, { -1, 0 }  },
  { { 0, -1 }, { 0, -1 }, { 1, 0 }  },
  { { 1, 0 }, { 1, 0 }, { 0, -1 }  },
  { { 1, 0 }, { 1, 0 }, { 0, 1 }  },
  { { 0, 1 }, { 0, 1 }, { 1, 0 }  },
  { { 0, 1 }, { 0, 1 }, { -1, 0 }  },
  { { -1, 0 }, { -1, 0 }, { 0, -1 }  },
  { { -1, 0 }, { -1, 0 }, { 0, 1 }  },
}

function Level:carveOutLShape( x, y, o )
  self:set( x, y, 0 )
  local shape = self.LShape[o] or self.LShape[1]
  for _, k in ipairs(shape) do
    x, y = x + k[1], y + k[2]
    self:set( x, y, 0 )
  end
  return x, y
end

function Level:finalize()
  for x = 0, self.width-1 do
    self:set( x, 0, 1 )
    self:set( x, self.height-1, 1 )
  end
  for y = 0, self.height-1 do
    self:set( 0, y, 1 )
    self:set( self.width-1, y, 1 )
  end
end

----------------------------------------

Level:init( LEVEL_WIDTH, LEVEL_HEIGHT )

local x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)

for i = 1, 100 do
  x, y = Level:carveOutLShape( x, y, math.random(#Level.LShape))
  if math.random(10)==1 then
    x, y = math.random(LEVEL_WIDTH), math.random(LEVEL_HEIGHT)
  end
end
Level:finalize()

Level:dump()

