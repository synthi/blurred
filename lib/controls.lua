-- archivo: lib/controls.lua
-- versión: V301 (UI Label Fix)

local Controls = {}
local press_times = {} 

function Controls.key(n, z, state)
  if n == 1 then state.k1_held = (z == 1); return end
  if state.k1_held and z == 1 then
    if n == 2 then state.current_page = state.current_page - 1; if state.current_page < 1 then state.current_page = #state.PAGE_NAMES end
    elseif n == 3 then state.current_page = state.current_page + 1; if state.current_page > #state.PAGE_NAMES then state.current_page = 1 end end
    return
  end
  
  local p = state.current_page
  local key_id = p .. "_" .. n

  if p == state.PAGES.MAIN then
     if n == 2 and z == 1 then
        local v = params:get("ghost_feed"); params:set("ghost_feed", (v%2)+1)
        state.popup.name = "GHOST FEED"; state.popup.value = (params:get("ghost_feed")==2) and "ON" or "OFF"
        state.popup.deadline = util.time()+1; state.popup.active=true
     elseif n == 3 then
        params:set("time_freeze", z+1) 
        if z==1 then state.popup.name = "TIME FREEZE"; state.popup.value = "ACTIVE"; state.popup.deadline = util.time()+1; state.popup.active=true end
     end

  elseif p == state.PAGES.PHYSICS then
     if z == 1 then
        if n == 2 then
           local h = params:get("feedback_hpf"); h = (h % 5) + 1; params:set("feedback_hpf", h)
           state.popup.name = "FDBK HPF"; state.popup.value = params:string("feedback_hpf"); state.popup.deadline = util.time() + 1.0; state.popup.active = true
        elseif n == 3 then _prev_fb = params:get("feedback"); params:set("feedback", 0.95) end
     elseif z == 0 and n == 3 then if _prev_fb then params:set("feedback", _prev_fb) end end

  elseif p == state.PAGES.TEXTURE then
     if z == 1 then
        if n == 2 then
           local f = params:get("texture_freeze"); params:set("texture_freeze", (f % 2) + 1)
           -- LABEL FIX: WANDER FREEZE
           state.popup.name = "WANDER FREEZE"; state.popup.value = (params:get("texture_freeze")==2) and "ON" or "OFF"; state.popup.deadline = util.time() + 1.0; state.popup.active = true
        elseif n == 3 then
           local c = params:get("crystal_mode"); params:set("crystal_mode", (c % 2) + 1)
           state.popup.name = "CRYSTAL"; state.popup.value = (params:get("crystal_mode")==2) and "ON" or "OFF"; state.popup.deadline = util.time() + 1.0; state.popup.active = true
        end
     end

  elseif p == state.PAGES.DIVERGENCE then
     if n == 2 and z == 1 then
        local c = params:get("lfo_shape"); params:set("lfo_shape", (c % 6) + 1)
        state.popup.name = "LFO SHAPE"; state.popup.value = Globals.LFO_SHAPES[params:get("lfo_shape")]; state.popup.deadline = util.time() + 1.0; state.popup.active = true
     elseif n == 3 then
        if z == 1 then
           engine.div_swell(1); press_times[key_id] = util.time()
           state.popup.name = "SWELL"; state.popup.value = ">>>"; state.popup.deadline = util.time() + 1.0; state.popup.active = true
        else
           local dur = util.time() - (press_times[key_id] or util.time()); local rel_time = util.clamp(dur, 0.1, 5.0)
           engine.div_swell_time(rel_time); engine.div_swell(0)
        end
     end

  elseif p == state.PAGES.OUTPUT then
     if n == 2 then
        -- LIBRE
     elseif n == 3 and z == 1 then
        local b = params:get("bass_focus_idx"); b = (b % 4) + 1; params:set("bass_focus_idx", b)
        local labels = {"OFF", "50Hz", "100Hz", "200Hz"}
        state.popup.name = "BASS FOCUS"; state.popup.value = labels[b]; state.popup.deadline = util.time() + 1.0; state.popup.active = true
     end
     
  elseif p == state.PAGES.MISC then
     if z == 1 then
       if n == 2 then
          local c = params:get("ef_clamp"); params:set("ef_clamp", (c % 2) + 1)
          state.popup.name = "CLAMP"; state.popup.value = params:string("ef_clamp"); state.popup.deadline = util.time() + 1.0; state.popup.active = true
       elseif n == 3 then
          local o = params:get("vintage_octave"); o = o + 1; if o > 1 then o = -1 end; params:set("vintage_octave", o)
          state.popup.name = "OCTAVE"; state.popup.value = o; state.popup.deadline = util.time() + 1.0; state.popup.active = true
       end
     end

  elseif p == state.PAGES.SYNTH then
    if z == 1 then
      if n == 2 then
        local m = params:get("vintage_lpg_mode"); params:set("vintage_lpg_mode", (m % 2) + 1)
        state.popup.name = "LPG MODE"; state.popup.value = params:string("vintage_lpg_mode"); state.popup.deadline = util.time() + 1.0; state.popup.active = true
      elseif n == 3 then
        local val = params:get("vintage_noisy_saw"); val = val + 0.25; if val > 1.0 then val = 0 end; params:set("vintage_noisy_saw", val)
        state.popup.name = "NOISY SAW"; state.popup.value = string.format("%.2f", val); state.popup.deadline = util.time() + 1.0; state.popup.active = true
      end
    end
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
     elseif n==3 then if shift then params:delta("vintage_decay", d) else params:delta("vintage_cutoff", d * 0.5) end end
  end
end

return Controls
