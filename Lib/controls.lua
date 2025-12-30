-- archivo: lib/controls.lua
-- versión: V116 (Fix MISC Page Encoders)

local Controls = {}

function Controls.key(n, z, state)
  if n == 1 then
    state.k1_held = (z == 1)
    return 
  end
  
  if state.k1_held and z == 1 then
    if n == 2 then 
      state.current_page = state.current_page - 1
      if state.current_page < 1 then state.current_page = #state.PAGE_NAMES end
    elseif n == 3 then 
      state.current_page = state.current_page + 1
      if state.current_page > #state.PAGE_NAMES then state.current_page = 1 end
    end
    return
  end
  
  if state.current_page == state.PAGES.DIVERGENCE then
     if z == 1 then
       local current = params:get("lfo_shape")
       if n == 2 then
          -- Anterior (Circular)
          if current <= 1 then params:set("lfo_shape", 6)
          else params:set("lfo_shape", current - 1) end
       elseif n == 3 then
          -- Siguiente (Circular)
          if current >= 6 then params:set("lfo_shape", 1)
          else params:set("lfo_shape", current + 1) end
       end
     end
     return
  end
  
  if n == 2 and z == 1 then
    engine.ping_amp(1.0); engine.ping_color(0); engine.ping_trig(1)
    clock.run(function() clock.sleep(0.05) engine.ping_trig(0) end)
  elseif n == 3 then
    if z == 1 then
       _prev_fb = params:get("feedback"); params:set("feedback", 0.95)
    else
       if _prev_fb then params:set("feedback", _prev_fb) end
    end
  end
end

function Controls.enc(n, d, state)
  local p = state.current_page
  
  if n == 1 then
    if p == state.PAGES.MAIN then params:delta("mix", d)
    elseif p == state.PAGES.PHYSICS then params:delta("feedback", d)
    elseif p == state.PAGES.TEXTURE then params:delta("wander", d)
    elseif p == state.PAGES.MISC then params:delta("grit", d) -- FIXED
    elseif p == state.PAGES.DIVERGENCE then params:delta("lfo_rate", d * 0.5)
    elseif p == state.PAGES.OUTPUT then params:delta("tone", d)
    end
    
  elseif n == 2 then
    if p == state.PAGES.MAIN then params:delta("depth", d)
    elseif p == state.PAGES.PHYSICS then params:delta("polarity", d)
    elseif p == state.PAGES.TEXTURE then params:delta("time_scale", d)
    elseif p == state.PAGES.MISC then params:delta("dyn_res", d) -- FIXED
    elseif p == state.PAGES.DIVERGENCE then params:delta("lfo_amt", d * 0.666)
    elseif p == state.PAGES.OUTPUT then params:delta("amp", d)
    end
    
  elseif n == 3 then
    if p == state.PAGES.MAIN then params:delta("decay", d * 2)
    elseif p == state.PAGES.PHYSICS then params:delta("damping", d)
    elseif p == state.PAGES.TEXTURE then params:delta("frequency", d)
    elseif p == state.PAGES.MISC then params:delta("fb_tap_pos", d) -- FIXED
    elseif p == state.PAGES.DIVERGENCE then params:delta("div_base", d * 0.666)
    elseif p == state.PAGES.OUTPUT then params:delta("skew", d)
    end
  end
end

return Controls
