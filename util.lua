
Util = {}

function Util.meta(tab,le)
  return setmetatable(le or {}, tab)
end

Util.symbol = Util.meta {
  __call = function(S, t) return setmetatable(t or {}, getmetatable(S)) end,
  __index = function(S, k) return rawset(S, k, k)[k] end,
  __nexindex = function(S, k, v) error("Bad usage of enum table.") end,
}

Util.const = Util.meta {
  __call = function(S, t) return setmetatable(t, getmetatable(S)) end,
  __newindex = function(S, k, v) error("Read-only table error! ", 2) end,
  __index = function(S, k) error("Read-only typo error! "..k, 2) end
}

function Util.set(...)
  local s = {}
  for i = 1, select('#',...) do
    s[select(i,...)] = true
  end
  return s
end

function Util.array( size, default )
  local a = {}
  if type(default) ~= "nil" then
    for i = 1, size do a[i] = default end
  end
  return a
end

function Util.lookup( tab )
  for i, v in ipairs(tab) do
    tab[v] = i
  end
  return tab
end

function Util.tostringr( val, indent )
  local str
  indent = indent or ""
  if type(val) == "table" then
    str = "{\n"
    local max = 25
    for key, value in pairs(val) do
      str = str .. indent .. "  [" .. tostring(key) .. "] = "
      str = str .. Util.tostringr(value, indent.."  ") .. "\n"
      if max <= 1 then
        str = str .. indent .. "  ...\n"
        break
      end
      max = max - 1
    end
    str = str .. indent .. "}"
  else
    str = tostring(val)
  end
  return str
end

function Util.printr( val )
  print( Util.tostringr(val) )
end


do
  local Signal_MT = {
    __index = {
      register = function(self, ...)
        local i, N, C = 1, select('#', ...), #self.cb+1
        while i <= N do
          self.obj[C] = assert(select(i, ...))
          self.cb[C] = assert(select(i+1, ...))
          i, C = i+2, C+1
        end
        return self
      end,
      unregister = function(self, obj, callback)
        assert(callback)
        local i, N = 1, #self.cb
        while i <= N do
          if (self.obj[i] == obj) and (self.cb[i] == callback) then
            table.remove( self.obj, i )
            table.remove( self.cb, i )
          else
            i = i + 1
          end
        end
        return self
      end,
    },
    __call = function(self, ...)
      local q = self.q
      local i, j, N = 1, 1, #self.cb
      while i <= N do
        q[j], q[j+1] = self.cb[i], self.obj[i]
        i, j = i+1, j+2
      end
      i, N = 1, j-2
      while i <= N do
        local f, o = q[i], q[i+1]
        f(o, ...)
        q[i], q[i+1] = nil, nil
        i = i + 2
      end
    end
  }
  function Util.signal(...)
    return setmetatable({obj={},cb={},q={}},Signal_MT):register(...)
  end
end

function Util.rectOverlaps( ax1, ay1, aw, ah, bx1, by1, bw, bh )
  local hint = 0.001
  local ax2, ay2 = ax1+aw-hint, ay1+ah-hint
  local bx2, by2 = bx1+bw-hint, by1+bh-hint
  return not ((ax1 > bx2) or (bx1 > ax2) or (ay1 > by2) or (by1 > ay2))
end

function Util.randomPick(...)
  return select(math.random(1, select('#', ...)), ...)
end

function Util.wordWrap( str, limit )
  limit = limit or 40
  local here = 1
  return str:gsub("(%s+)()(%S+)()",
    function(sp, st, word, fi)
      if fi-here > limit then
        here = st
        return '\n' .. word
      end
    end)
end

function Util.reflow( str, limit )
  local t, i, nl, sp = {}, 0, 0, 0
  limit = limit or 20
  for c in str:gmatch(".") do
    i = i + 1
    t[i] = c
    if (c == " ") then sp = i
    elseif (c == "\n") then sp, nl = i, i end
    if (i-nl) > limit then t[sp], nl = "\n", sp end
  end
  return table.concat(t)
end

