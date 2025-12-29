-- archivo: lib/graphics.lua
-- versión: V105 (Popup Draw)

local Graphics = {}

local trail_history = {} 
local MAX_TRAILS = 3
local anim_phase = 0

local function draw_param_v2(label, value, x, y_base, align)
  screen.level(3)
  local lbl_y = y_base - 7
  if y_base == 18 then lbl_y = 8 end
  
  screen.move(x, lbl_y)
  if align == "right" then screen.text_right(label) else screen.text(label) end
  screen.level(15)
  screen.move(x, y_base)
  if align == "right" then screen.text_right(value) else screen.text(value) end
end

local function draw_lfo_icon(shape, x, y)
  screen.level(15)
  screen.move(x, y+4)
  if shape == 1 then for i=0, 10 do screen.pixel(x+i, y+4 + math.sin(i*0.6)*4) end
  elseif shape == 2 then screen.line(x+5, y); screen.line(x+10, y+8)
  elseif shape == 3 then screen.line(x+10, y); screen.line(x+10, y+8)
  elseif shape == 4 then screen.line(x+5, y+4); screen.line(x+5, y); screen.line(x+10, y); screen.line(x+10, y+8)
  elseif shape == 5 then screen.rect(x, y+2, 3, 3); screen.rect(x+6, y, 3, 3)
  elseif shape == 6 then for i=0, 10 do screen.pixel(x+i, y+4 + math.random(-2,2)) end
  end
  screen.stroke()
end

local function draw_chain(state)
  local cx = 64
  local cy = 28 
  local stages = 111
  local step = 3
  local visual_points = math.floor(stages / step)
  
  local pol = params:get("polarity")
  local depth = params:get("depth")
  local real_depth_idx = math.floor(depth * (stages - 1)) + 1
  local wander = params:get("wander")
  local decay = params:get("decay")
  local damping = params:get("damping")
  local skew = params:get("skew")
  local amp = (state.amp_in or 0) * 5.0
  
  local curve_intensity = pol * 12
  local spacing = 3 
  local start_x = cx - ((visual_points * spacing) / 2)
  
  anim_phase = anim_phase + (0.1 + (wander * 0.2))
  
  local current_frame = {}
  for v = 1, visual_points do
    local real_i = v * step 
    local norm_x = (real_i - 1) / (stages - 1)
    local centered_x = (norm_x - 0.5) * 2
    local y_base = (centered_x * centered_x) * curve_intensity
    local y_mod = math.sin((real_i * 0.2) + anim_phase) * (wander * 5)
    local jitter = (math.random() - 0.5) * ((1.0 - damping) * 4)
    
    local is_active = false
    if math.abs(real_i - real_depth_idx) < (step / 1.5) then is_active = true end
    
    table.insert(current_frame, {
        x = start_x + ((v-1)*spacing), 
        y = cy + y_base + y_mod + jitter,
        active = is_active
    })
  end
  
  table.insert(trail_history, 1, current_frame)
  if #trail_history > MAX_TRAILS then table.remove(trail_history) end
  
  for t = #trail_history, 1, -1 do
    local frame = trail_history[t]
    local brightness = math.floor(15 / t)
    
    for i, pt in ipairs(frame) do
      local size = 1 + math.floor(decay * 0.1) + math.floor(amp * 4)
      if size > 4 then size = 4 end 
      
      if skew > 0.1 then
         screen.level(2) 
         screen.pixel(pt.x + (skew * 2), pt.y)
         screen.fill()
      end

      screen.level(brightness)
      if t == 1 and pt.active then
         local pulse = size + 2 + math.floor(math.sin(anim_phase * 4))
         screen.rect(pt.x - pulse/2, pt.y - pulse/2, pulse, pulse)
         screen.fill()
      else
         screen.rect(pt.x - size/2, pt.y - size/2, size, size)
         screen.fill()
      end
    end
  end
end

