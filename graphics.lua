
Graphics = {
  gameWidth = 160,
  gameHeight = 120,
  xScale = 1,
  yScale = 1,
  maxScale = 6,
  fontset = [==[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuv
wxyz{|}~]==],
}

function Graphics:init( artwork )
  self.xScale = math.max(1,floor(love.graphics.getWidth()/self.gameWidth))
  self.yScale = math.max(1,floor(love.graphics.getHeight()/self.gameHeight))
  love.graphics.setColorMode("modulate")
  love.graphics.setBlendMode("alpha")
  self:loadFont("cgafont.png")

  self.tileBounds = artwork.tiles
  self:loadTileset(artwork.name, artwork.tiles)

  self.backDrops = {
    self.loadBackDrop("backdrop.png"),
    self.loadBackDrop("backdrop2.png"),
    self.loadBackDrop("backdrop3.png")
  }

  return self
end

function Graphics:setNextScale()
  self:changeScale((self.xScale%self.maxScale)+1)
  return self
end

function Graphics:changeScale(size)
  self.xScale, self.yScale = size, size
  love.graphics.setMode( self.gameWidth*size, self.gameHeight*size, false )
  return self
end

function Graphics:saveScreenshot()
  local name = string.format("screenshot-%s.png", os.date("%Y%m%d-%H%M%S"))
  local shot = love.graphics.newScreenshot()
  shot:encode(name, "png")
  return self
end

function Graphics:loadTileset(name, tiles)
  self.image = love.graphics.newImage(name)
  self.image:setFilter("nearest", "nearest")
  local sw, sh = self.image:getWidth(), self.image:getHeight()
  self.quads = {}
  for k, v in pairs( tiles ) do
    self.quads[k] = love.graphics.newQuad( v[1], v[2], v[3], v[4], sw, sh)
  end
end

function Graphics.loadBackDrop(name)
  local image = love.graphics.newImage(name)
  image:setFilter("nearest", "nearest")
  return image
end

function Graphics:loadFont(name)
  self.fontimg = love.graphics.newImage(name)
  self.fontimg:setFilter("nearest", "nearest")
  self.font = love.graphics.newImageFont(self.fontimg, self.fontset)
  self.fontHeight = self.fontimg:getHeight()
  self.font:setLineHeight( self.fontHeight )
  love.graphics.setFont(self.font)
end

function Graphics:setClipping( x, y, w, h )
  local xs, ys = self.xScale, self.yScale
  x, y = floor(x*xs), floor(y*ys)
  w, h = floor(w*xs), floor(h*ys)
  love.graphics.setScissor( x, y, w, h )
  return self
end

function Graphics:drawBackdrop( index )
  local backdrop = self.backDrops[index] or self.backDrops[1]
  love.graphics.draw( backdrop, 0, 0 )
  return self
end

Graphics.orientations = { 0, math.pi*0.5, math.pi, math.pi*1.5 }

function Graphics:drawTile(x, y, t, c, flipped, upsideDown)
  local quad = self.quads[t]
  if not quad then return end
  local bounds = self.tileBounds[t]
  local xs, ys = self.xScale, self.yScale
  x, y = floor(x*xs)/xs, floor(y*ys)/ys
  if c then self:setColor(c) end
  if flipped then x = x + bounds[3]-1 end
  if upsideDown then y = y + bounds[4]-1 end

  love.graphics.drawq( self.image, quad, x, y, 0, flipped and -1 or 1, upsideDown and -1 or 1 )
  return self
end

function Graphics:drawChar(x, y, t, c, b)
  local quad = self.fontquads[t]
  if not quad then return end
  local xs, ys = self.xScale, self.yScale
  x, y = floor(x*8*xs)/xs, floor(y*8*ys)/ys
  self:setColor(b)
  love.graphics.drawq( self.font, self.fontquads[219], x, y )
  self:setColor(c)
  love.graphics.drawq( self.font, quad, x, y )
  return self
end

function Graphics:write(x, y, colr, str, ...)
  str = str:format(...)
  self:setColor(colr)
  if y == "center" then
    local lines = 0
    for _ in str:gmatch("[^\r\n]+") do lines = lines + 1 end
    y = floor((self.gameHeight-(self.fontHeight+2)*lines)/2)
  end
  for line in str:gmatch("[^\r\n]+") do
    local lx = (x == "center") and floor((self.gameWidth/2)-(line:len()*4)) or x
    love.graphics.print(line, lx, y)
    y = y + self.fontHeight + 2
  end
end

function Graphics:setColor(c)
  if self.lastColor ~= c then
    self.lastColor = c
    love.graphics.setColor(c)
  end
  return self
end

function Graphics:start()
  love.graphics.scale( Graphics.xScale, Graphics.yScale )
  love.graphics.setLine( 1, "rough" )
  self:setColor( Color.PUREWHITE )
  return self
end

function Graphics:stop()
  love.graphics.setScissor()
  return self
end

--------------------------------------------------------------------------------

do
  local cache={}

  Color = setmetatable( {}, {
    __index = function( self, key ) error("Nil color "..key) end,
    __call = function( self, r, g, b )
      local s
      if type(r)=="number" then
        s = string.format('#%02X%02X%02X', r, g, b)
      elseif type(r)=="string" then
        s = r:toUpper()
        if s:sub(1,1) ~= '#' then s = '#' .. s end
      else error("Bad color") end
      if not cache[s] then
        if (not g) or (not b) then
          r = tonumber( s:sub(2,3), 16 )
          g = tonumber( s:sub(4,5), 16 )
          b = tonumber( s:sub(6,7), 16 )
        end
        cache[s] = { r, g, b }
      end
      return cache[s]
    end
  })
end

Color.BLACK = Color( 0, 0, 0 )
Color.BLUE = Color( 0, 0, 255 )
Color.BROWN = Color( 170, 85, 0 )
Color.CYAN = Color( 0, 255, 255 )
Color.GRAY = Color( 85, 85, 85 )
Color.GREEN = Color( 0, 255, 0 )
Color.MAGENTA = Color( 255, 0, 255 )
Color.MAROON = Color( 170, 0, 0 )
Color.MIDNIGHT = Color( 0, 0, 85 )
Color.NAVY = Color( 0, 0, 170 )
Color.OLIVE = Color( 170, 170, 0 )
Color.ORANGE = Color( 255, 170, 0 )
Color.ORANGERED = Color( 255, 85, 0 )
Color.PURPLE = Color( 170, 0, 170 )
Color.RED = Color( 255, 0, 0 )
Color.SILVER = Color( 170, 170, 170 )
Color.TEAL = Color( 0, 170, 170 )
Color.WHITE = Color( 255, 255, 255 )
Color.YELLOW = Color( 255, 255, 0 )

Color.PUREWHITE = Color( 255, 255, 255 )

