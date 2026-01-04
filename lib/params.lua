-- archivo: lib/params.lua
-- versión: V228 (Clean Params)

local Params = {}
local Globals = require 'blurred/lib/globals'
local MusicUtil = require 'musicutil'

function Params.init()
  params:add_separator("BLURRED")
  -- ... [GRUPOS 1-6 IGUALES] ...
  params:add_group("MAIN", 3)
  params:add{type = "control", id = "mix", name = "Mix", controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, "%"), action = function(x) engine.mix(x) end}
  params:add{type = "control", id = "depth", name = "Depth", controlspec = controlspec.new(0, 1, 'lin', 0, 1, ""), action = function(x) engine.depth(x) end}
  params:add{type = "control", id = "decay", name = "Delay", controlspec = controlspec.new(0.001, 10.0, 'exp', 0, 0.5, "s"), action = function(x) engine.decay(x) end}

  params:add_group("PHYSICS", 4)
  params:add{type = "control", id = "feedback", name = "Global Fdbk", controlspec = controlspec.new(0, 1.1, 'lin', 0, 0.0, ""), action = function(x) engine.feedback(x) end}
  params:add{type = "control", id = "polarity", name = "Polarity", controlspec = controlspec.new(-1, 1, 'lin', 0, 0, ""), action = function(x) engine.polarity(x) end}
  params:add{type = "control", id = "damping", name = "Damping", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.damping(x) end}
  params:add{type = "option", id = "feedback_hpf", name = "Fdbk HPF", options = {"OFF", "120", "250", "500", "1K"}, default = 1, action = function(x) engine.feedback_hpf(x-1) end}

  params:add_group("TEXTURE", 4)
  params:add{type = "control", id = "frequency", name = "Frequency", controlspec = controlspec.new(0.0, 1.0, 'lin', 0, 0.5, ""), action = function(x) engine.frequency(x) end}
  params:add{type = "control", id = "time_scale", name = "Time Scale", controlspec = controlspec.new(0.01, 1.0, 'exp', 0, 1.0, "x"), action = function(x) engine.time_scale(x) end}
  params:add{type = "control", id = "wander", name = "Wander", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.wander(x) end}
  params:add{type = "option", id = "texture_freeze", name = "Freeze LFO", options = {"OFF", "ON"}, default = 1, action = function(x) engine.texture_freeze(x-1) end}

  params:add_group("MISC", 4)
  params:add{type = "control", id = "grit", name = "Grit (Macro)", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.grit(x) end}
  params:add{type = "control", id = "dyn_res", name = "Dyn. Res", controlspec = controlspec.new(0, 1, 'lin', 0, 0, "%"), action = function(x) engine.dyn_res(x) end}
  params:add{type = "option", id = "ef_clamp", name = "EF Clamp", options = {"OFF", "ON"}, default = 2, action = function(x) engine.ef_clamp(x-1) end}
  params:add{type = "control", id = "fb_tap_pos", name = "Fdbk Tap", controlspec = controlspec.new(0, 7, 'lin', 0, 7, ""), action = function(x) engine.fb_tap_pos(x) end}

  params:add_group("DIVERGENCE", 4)
  params:add{type = "control", id = "lfo_rate", name = "LFO Rate", controlspec = controlspec.new(0.01, 20.0, 'exp', 0, 0.1, "Hz"), action = function(x) engine.lfo_rate(x) end}
  params:add{type = "control", id = "lfo_amt", name = "LFO Amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.lfo_amt(x) end}
  params:add{type = "control", id = "div_base", name = "Divergence", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.div_base(x) end}
  params:add{type = "number", id = "lfo_shape", name = "LFO Shape", min=1, max=6, default=1, action = function(x) engine.lfo_shape(x-1) end}

  params:add_group("OUTPUT", 4)
  params:add{type = "control", id = "tone", name = "Tone (DJ)", controlspec = controlspec.new(-1, 1, 'lin', 0, 0, ""), action = function(x) engine.tone(x) end}
  params:add{type = "control", id = "amp", name = "Output Level", controlspec = controlspec.new(0, 2, 'lin', 0, 1, ""), action = function(x) engine.amp(x) end}
  params:add{type = "control", id = "skew", name = "Stereo Skew", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.skew(x) end}
  params:add{type = "option", id = "output_mono", name = "Mono Output", options = {"OFF", "ON"}, default = 1, action = function(x) engine.output_mono(x-1) end}

  -- [VINTAGE SYNTH IGUAL]
  params:add_group("VINTAGE SYNTH", 15)
  params:add{type = "control", id = "vintage_vol", name = "Synth Vol", controlspec = controlspec.new(0, 2, 'lin', 0, 0.8), action = function(x) engine.vintage_vol(x) end}
  params:add{type = "control", id = "vintage_timbre", name = "Timbre", controlspec = controlspec.new(0, 1, 'lin', 0, 0.2), action = function(x) engine.vintage_timbre(x) end}
  params:add{type = "control", id = "vintage_mix", name = "Wave Mix", controlspec = controlspec.new(0, 1, 'lin', 0, 0.0), action = function(x) engine.vintage_mix(x) end}
  params:add{type = "control", id = "vintage_cutoff", name = "Cutoff", controlspec = controlspec.new(20, 20000, 'exp', 0, 2000, "Hz"), action = function(x) engine.vintage_cutoff(x) end}
  params:add{type = "control", id = "vintage_attack", name = "Attack", controlspec = controlspec.new(0.001, 8.0, 'exp', 0, 0.01, "s"), action = function(x) engine.vintage_attack(x) end}
  params:add{type = "control", id = "vintage_decay", name = "Decay/Rel", controlspec = controlspec.new(0.01, 15.0, 'exp', 0, 0.5, "s"), action = function(x) engine.vintage_decay(x) end}
  params:add{type = "control", id = "vintage_sustain", name = "Sustain", controlspec = controlspec.new(0, 1, 'lin', 0, 1.0, ""), action = function(x) engine.vintage_sustain(x) end}
  params:add{type = "option", id = "vintage_lpg_mode", name = "LPG Mode", options = {"VCA", "BOTH"}, default = 2}
  params:add{type = "number", id = "vintage_octave", name = "Octave", min = -1, max = 1, default = 0}
  params:add{type = "control", id = "vintage_drift", name = "Drift", controlspec = controlspec.new(0, 1, 'lin', 0, 0), action = function(x) engine.vintage_drift(x) end}
  params:add{type = "control", id = "vintage_noisy_saw", name = "Noisy Saw", controlspec = controlspec.new(0, 1, 'lin', 0, 0), action = function(x) engine.vintage_noisy_saw(x) end}
  params:add{type = "option", id = "vintage_keytrack", name = "Key Track", options = {"OFF", "HALF", "FULL"}, default = 1, action = function(x) engine.vintage_keytrack((x-1)*0.5) end}
  params:add{type = "option", id = "max_voices", name = "Max Voices", options = {"4", "6", "8", "12"}, default = 2} 
  params:add{type = "number", id = "scale_idx", name = "Scale", min = 1, max = #Globals.SCALES, default = 1}
  params:add{type = "number", id = "root_note", name = "Root Note", min = 0, max = 127, default = 36, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end}
  
  params:add_group("MIDI SETUP", 2)
  params:add{type = "number", id = "midi_device", name = "MIDI Device", min = 0, max = 4, default = 0, formatter = function(param) return param:get()==0 and "Disabled" or "Port "..param:get() end, action = function(x) end}
  params:add{type = "number", id = "midi_channel", name = "MIDI Channel", min = 0, max = 16, default = 0, formatter = function(param) return param:get()==0 and "Omni" or tostring(param:get()) end}

  -- HIDDEN PARAMS
  params:add{type = "option", id = "ghost_feed", name = "Ghost Feed", options={"OFF", "ON"}, default=1, action=function(x) engine.ghost_feed(x-1) end}
  params:add{type = "option", id = "time_freeze", name = "Time Freeze", options={"OFF", "ON"}, default=1, action=function(x) engine.time_freeze(x-1) end}
  params:add{type = "option", id = "crystal_mode", name = "Harmonic Crystal", options={"OFF", "ON"}, default=1, action=function(x) engine.crystal_mode(x-1) end}
  params:add{type = "number", id = "bass_focus_idx", name = "Bass Focus", min=1, max=4, default=1, action=function(x) 
     local freqs = {0, 50, 100, 200}
     engine.bass_focus(freqs[x]) 
  end}
  
  -- REMOVED TAPE STOP PARAMS TO AVOID ERROR

  -- [RESTO IGUAL]
  params:add_group("GENERATORS", 4)
  params:add{type = "control", id = "ping_trig", name = "Ping Trig", controlspec = controlspec.new(0, 1, 'lin', 0, 0), action = function(x) engine.ping_trig(x) end}
  params:add{type = "control", id = "ping_pitch", name = "P. Pitch", controlspec = controlspec.new(0, 127, 'lin', 0, 60), action = function(x) engine.ping_pitch(x) end}
  params:add{type = "control", id = "ping_amp", name = "P. Amp", controlspec = controlspec.new(0, 1, 'lin', 0, 1), action = function(x) engine.ping_amp(x) end}
  params:add{type = "control", id = "ping_color", name = "P. Color", controlspec = controlspec.new(-1, 1, 'lin', 0, 0), action = function(x) engine.ping_color(x) end}
  params:add_group("SYSTEM", 1)
  params:add{type = "option", id = "ef_clamp", name = "EF Clamp", options = {"OFF", "ON"}, default = 2, action = function(x) engine.ef_clamp(x-1) end}

  params:bang()
end

return Params
