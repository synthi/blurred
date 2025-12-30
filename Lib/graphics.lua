-- archivo: lib/graphics.lua
-- versión: V116 (Better SAW/SQUARE Icons)

local Graphics = {}

local trail_history = {} 
local MAX_TRAILS = 10 
local anim_phase = 0
local lfo_phase = 0

local function draw_param_inline(label, value, x, y, align)
  screen.move(x, y)
  local str = label .. ": " .. value
  if align == "right" then screen.text_right(str) else screen.text(str) end
end

local function draw_lfo_icon(shape, x, y)
  screen.level(15)
  local w = 24 
  local h = 10 -- Altura ajustada
  local x_start = x - (w/2)
  local y_mid = y + 6
  local y_top = y_mid - 5
  local y_bot = y_mid + 5
  
  if shape == 1 then -- SINE
    screen.move(x_start, y_mid)
    for i=0, w do screen.pixel(x_start + i, y_mid + math.sin((i/w) * 12.56) * 5) end; screen.stroke()
    
  elseif shape == 2 then -- TRI
    screen.move(x_start, y_mid)
    screen.line(x_start + w/4, y_top)
    screen.line(x_start + w/2, y_mid)
    screen.line(x_start + (3*w)/4, y_bot)
    screen.line(x_start + w, y_mid)
    screen.stroke()
    
  elseif shape == 3 then -- SAW (Mejorada: Rampa + Caída Vertical)
    screen.move(x_start, y_bot)       -- Inicio abajo
    screen.line(x_start + w/2, y_top) -- Sube rampa
    screen.line(x_start + w/2, y_bot) -- Cae vertical
    screen.line(x_start + w, y_top)   -- Sube rampa 2
    screen.line(x_start + w, y_bot)   -- Cae vertical 2
    screen.stroke()
    
  elseif shape == 4 then -- SQUARE (Mejorada: Pulsos claros)
    local cycle = w/2
    screen.move(x_start, y_top)           -- Start High
    screen.line(x_start + cycle/2, y_top) -- High Line
    screen.line(x_start + cycle/2, y_bot) -- Drop
    screen.line(x_start + cycle, y_bot)   -- Low Line
    screen.line(x_start + cycle, y_top)   -- Rise
    screen.line(x_start + cycle*1.5, y_top) -- High Line 2
    screen.line(x_start + cycle*1.5, y_bot) -- Drop 2
    screen.line(x_start + w, y_bot)       -- Low Line 2
    screen.stroke()
    
  elseif shape == 5 then -- S&H
    screen.move(x_start, y_mid); for i=0, w, 4 do local r = math.random(-4, 4); screen.line(x_start + i, y_mid + r); screen.line(x_start + i + 4, y_mid + r) end; screen.stroke()
    
  elseif shape == 6 then -- SMOOTH
    for i=0, w do screen.pixel(x_start + i, y_mid + math.random(-3,3)) end; screen.fill()
  end
end

-- DIBUJO DE GOTA DE PLASMA
local function draw_plasma_drop(x, y, size)
  screen.level(4)
  screen.circle(x, y, size + 2.5) 
  screen.fill()
  
  screen.level(15)
  screen.circle(x, y, size + 1.0) 
  screen.fill()
  
  screen.level(15)
  screen.pixel(x + 2, y - 2)
  screen.fill()
end

local function draw_spray_point(x, y, radius, density, sharpness)
  if sharpness > 0.8 then
     screen.pixel(x, y); screen.fill()
  else
     local effective_rad = radius * (1.5 - sharpness)
     for i = 1, density do
       local r = math.random() * effective_rad
       local a = math.random() * 6.28
       screen.pixel(x + math.cos(a)*r, y + math.sin(a)*r)
       screen.fill()
     end
  end
end

