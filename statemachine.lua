
StateMachine = { stack = {}, queue = {} }

function StateMachine:sendTo( index, message, ... )
  local state = self.stack[index]
  if state and state[message] then state[message](state, ...) end
end

function StateMachine:send( message, ... )
  if (message == "update") and (#self.queue >= 1) then
    self:push( table.remove( self.queue, 1 ) )
  end
  self:sendTo( #self.stack, message, ... )
end

function StateMachine:downsend( obj, index, message, ... )
  local N = #self.stack
  while self.stack[N] ~= obj and N > 0 do N = N - 1 end
  self:sendTo( N+index, message, ... )
end

function StateMachine:push( state )
  self:send(E.suspend)
  table.insert( self.stack, state )
  self:send(E.enter)
end

function StateMachine:pop()
  self:send(E.exit)
  table.remove( self.stack )
  self:send(E.resume)
end

function StateMachine:enqueue( state )
  table.insert(self.queue, state)
end

function StateMachine:isEmpty()
  return ( #self.stack == 0 ) and ( #self.queue == 0 )
end

function StateMachine:clear()
  local N, M = #self.stack, #self.queue
  for i = 1, N do self.stack[i] = nil end
  for i = 1, M do self.queue[i] = nil end
end

--------------------------------------------------------------------------------

State = Object:clone {
  enter = NULLFUNC,
  exit = NULLFUNC,
  suspend = NULLFUNC,
  resume = NULLFUNC,
  focus = NULLFUNC,
  keypressed = NULLFUNC,
}

function State:init()
  self.layers = {}
  return self
end

function State:draw(dt)
  for _, v in pairs(self.layers) do
    v:draw(dt)
  end
end

function State.layerSorter(a, b)
  return a.priority < b.priority
end

function State:addLayer(...)
  for i = 1, select('#',...) do
    local txt = select(i, ...)
    table.insert( self.layers, txt )
  end
  table.sort( self.layers, self.layerSorter )
end

function State:removeLayer(txt)
  local i = #self.layers
  while i > 0 do
    if self.layers[i] == txt then
      table.remove(self.layers, i)
    end
    i = i - 1
  end
end

function State:changeLayerPriority( layer, priority )
  layer.priority = priority
  table.sort( self.layers, self.layerSorter )
end

function State:updateLayers(dt)
  for i = 1, #self.layers do
    self.layers[i]:update(dt)
  end
end

function State:clearLayers(txt)
  self.layers = {}
end

function State:update(dt)
  self:updateLayers(dt)
end

--------------------------------------------------------------------------------

