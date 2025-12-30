-- archivo: blurred.lua
-- versión: V106 (True Blurred Mapping & Hysteresis)

engine.name = 'Blurred'

local Globals = require 'blurred/lib/globals'
local Params = require 'blurred/lib/params'
local Graphics = require 'blurred/lib/graphics'
local Controls = require 'blurred/lib/controls'
local GridCtrl = require 'blurred/lib/grid_control'
local Sixteen = require 'blurred/lib/sixteen'

local g = grid.connect()
state = Globals.new() 

-- MAPEO V106: Proposal A (Logic Flow)
local fader_map = {
  [1] = "mix",        [2] = "time_scale", [3] = "frequency", [4] = "decay",
  [5] = "feedback",   [6] = "grit",       [7] = "damping",   [8] = "polarity",
  [9] = "wander",     [10]= "depth",      [11]= "skew",      [12]= "div_base",
  [13]= "lfo_rate",   [14]= "lfo_amt",    [15]= "tone",      [16]= "amp"
}

-- HISTÉRESIS: Tabla para guardar últimos valores y evitar jitter
local last_cc_vals = {}
local JITTER_THRESHOLD = 0.02 -- 2% de movimiento requerido

function init()
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  
  Params.init()
  GridCtrl.init(g, state)
  
  -- INICIALIZAR 16n CON POPUP + HISTÉRESIS
  Sixteen.init(function(msg)
    local slider_id = Sixteen.cc_2_slider_id(msg.cc)
    
    if slider_id == nil then
       if msg.cc >= 32 and msg.cc <= 47 then slider_id = msg.cc - 31 end
    end
    
    if slider_id and fader_map[slider_id] then
       local param_id = fader_map[slider_id]
       local val = msg.val / 127
       
       -- CONTROL DE DIVERGENCIA EXPONENCIAL
       if param_id == "div_base" then
         val = val * val -- Curva exponencial (x^2)
       end
       
       -- ALGORITMO ANTI-JITTER
       local prev = last_cc_vals[slider_id] or -1
       if math.abs(val - prev) > JITTER_THRESHOLD then
         last_cc_vals[slider_id] = val
         
         params:set_raw(param_id, val)
         
         -- ACTIVAR POPUP
         local p = params:lookup_param(param_id)
         state.popup.name = p.name
         state.popup.value = p:string() 
         state.popup.deadline = util.time() + 1.0 
         state.popup.active = true
       end
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
