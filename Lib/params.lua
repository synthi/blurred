-- archivo: lib/params.lua
-- versión: V108 (Renamed Resonance to Delay)

local Params = {}

function Params.init()
  params:add_separator("BLURRED")
  
  -- P1: MAIN
  params:add_group("MAIN", 3)
  params:add{type = "control", id = "mix", name = "Mix", controlspec = controlspec.new(0, 1, 'lin', 0, 0.5, "%"), action = function(x) engine.mix(x) end}
  params:add{type = "control", id = "depth", name = "Depth", controlspec = controlspec.new(0, 1, 'lin', 0, 1, ""), action = function(x) engine.depth(x) end}
  -- CAMBIO DE NOMBRE: Resonance -> Delay
  params:add{type = "control", id = "decay", name = "Delay", controlspec = controlspec.new(0.001, 10.0, 'exp', 0, 0.5, "s"), action = function(x) engine.decay(x) end}

  -- P2: PHYSICS
  params:add_group("PHYSICS", 3)
  params:add{type = "control", id = "feedback", name = "Global Fdbk", controlspec = controlspec.new(0, 1.1, 'lin', 0, 0.0, ""), action = function(x) engine.feedback(x) end}
  params:add{type = "control", id = "polarity", name = "Polarity", controlspec = controlspec.new(-1, 1, 'lin', 0, 0, ""), action = function(x) engine.polarity(x) end}
  params:add{type = "control", id = "damping", name = "Damping", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.damping(x) end}

  -- P3: TEXTURE
  params:add_group("TEXTURE", 3)
  params:add{type = "control", id = "frequency", name = "Frequency", controlspec = controlspec.new(0.0, 1.0, 'lin', 0, 0.5, ""), action = function(x) engine.frequency(x) end}
  params:add{type = "control", id = "time_scale", name = "Time Scale", controlspec = controlspec.new(0.01, 1.0, 'exp', 0, 1.0, "x"), action = function(x) engine.time_scale(x) end}
  params:add{type = "control", id = "wander", name = "Wander", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.wander(x) end}

  -- P4: MISC
  params:add_group("MISC", 3)
  params:add{type = "control", id = "grit", name = "Grit (Macro)", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.grit(x) end}
  params:add{type = "control", id = "dyn_res", name = "Dyn. Res", controlspec = controlspec.new(0, 1, 'lin', 0, 0, "%"), action = function(x) engine.dyn_res(x) end}
  params:add{type = "control", id = "fb_tap_pos", name = "Fdbk Tap", controlspec = controlspec.new(0, 7, 'lin', 0, 7, ""), action = function(x) engine.fb_tap_pos(x) end}

  -- P5: DIVERGENCE
  params:add_group("DIVERGENCE", 4)
  params:add{type = "control", id = "lfo_rate", name = "LFO Rate", controlspec = controlspec.new(0.01, 20.0, 'exp', 0, 0.1, "Hz"), action = function(x) engine.lfo_rate(x) end}
  params:add{type = "control", id = "lfo_amt", name = "LFO Amount", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.lfo_amt(x) end}
  params:add{type = "control", id = "div_base", name = "Divergence", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.div_base(x) end}
  params:add{type = "number", id = "lfo_shape", name = "LFO Shape", min=1, max=6, default=1, action = function(x) engine.lfo_shape(x-1) end}

  -- P6: OUTPUT
  params:add_group("OUTPUT", 3)
  params:add{type = "control", id = "tone", name = "Tone (DJ)", controlspec = controlspec.new(-1, 1, 'lin', 0, 0, ""), action = function(x) engine.tone(x) end}
  params:add{type = "control", id = "amp", name = "Output Level", controlspec = controlspec.new(0, 2, 'lin', 0, 1, ""), action = function(x) engine.amp(x) end}
  params:add{type = "control", id = "skew", name = "Stereo Skew", controlspec = controlspec.new(0, 1, 'lin', 0, 0, ""), action = function(x) engine.skew(x) end}
  
  -- GENERATORS
  params:add_group("GENERATORS", 7)
  params:add{type = "control", id = "scrape_vel", name = "Scrape", controlspec = controlspec.new(0, 1, 'lin', 0, 0), action = function(x) engine.scrape_vel(x) end}
  params:add{type = "control", id = "scrape_pitch", name = "S. Pitch", controlspec = controlspec.new(0, 1, 'lin', 0, 0.5), action = function(x) engine.scrape_pitch(x) end}
  params:add{type = "control", id = "scrape_color", name = "S. Color", controlspec = controlspec.new(-1, 1, 'lin', 0, 0), action = function(x) engine.scrape_color(x) end}
  params:add{type = "control", id = "ping_trig", name = "Ping Trig", controlspec = controlspec.new(0, 1, 'lin', 0, 0), action = function(x) engine.ping_trig(x) end}
  params:add{type = "control", id = "ping_pitch", name = "P. Pitch", controlspec = controlspec.new(0, 127, 'lin', 0, 60), action = function(x) engine.ping_pitch(x) end}
  params:add{type = "control", id = "ping_amp", name = "P. Amp", controlspec = controlspec.new(0, 1, 'lin', 0, 1), action = function(x) engine.ping_amp(x) end}
  params:add{type = "control", id = "ping_color", name = "P. Color", controlspec = controlspec.new(-1, 1, 'lin', 0, 0), action = function(x) engine.ping_color(x) end}
  
  params:add_group("SYSTEM", 1)
  params:add{type = "option", id = "ef_clamp", name = "EF Clamp", options = {"OFF", "ON"}, default = 2, action = function(x) engine.ef_clamp(x-1) end}

  params:bang()
end

return Params
