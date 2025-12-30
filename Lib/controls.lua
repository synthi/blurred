-- archivo: lib/controls.lua
-- versión: V210 (Cutoff Resolution 0.5)

local Controls = {}

function Controls.key(n, z, state)
  if n == 1 then state.k1_held = (z == 1); return end
  if state.k1_held and z == 1 then
    if n == 2 then state.current_page = state.current_page - 1; if state.current_page < 1 then state.current_page = #state.PAGE_NAMES end
    elseif n == 3 then state.current_page = state.current_page + 1; if state.current_page > #state.PAGE_NAMES then state.current_page = 1 end end
    return
  end
  
  if state.current_page == state.PAGES.DIVERGENCE then
     if z == 1 then
       local current = params:get("lfo_shape")
       if n == 2 then if current <= 1 then params:set("lfo_shape", 6) else params:set("lfo_shape", current - 1) end
       elseif n == 3 then if current >= 6 then params:set("lfo_shape", 1) else params:set("lfo_shape", current + 1) end end
     end
  elseif state.current_page == state.PAGES.SYNTH then
    if z == 1 then
      if n == 2 then
        local m = params:get("vintage_lpg_mode")
        params:set("vintage_lpg_mode", (m % 2) + 1)
        state.popup.name = "LPG MODE"; state.popup.value = params:string("vintage_lpg_mode"); state.popup.deadline = util.time() + 1.0; state.popup.active = true
      elseif n == 3 then
        local val = params:get("vintage_noisy_saw")
        val = val + 0.25; if val > 1.0 then val = 0 end
        params:set("vintage_noisy_saw", val)
        state.popup.name = "NOISY SAW"; state.popup.value = string.format("%.2f", val); state.popup.deadline = util.time() + 1.0; state.popup.active = true
      end
    end
  elseif state.current_page == state.PAGES.PHYSICS then
     if n == 2 and z == 1 then engine.ping_amp(1.0); engine.ping_color(0); engine.ping_trig(1); clock.run(function() clock.sleep(0.05) engine.ping_trig(0) end)
     elseif n == 3 then if z == 1 then _prev_fb = params:get("feedback"); params:set("feedback", 0.95) else if _prev_fb then params:set("feedback", _prev_fb) end end end
  end
end

function Controls.enc(n, d, state)
  local p = state.current_page
  local shift = state.k1_held or state.grid_shift_active or state.synth_btn_held
  
  if p == state.PAGES.MAIN then if n==1 then params:delta("mix", d) elseif n==2 then params:delta("depth", d) elseif n==3 then params:delta("decay", d * 2) end
  elseif p == state.PAGES.PHYSICS then if n==1 then params:delta("feedback", d) elseif n==2 then params:delta("polarity", d) elseif n==3 then params:delta("damping", d) end
  elseif p == state.PAGES.TEXTURE then if n==1 then params:delta("wander", d) elseif n==2 then params:delta("time_scale", d) elseif n==3 then params:delta("frequency", d) end
  elseif p == state.PAGES.MISC then if n==1 then params:delta("grit", d) elseif n==2 then params:delta("dyn_res", d) elseif n==3 then params:delta("fb_tap_pos", d) end
  elseif p == state.PAGES.DIVERGENCE then if n==1 then params:delta("lfo_rate", d * 0.5) elseif n==2 then params:delta("lfo_amt", d * 0.666) elseif n==3 then params:delta("div_base", d * 0.666) end
  elseif p == state.PAGES.OUTPUT then if n==1 then params:delta("tone", d) elseif n==2 then params:delta("amp", d) elseif n==3 then params:delta("skew", d) end
  elseif p == state.PAGES.SYNTH then
     if n==1 then if shift then params:delta("vintage_vol", d) else params:delta("vintage_timbre", d) end
     elseif n==2 then if shift then params:delta("vintage_attack", d) else params:delta("vintage_mix", d) end
     elseif n==3 then 
        if shift then params:delta("vintage_decay", d) 
        else 
            -- CUTOFF AJUSTADO A 0.5 (Mitad de velocidad = Doble resolución)
            params:delta("vintage_cutoff", d * 0.5) 
        end 
     end
  end
end

return Controls
