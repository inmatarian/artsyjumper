
Sound = {
  clips = {
    COIN1 = "coin.ogg",
    DEATH1 = "death1.wav",
    DEATH2 = "death2.wav",
    JUMP1 = "jump1.wav",
    JUMP2 = "jump2.wav",
    JUMP3 = "jump3.wav"
  },
  sources = {}
}

function Sound:init()
  for k, v in pairs(self.clips) do
    self[k] = "sound/"..v
  end
end

function Sound:update(dt)
  local toKill = {}
  for _, sound in pairs(self.sources) do
    if sound:isStopped() then
      table.insert(toKill, sound)
    end
  end
  for _, sound in ipairs(toKill) do
    self.sources[s] = nil
  end
end

function Sound:playClip(name)
  local src = love.audio.newSource(name, "stream")
  src:setLooping(false)
  love.audio.play(src)
  self.sources[src]=src
end


