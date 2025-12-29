-- archivo: lib/grid_control.lua
-- versión: V100 (Rebrand)

local GC = {}
local Globals = require 'blurred/lib/globals'

GC.mode = Globals.MODES.RAIN 
GC.led_buffer = {}
GC.held_keys = {}
GC.dirty = true 
GC.last_scrape_y = 4

GC.seqs = {}
for i = 1, 12 do
  GC.seqs[i] = {
    state = "stopped", data = {}, 
    start_time = 0, duration = 0, play_ptr = 1, play_time = 0,
    press_time = 0, clicks = 0
  }
end

function GC.init(g, state)
  GC.grid = g
  GC.state = state 
  for x = 1, 16 do GC.led_buffer[x] = {}
    for y = 1, 8 do GC.led_buffer[x][y] = 0 end
  end
  GC.timer = metro.init()
  GC.timer.time = 1/15 
  GC.timer.event = function() GC.tick() end
  GC.timer:start()
end

function GC.tick()
  local dt = 1/15
  local changed = false 
  
  for x = 1, 16 do
    for y = 1, 7 do
      if GC.led_buffer[x][y] > 0 then
        GC.led_buffer[x][y] = math.max(0, GC.led_buffer[x][y] - 3)
        changed = true
      end
    end
  end
  
  for i, seq in ipairs(GC.seqs) do
    if seq.state == "play" and #seq.data > 0 then
      seq.play_time = seq.play_time + dt
      if seq.play_time >= seq.duration then seq.play_time = 0; seq.play_ptr = 1 end
      while seq.play_ptr <= #seq.data and seq.data[seq.play_ptr].time <= seq.play_time do
        local ev = seq.data[seq.play_ptr]
        GC.trigger_note_from_seq(ev.x, ev.y, ev.mode, ev.x2)
        seq.play_ptr = seq.play_ptr + 1
      end
    elseif seq.state == "rec" then changed = true end
  end
  
  if changed then GC.dirty = true end
  if GC.dirty then GC.redraw_grid(); GC.dirty = false end
end

