-- archivo: blurred.lua
-- versión: V105 (Popup Trigger)

engine.name = 'Blurred'

local Globals = require 'blurred/lib/globals'
local Params = require 'blurred/lib/params'
local Graphics = require 'blurred/lib/graphics'
local Controls = require 'blurred/lib/controls'
local GridCtrl = require 'blurred/lib/grid_control'
local Sixteen = require 'blurred/lib/sixteen'

local g = grid.connect()
state = Globals.new() 

-- MAPEO DE FADERS
local fader_map = {
  [1] = "mix", [2] = "depth", [3] = "decay", [4] = "feedback",
  [5] = "frequency", [6] = "time_scale", [7] = "wander", [8] = "grit",
  [9] = "div_base", [10] = "lfo_rate", [11] = "lfo_amt", [12] = "skew",
  [13] = "polarity", [14] = "damping", [15] = "tone", [16] = "amp"
}

function init()
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  
  Params.init()
  GridCtrl.init(g, state)
  
  -- INICIALIZAR 16n CON POPUP
  Sixteen.init(function(msg)
    local slider_id = Sixteen.cc_2_slider_id(msg.cc)
    
    if slider_id == nil then
       if msg.cc >= 32 and msg.cc <= 47 then slider_id = msg.cc - 31 end
    end
    
    if slider_id and fader_map[slider_id] then
       local param_id = fader_map[slider_id]
       local val = msg.val / 127
       params:set_raw(param_id, val)
       
       -- ACTIVAR POPUP
       local p = params:lookup_param(param_id)
       state.popup.name = p.name
       state.popup.value = p:string() -- Valor formateado (ej: 50%, 0.05 Hz)
       state.popup.deadline = util.time() + 1.0 -- Mostrar por 1 segundo
       state.popup.active = true
    end
  end)
  
  local fps = metro.init()
  fps.time = 1/15
  fps.event = function() 
    redraw() 
  end
  fps:start()
  
  g.key = function(x, y, z)
    GridCtrl.key(x, y, z, state)
  end
end

function osc.event(path, args, from)
  if path == "/smear_meter" then
    state.amp_in = args[3]
  end
end

function redraw()
  screen.clear()
  Graphics.draw(state)
  screen.update()
end

function key(n, z)
  Controls.key(n, z, state)
end

function enc(n, d)
  Controls.enc(n, d, state)
end