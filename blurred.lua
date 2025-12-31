-- archivo: blurred.lua
-- versión: V309 (20 FPS Performance)

engine.name = 'Blurred'

local Globals = require 'blurred/lib/globals'
local Params = require 'blurred/lib/params'
local Graphics = require 'blurred/lib/graphics'
local Controls = require 'blurred/lib/controls'
local GridCtrl = require 'blurred/lib/grid_control'
local Sixteen = require 'blurred/lib/sixteen'
local MusicUtil = require 'musicutil'

local g = grid.connect()
local m_dev = nil 
state = Globals.new() 

local fader_map = {
  [1] = "mix",        [2] = "time_scale", [3] = "frequency", [4] = "decay",
  [5] = "feedback",   [6] = "grit",       [7] = "damping",   [8] = "polarity",
  [9] = "wander",     [10]= "depth",      [11]= "skew",      [12]= "div_base",
  [13]= "lfo_rate",   [14]= "lfo_amt",    [15]= "tone",      [16]= "amp"
}
local fader_latched = {}; local CATCH_THRESH = 0.05; local JITTER_THRESH = 0.015; local last_cc_vals = {}

function init()
  audio.level_adc_cut(1); audio.level_eng_cut(1)
  
  Params.init()
  GridCtrl.init(g, state)
  
  for i=1,16 do fader_latched[i] = false; last_cc_vals[i] = -1 end
  
  Sixteen.init(function(msg)
    local slider_id = Sixteen.cc_2_slider_id(msg.cc)
    if slider_id == nil then if msg.cc >= 32 and msg.cc <= 47 then slider_id = msg.cc - 31 end end
    if slider_id and fader_map[slider_id] then
       local param_id = fader_map[slider_id]
       local val = msg.val / 127
       local prev_val = last_cc_vals[slider_id]
       if math.abs(val - prev_val) < JITTER_THRESH then return end
       last_cc_vals[slider_id] = val
       local p = params:lookup_param(param_id)
       if not fader_latched[slider_id] then
          local current_param_val = params:get_raw(param_id)
          if math.abs(val - current_param_val) < CATCH_THRESH then fader_latched[slider_id] = true
          else
             state.popup.name = "* " .. p.name 
             state.popup.value = string.format("%.2f -> %.2f", val, current_param_val)
             state.popup.deadline = util.time() + 1.0; state.popup.active = true; return 
          end
       end
       if fader_latched[slider_id] then
           if param_id == "div_base" then val = val * val end
           params:set_raw(param_id, val)
           state.popup.name = p.name; state.popup.value = p:string(); state.popup.deadline = util.time() + 1.0; state.popup.active = true
       end
    end
  end)
  
  connect_midi()
  local fps = metro.init(); fps.time = 1/20; fps.event = function() redraw() end; fps:start()
  g.key = function(x, y, z) GridCtrl.key(x, y, z, state) end
end

function connect_midi()
  local dev_idx = params:get("midi_device")
  if dev_idx > 0 then
     if midi.vports[dev_idx] then
        m_dev = midi.connect(dev_idx)
        m_dev.event = function(data) GridCtrl.midi_event(midi.to_msg(data)) end
        print("MIDI connected to port "..dev_idx)
     end
  else if m_dev then m_dev.event = nil end; m_dev = nil; print("MIDI Disabled") end
end

function params.action_write(id, val) if id == "midi_device" then connect_midi() end end
function osc.event(path, args, from) if path == "/smear_meter" then state.amp_in = args[3] end end
function redraw() screen.clear(); Graphics.draw(state); screen.update() end
function key(n, z) Controls.key(n, z, state) end
function enc(n, d) Controls.enc(n, d, state) end