function GC.trigger_note_from_seq(x, y, recorded_mode, x2)
  GC.led_buffer[x][y] = Globals.GRID.B_MAX
  if x2 then GC.led_buffer[x2][y] = Globals.GRID.B_MAX end
  GC.dirty = true
  
  if recorded_mode == Globals.MODES.RAIN then
    local amp = util.linlin(1, 7, 1.0, 0.1, y)
    local color = util.linlin(1, 16, -1, 1, x)
    local scale = {60, 62, 65, 67, 69, 72, 74, 77}
    local note_idx = (x % #scale) + 1
    local pitch = scale[note_idx]
    engine.ping_amp(amp); engine.ping_color(color); engine.ping_pitch(pitch); engine.ping_trig(1)
    clock.run(function() clock.sleep(0.02) engine.ping_trig(0) end)
  elseif recorded_mode == Globals.MODES.SCRAPE then
     local center_x = x
     if x2 then center_x = (x + x2) / 2 end
     local span = 0
     if x2 then span = math.abs(x2 - x) end
     local color = util.linlin(1, 16, -1, 1, center_x)
     engine.scrape_color(color)
     engine.scrape_pitch(util.linlin(7, 1, 0.1, 0.9, y))
     engine.scrape_vel(util.clamp(span / 8, 0.05, 1.0))
     clock.run(function() clock.sleep(0.1) engine.scrape_vel(0) end)
  end
end

function GC.trigger_note_manual(x, y)
  GC.led_buffer[x][y] = Globals.GRID.B_MAX
  GC.dirty = true
  
  if GC.mode == Globals.MODES.RAIN then
    local amp = util.linlin(1, 7, 1.0, 0.1, y)
    local color = util.linlin(1, 16, -1, 1, x)
    local scale = {60, 62, 65, 67, 69, 72, 74, 77}
    local note_idx = (x % #scale) + 1
    local pitch = scale[note_idx]
    engine.ping_amp(amp); engine.ping_color(color); engine.ping_pitch(pitch); engine.ping_trig(1)
    clock.run(function() clock.sleep(0.02) engine.ping_trig(0) end)
    
    local offset = (GC.mode == Globals.MODES.RAIN) and 0 or 6
    for i = 1, 6 do
      local seq = GC.seqs[i + offset]
      if seq.state == "rec" then
        table.insert(seq.data, {time = util.time() - seq.start_time, x = x, y = y, mode = GC.mode})
      end
    end
  end
end

function GC.key(x, y, z, state)
  GC.dirty = true
  if y == Globals.GRID.NAV_ROW then
    if z == 1 then
      if x == 1 then engine.ping_amp(1); engine.ping_color(0); engine.ping_trig(1); clock.run(function() clock.sleep(0.05) engine.ping_trig(0) end)
      elseif x == 2 then GC.mode = (GC.mode == Globals.MODES.SCRAPE) and Globals.MODES.RAIN or Globals.MODES.SCRAPE
      elseif x >= 4 and x <= 9 then
        local slot_idx = x - 3
        local offset = (GC.mode == Globals.MODES.RAIN) and 0 or 6
        local abs_idx = slot_idx + offset
        local seq = GC.seqs[abs_idx]
        seq.press_time = util.time()
      elseif x >= 11 then
        local p = x - 10
        if state then state.current_page = p; state.grid_shift_active = true end
      end
    elseif z == 0 then
      if x >= 4 and x <= 9 then
        local slot_idx = x - 3
        local offset = (GC.mode == Globals.MODES.RAIN) and 0 or 6
        local abs_idx = slot_idx + offset
        local seq = GC.seqs[abs_idx]
        local hold_time = util.time() - seq.press_time
        
        if hold_time > Globals.GRID.LONG_PRESS_TIME then
           seq.state = "stopped"; seq.data = {}; seq.step = 1
        else
           seq.clicks = seq.clicks + 1
           if seq.clicks == 1 then
              clock.run(function()
                 clock.sleep(Globals.GRID.DOUBLE_CLICK_TIME)
                 if seq.clicks == 1 then
                    if seq.state == "stopped" then seq.state = "rec"; seq.data = {}; seq.start_time = util.time()
                    elseif seq.state == "rec" then seq.duration = util.time() - seq.start_time; seq.state = "play"; seq.play_time = 0; seq.play_ptr = 1; table.sort(seq.data, function(a,b) return a.time < b.time end)
                    elseif seq.state == "play" then seq.state = "play" end
                 else
                    if seq.state ~= "stopped" then seq.state = "stopped" end
                 end
                 seq.clicks = 0
                 GC.dirty = true
              end)
           end
        end
      elseif x >= 11 and state then state.grid_shift_active = false end
    end
  else
    if z == 1 then
      if GC.mode == Globals.MODES.RAIN then GC.trigger_note_manual(x, y)
      elseif GC.mode == Globals.MODES.SCRAPE then 
         GC.held_keys[x.."_"..y] = {x=x, y=y}
         GC.last_scrape_y = y 
         GC.process_scrape() 
      end
    else
      if GC.mode == Globals.MODES.SCRAPE then GC.held_keys[x.."_"..y] = nil; GC.process_scrape() end
    end
  end
end

function GC.process_scrape()
  GC.dirty = true
  local min_x = 17
  local max_x = 0
  local count = 0
  
  for k, v in pairs(GC.held_keys) do
    count = count + 1
    if v.x < min_x then min_x = v.x end
    if v.x > max_x then max_x = v.x end
    GC.led_buffer[v.x][v.y] = Globals.GRID.B_MED 
  end
  
  if count > 0 then
    local span = max_x - min_x
    local center_x = (max_x + min_x) / 2
    local target_y = GC.last_scrape_y 
    
    local color = util.linlin(1, 16, -1, 1, center_x)
    engine.scrape_color(color)
    engine.scrape_pitch(util.linlin(7, 1, 0.1, 0.9, target_y))
    engine.scrape_vel(util.clamp(span / 8, 0.05, 1.0))
    
    local offset = (GC.mode == Globals.MODES.RAIN) and 0 or 6
    for i = 1, 6 do
      local seq = GC.seqs[i + offset]
      if seq.state == "rec" then
         local save_x = math.floor(center_x - span/2)
         local save_x2 = math.floor(center_x + span/2)
         table.insert(seq.data, {time = util.time() - seq.start_time, x = save_x, x2 = save_x2, y = target_y, mode = Globals.MODES.SCRAPE})
      end
    end
  else engine.scrape_vel(0) end
end

function GC.redraw_grid()
  local g = GC.grid; g:all(0)
  for x = 1, 16 do for y = 1, 7 do local val = math.floor(GC.led_buffer[x][y]); if val > 0 then g:led(x, y, val) end end end
  g:led(1, 8, Globals.GRID.B_MED)
  g:led(2, 8, (GC.mode == Globals.MODES.RAIN) and Globals.GRID.B_MAX or Globals.GRID.B_DIM)
  
  local beat = (util.time() * 4) % 1; local rec_bright = math.floor(util.linlin(0, 1, 4, 10, beat))
  
  local offset = (GC.mode == Globals.MODES.RAIN) and 0 or 6
  for i = 1, 6 do
    local seq = GC.seqs[i + offset]
    local gx = 3 + i
    if seq.state == "stopped" then if #seq.data > 0 then g:led(gx, 8, Globals.GRID.B_DIM) else g:led(gx, 8, Globals.GRID.B_OFF + 1) end
    elseif seq.state == "rec" then g:led(gx, 8, rec_bright)
    elseif seq.state == "play" then g:led(gx, 8, Globals.GRID.B_HI) end
  end
  
  local current = 1; if GC.state then current = GC.state.current_page end
  for i = 1, 6 do 
     local bright = (i == current) and Globals.GRID.B_MAX or Globals.GRID.B_DIM
     g:led(10 + i, 8, bright) 
  end 
  g:refresh()
end

return GC