local function draw_chain(state)
  local cx = 61 
  local cy = 34
  local stages = 50 
  
  local time_scale = params:get("time_scale")
  local freq = params:get("frequency") 
  local wander = params:get("wander") * 0.4
  local skew = params:get("skew") * 0.5     
  local div_base = params:get("div_base") * 0.55
  local lfo_rate = params:get("lfo_rate")
  local lfo_amt = params:get("lfo_amt")
  local feedback = params:get("feedback")
  local grit = params:get("grit")
  local decay = params:get("decay")
  local depth = params:get("depth")
  local polarity = params:get("polarity")
  local damping = params:get("damping") 
  
  local sharpness = util.linlin(0, 2, 0, 1, decay)
  if sharpness > 1 then sharpness = 1 end

  local base_w = 107 
  local variable_w = 7 
  local total_width = base_w + (variable_w * time_scale)
  
  local start_x = cx - (total_width / 2)
  local step = total_width / stages
  
  anim_phase = anim_phase + (0.1 + (wander * 0.2))
  lfo_phase = lfo_phase + (lfo_rate * 0.05)
  local lfo_val = math.sin(lfo_phase)
  
  local div_total = div_base + (lfo_val * lfo_amt)
  if div_total < 0 then div_total = 0 end
  if div_total > 1 then div_total = 1 end
  
  local jitter_amt = grit * 4.0 
  local spray_radius = 0.5 + (feedback * 6) 
  local spray_density = 1 + math.floor(feedback * 4)
  
  local div_pow = math.pow(div_total, 3) * 0.25
  local depth_l = util.clamp(depth + div_pow, 0, 1)
  local depth_r = util.clamp(depth - div_pow, 0, 1)
  
  local idx_l = math.floor(depth_l * (stages - 1)) + 1
  local idx_r = math.floor(depth_r * (stages - 1)) + 1
  
  local current_frame = {}
  
  for i = 1, stages do
    local zig = (i % 2 == 0) and -1 or 1
    local skew_offset = zig * skew * 10
    
    local norm_x = (i - 1) / (stages - 1)
    local centered_x = (norm_x - 0.5) * 2 
    local parabola = centered_x * centered_x 
    local poly_offset = parabola * polarity * -12 
    
    local grit_jit_x = (math.random() - 0.5) * jitter_amt
    local grit_jit_y = (math.random() - 0.5) * jitter_amt
    
    local px = start_x + (i * step) + grit_jit_x
    local py_base = cy + poly_offset + (math.sin((i * freq * 0.5) + anim_phase) * wander * 15) + grit_jit_y
    
    local split_offset = div_total * 12 
    
    local is_ball_l = (i == idx_l)
    local is_ball_r = (i == idx_r)
    
    table.insert(current_frame, {
      x = px,
      y_l = py_base - split_offset + skew_offset,
      y_r = py_base + split_offset + skew_offset,
      rad = spray_radius,
      den = spray_density,
      sharp = sharpness,
      ball_l = is_ball_l,
      ball_r = is_ball_r
    })
  end
  
  table.insert(trail_history, 1, current_frame)
  if #trail_history > MAX_TRAILS then table.remove(trail_history) end
  
  for t = #trail_history, 1, -1 do
    local frame = trail_history[t]
    local brightness = 1
    if t == 1 then brightness = 15
    elseif t == 2 then brightness = 4
    end
    
    if t > (12 - (damping * 10)) then brightness = 0 end
    
    if brightness > 0 then
        screen.level(brightness)
        for _, pt in ipairs(frame) do
          if brightness > 1 or math.random() > 0.6 then
             draw_spray_point(pt.x, pt.y_l, pt.rad, pt.den, pt.sharp)
             draw_spray_point(pt.x, pt.y_r, pt.rad, pt.den, pt.sharp)
          end
          if t == 1 then
             if pt.ball_l then draw_plasma_drop(pt.x, pt.y_l, 2.0) end
             if pt.ball_r then draw_plasma_drop(pt.x, pt.y_r, 2.0) end
          end
        end
    end
  end
end

local function draw_popup(state)
  if state.popup.active then
    if util.time() > state.popup.deadline then
      state.popup.active = false
    else
      screen.level(0)
      screen.rect(10, 54, 108, 10) 
      screen.fill()
      
      screen.level(15)
      screen.rect(10, 54, 108, 10) 
      screen.stroke()
      
      screen.move(64, 61)
      screen.text_center(state.popup.name .. ": " .. state.popup.value)
    end
  end
end

function Graphics.draw(state)
  screen.level(15)
  screen.move(128, 8)
  screen.text_right(state.PAGE_NAMES[state.current_page])
  
  local bot_y = 62
  local top_y = 8
  
  if state.current_page ~= state.PAGES.DIVERGENCE then
     draw_chain(state)
  end
  
  if state.current_page == state.PAGES.MAIN then
    draw_param_inline("Mix", math.floor(params:get("mix")*100).."%", 0, top_y, "left")
    draw_param_inline("Depth", math.floor(params:get("depth")*100).."%", 0, bot_y, "left")
    draw_param_inline("Delay", util.round(params:get("decay"), 0.01).."s", 128, bot_y, "right")

  elseif state.current_page == state.PAGES.PHYSICS then
    draw_param_inline("Fdbk", math.floor(params:get("feedback")*100).."%", 0, top_y, "left")
    local pol = params:get("polarity"); local pol_txt = ""
    if pol < -0.3 then pol_txt = " (MTL)" elseif pol > 0.3 then pol_txt = " (WTR)" end
    draw_param_inline("Pol", util.round(pol, 0.01)..pol_txt, 0, bot_y, "left")
    draw_param_inline("Damp", util.round(params:get("damping"), 0.01), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.TEXTURE then
    draw_param_inline("Wander", util.round(params:get("wander"), 0.01), 0, top_y, "left")
    draw_param_inline("T.Scale", string.format("x%.2f", params:get("time_scale")), 0, bot_y, "left")
    draw_param_inline("Freq", util.round(params:get("frequency"), 0.01), 128, bot_y, "right")
    
  elseif state.current_page == state.PAGES.MISC then
     draw_param_inline("Grit", util.round(params:get("grit"), 0.01), 0, top_y, "left")
     draw_param_inline("D.Res", math.floor(params:get("dyn_res")*100).."%", 0, bot_y, "left")
     local tap = params:get("fb_tap_pos")
     draw_param_inline("Tap", util.round(tap, 0.1), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.DIVERGENCE then
     local shape = params:get("lfo_shape")
     screen.level(3); screen.move(64, 25); screen.text_center("LFO SHAPE")
     draw_lfo_icon(shape, 64, 30) 
     
     draw_param_inline("Rate", string.format("%.2f Hz", params:get("lfo_rate")), 0, top_y, "left")
     draw_param_inline("Amt", util.round(params:get("lfo_amt"), 0.01), 0, bot_y, "left")
     draw_param_inline("Div", util.round(params:get("div_base"), 0.01), 128, bot_y, "right")

  elseif state.current_page == state.PAGES.OUTPUT then
    local t = params:get("tone"); local t_txt = util.round(t, 0.01)
    if t < -0.1 then t_txt = "LPF " .. t_txt elseif t > 0.1 then t_txt = "HPF " .. t_txt end
    draw_param_inline("Tone", t_txt, 0, top_y, "left")
    draw_param_inline("Level", util.round(params:get("amp"), 0.01), 0, bot_y, "left")
    draw_param_inline("Skew", util.round(params:get("skew"), 0.01), 128, bot_y, "right")
  end
  
  draw_popup(state)
end

return Graphics