local function draw_popup(state)
  if state.popup.active then
    if util.time() > state.popup.deadline then
      state.popup.active = false
    else
      -- Dibujar Caja
      local w = 80
      local h = 24
      local x = 64 - (w/2)
      local y = 32 - (h/2)
      
      screen.level(0)
      screen.rect(x, y, w, h)
      screen.fill()
      
      screen.level(15)
      screen.rect(x, y, w, h)
      screen.stroke()
      
      screen.move(64, y + 8)
      screen.text_center(state.popup.name)
      
      screen.move(64, y + 18)
      screen.text_center(state.popup.value)
    end
  end
end

function Graphics.draw(state)
  screen.level(15)
  screen.move(64, 8)
  screen.text_center("- " .. state.PAGE_NAMES[state.current_page] .. " -")
  
  local bot_y = 53
  
  if state.current_page ~= state.PAGES.DYNAMICS and state.current_page ~= state.PAGES.DIVERGENCE then
     draw_chain(state)
  end
  
  if state.current_page == state.PAGES.MAIN then
    draw_param_v2("Mix", math.floor(params:get("mix")*100).."%", 0, 18, "left")
    draw_param_v2("Depth", math.floor(params:get("depth")*100).."%", 0, bot_y, "left")
    draw_param_v2("Decay", util.round(params:get("decay"), 0.01), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.PHYSICS then
    draw_param_v2("Fdbk", math.floor(params:get("feedback")*100).."%", 0, 18, "left")
    local pol = params:get("polarity")
    draw_param_v2("Polarity", util.round(pol, 0.01), 0, bot_y, "left")
    screen.level(2); screen.move(35, bot_y)
    if pol < -0.3 then screen.text("METAL")
    elseif pol > 0.3 then screen.text("WATER")
    else screen.text("-") end
    draw_param_v2("Damping", util.round(params:get("damping"), 0.01), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.TEXTURE then
    draw_param_v2("Wander", util.round(params:get("wander"), 0.01), 0, 18, "left")
    draw_param_v2("Time Scale", string.format("x%.2f", params:get("time_scale")), 0, bot_y, "left")
    draw_param_v2("Frequency", util.round(params:get("frequency"), 0.01), 128, bot_y, "right")
    
  elseif state.current_page == state.PAGES.DYNAMICS then
     local amp = (state.amp_in or 0) * 5.0
     local bar_w = 100
     local bar_h = 6
     local bar_x = 14
     local bar_y = 30
     screen.level(2); screen.rect(bar_x, bar_y, bar_w, bar_h); screen.stroke()
     screen.level(15); screen.rect(bar_x, bar_y, bar_w * math.min(amp, 1.0), bar_h); screen.fill()
     screen.level(3); screen.move(64, bar_y - 4); screen.text_center("INPUT ENVELOPE")
     
     draw_param_v2("Grit", util.round(params:get("grit"), 0.01), 0, 18, "left")
     draw_param_v2("Dyn Res", math.floor(params:get("dyn_res")*100).."%", 0, bot_y, "left")
     local clamp = params:get("ef_clamp") == 2 and "ON" or "OFF"
     draw_param_v2("Clamp", clamp, 128, bot_y, "right")

  elseif state.current_page == state.PAGES.DIVERGENCE then
     local shape = params:get("lfo_shape")
     screen.level(3); screen.move(64, 30); screen.text_center("LFO SHAPE")
     draw_lfo_icon(shape, 60, 35)
     draw_param_v2("Rate", string.format("%.2f Hz", params:get("lfo_rate")), 0, 18, "left")
     draw_param_v2("Amount", util.round(params:get("lfo_amt"), 0.01), 0, bot_y, "left")
     draw_param_v2("Divergence", util.round(params:get("div_base"), 0.01), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.OUTPUT then
    local t = params:get("tone")
    local t_txt = util.round(t, 0.01)
    if t < -0.1 then t_txt = "LPF " .. t_txt
    elseif t > 0.1 then t_txt = "HPF " .. t_txt
    else t_txt = "FLAT" end
    draw_param_v2("Tone", t_txt, 0, 18, "left")
    draw_param_v2("Level", util.round(params:get("amp"), 0.01), 0, bot_y, "left")
    draw_param_v2("Skew", util.round(params:get("skew"), 0.01), 128, bot_y, "right")
  end
  
  -- DIBUJAR POPUP AL FINAL (Z-INDEX SUPERIOR)
  draw_popup(state)
end

return Graphics