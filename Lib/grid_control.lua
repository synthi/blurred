-- archivo: lib/grid_control.lua
-- versión: V216 (Octave Unlock)

local GC = {}
local Globals = require 'blurred/lib/globals'
local MusicUtil = require 'musicutil'

GC.led_buffer = {}
GC.dirty = true
GC.timer = nil

GC.hold_active = false
GC.latch_active = false
GC.latch_timer = 0
GC.keys_down_count = 0

-- TABLAS DE ESTADO
GC.held_notes = {}   -- { [degree] = {id, x, y, source} }
GC.seq_visuals = {}  -- { [degree] = true/false }

GC.rain_flash = {} 
GC.recording_pending = {} 

GC.seqs_synth = {}
GC.seqs_rain = {}

for i = 1, 6 do
  GC.seqs_synth[i] = {state="stopped", data={}, clock=nil, start_time=0, duration=0, press_time=0, clicks=0, just_started=false}
  GC.seqs_rain[i] = {state="stopped", data={}, clock=nil, start_time=0, duration=0, press_time=0, clicks=0, just_started=false}
end

GC.anim_frame = 0

function GC.init(g, state)
  GC.grid = g
  GC.state = state 
  for x = 1, 16 do GC.led_buffer[x] = {}
    for y = 1, 8 do GC.led_buffer[x][y] = 0 end
  end
  GC.timer = metro.init()
  GC.timer.time = 1/30 
  GC.timer.event = function() GC.tick() end
  GC.timer:start()
end

local function stop_note(id) engine.vintage_note_off(id) end

function GC.panic()
  for k, v in pairs(GC.held_notes) do stop_note(v.id) end
  GC.held_notes = {}
  engine.vintage_panic()
end

function GC.soft_release_all()
  for k, v in pairs(GC.held_notes) do stop_note(v.id) end
  GC.held_notes = {}
end

-- MATH HELPER
local function get_freq_ji(root_note, scale_idx, degree)
  local scale_def = Globals.SCALES[scale_idx]
  if scale_def.type == "JI" then
    local root_freq = MusicUtil.note_num_to_freq(root_note)
    local ratios = scale_def.ratios
    local len = #ratios
    -- Math robusta para negativos
    local d0 = degree - 1
    local oct = math.floor(d0 / len)
    -- Modulo en Lua siempre es positivo, perfecto para índices cíclicos
    local idx = (d0 % len) + 1 
    local ratio = ratios[idx]
    return root_freq * ratio * (2 ^ oct)
  else
    local intervals = scale_def.intervals
    local root_freq = MusicUtil.note_num_to_freq(root_note)
    local len = #intervals
    local d0 = degree - 1
    local oct = math.floor(d0 / len)
    local idx = (d0 % len) + 1
    local semi = intervals[idx]
    local total_semis = semi + (oct * 12)
    return root_freq * (2 ^ (total_semis / 12))
  end
end

local function xy_to_degree(x, y) return x + ((6 - y) * 3) end

local function trigger_note_with_id(degree, forced_id)
  local root = params:get("root_note")
  local scale = params:get("scale_idx")
  local oct = params:get("vintage_octave")
  local scale_def = Globals.SCALES[scale]
  local len = 7
  if scale_def.type=="JI" then len = #scale_def.ratios else len = #scale_def.intervals end
  
  -- Cálculo de Grado Final
  local final_degree = degree + (oct * len)
  
  -- FIX V216: Eliminado el límite inferior. 
  -- Ahora permitimos grados negativos (octavas bajas reales).
  -- if final_degree < 1 then final_degree = 1 end  <-- BORRADO
  
  local freq = get_freq_ji(root, scale, final_degree)
  local mode = params:get("vintage_lpg_mode") - 1
  
  local id = forced_id or final_degree 
  engine.vintage_note_on(id, freq, mode)
  return id
end

-- ========================================================
-- INPUT & RECORDING LOGIC
-- ========================================================

local function add_note(degree, x, y, source)
  if GC.held_notes[degree] then stop_note(GC.held_notes[degree].id) end
  local id = trigger_note_with_id(degree, nil) 
  GC.held_notes[degree] = {x=x, y=y, id=id, source=source}
end

local function remove_note(degree)
  if GC.held_notes[degree] then
     stop_note(GC.held_notes[degree].id)
     GC.held_notes[degree] = nil
  end
end

local function check_rec_start(bank)
  for i, seq in ipairs(bank) do
    if seq.state == "rec_armed" then 
       seq.state="rec"; seq.start_time=util.time(); seq.data={}
    end
  end
end

local function note_on_grid(x, y)
  local degree = xy_to_degree(x, y)
  
  check_rec_start(GC.seqs_synth)
  
  if GC.latch_active then
     if GC.keys_down_count == 1 and (util.time() - GC.latch_timer > 0.15) then
        GC.soft_release_all()
        GC.latch_timer = util.time()
     end
     add_note(degree, x, y, "latch")
  elseif GC.hold_active then
     if GC.held_notes[degree] then remove_note(degree) else add_note(degree, x, y, "hold") end
  else
     add_note(degree, x, y, "finger")
  end
  
  local bank = GC.seqs_synth
  for i, seq in ipairs(bank) do
    if seq.state == "rec" or seq.state == "overdub" then
       local t_start
       if seq.state == "rec" then t_start = util.time() - seq.start_time
       else t_start = (util.time() - seq.start_time) % seq.duration end
       
       table.insert(seq.data, {t = t_start, type = "note", x = x, y = y, dur = 0.2})
       
       local key = i .. "_" .. degree
       GC.recording_pending[key] = {seq_idx = i, event_idx = #seq.data, abs_start = util.time()}
       
       if seq.state == "overdub" then
          table.sort(seq.data, function(a,b) return a.t < b.t end)
          if seq.state == "overdub" then GC.recording_pending[key] = nil end
       end
    end
  end
end

local function note_off_grid(x, y)
  local degree = xy_to_degree(x, y)
  
  for i=1,6 do
      local key = i .. "_" .. degree
      local pending = GC.recording_pending[key]
      if pending then
          local seq = GC.seqs_synth[pending.seq_idx]
          if seq and seq.data[pending.event_idx] then
              local real_dur = util.time() - pending.abs_start
              if real_dur < 0.05 then real_dur = 0.05 end
              seq.data[pending.event_idx].dur = real_dur
          end
          GC.recording_pending[key] = nil
      end
  end
  
  if not GC.hold_active and not GC.latch_active then
     if GC.held_notes[degree] and GC.held_notes[degree].source == "finger" then
        remove_note(degree)
     end
  end
end

local function rain_trigger(x, y)
  check_rec_start(GC.seqs_rain)
  
  local amp = util.linlin(1, 7, 1.0, 0.1, y); local color = util.linlin(1, 16, -1, 1, x)
  engine.ping_amp(amp); engine.ping_color(color); engine.ping_trig(1)
  clock.run(function() clock.sleep(0.02) engine.ping_trig(0) end)
  table.insert(GC.rain_flash, {x=x, y=y, brite=14})
  
  local bank = GC.seqs_rain
  for i, seq in ipairs(bank) do
    if seq.state == "rec" then
       table.insert(seq.data, {t=util.time()-seq.start_time, type="rain", x=x, y=y})
    elseif seq.state == "overdub" then
       local t_rel = (util.time() - seq.start_time) % seq.duration
       table.insert(seq.data, {t=t_rel, type="rain", x=x, y=y})
       table.sort(seq.data, function(a,b) return a.t < b.t end)
    end
  end
end

-- ========================================================
-- SEQUENCER RUNNER
-- ========================================================

local function run_seq(seq, mode_type)
  while seq.state == "play" or seq.state == "overdub" do
    local now = 0
    for _, ev in ipairs(seq.data) do
       if seq.state == "stopped" then break end
       local delta = ev.t - now
       if delta > 0 then clock.sleep(delta) end
       now = ev.t
       
       if mode_type == "synth" then
          local deg = xy_to_degree(ev.x, ev.y)
          local safe_id = 10000 + math.random(50000)
          
          GC.seq_visuals[deg] = true 
          trigger_note_with_id(deg, safe_id)
          
          clock.run(function()
             clock.sleep(ev.dur)
             stop_note(safe_id)
             GC.seq_visuals[deg] = nil
          end)
       else
          local amp = util.linlin(1, 7, 1.0, 0.1, ev.y); local color = util.linlin(1, 16, -1, 1, ev.x)
          engine.ping_amp(amp); engine.ping_color(color); engine.ping_trig(1)
          clock.run(function() clock.sleep(0.02) engine.ping_trig(0) end)
          table.insert(GC.rain_flash, {x=ev.x, y=ev.y, brite=14})
       end
    end
    if seq.duration > now then clock.sleep(seq.duration - now) end
  end
end

-- ========================================================
-- UI
-- ========================================================

function GC.tick()
  GC.anim_frame = GC.anim_frame + 0.1
  local beat = math.sin(GC.anim_frame); local pulse_brite = math.floor(util.linlin(-1, 1, 7, 11, beat))
  local fast_beat = math.floor(util.linlin(-1, 1, 2, 15, math.sin(GC.anim_frame * 4)))
  local dub_pulse = math.floor(util.linlin(-1, 1, 8, 15, math.sin(GC.anim_frame * 3)))
  
  for x=1,16 do for y=1,8 do GC.led_buffer[x][y] = 0 end end
  
  if GC.state.mode == 1 then
      local scale = params:get("scale_idx")
      local scale_def = Globals.SCALES[scale]
      local len = 7
      if scale_def.type=="JI" then len = #scale_def.ratios else len = #scale_def.intervals end
      
      for y=1,6 do for x=1,16 do
          local deg = xy_to_degree(x, y)
          if ((deg - 1) % len) == 0 then GC.led_buffer[x][y] = Globals.GRID.B_DIM end
          
          if GC.held_notes[deg] then GC.led_buffer[x][y] = pulse_brite end
          if GC.seq_visuals[deg] then GC.led_buffer[x][y] = 14 end 
      end end
  else
      for k, v in pairs(GC.rain_flash) do
          GC.led_buffer[v.x][v.y] = math.floor(v.brite)
          v.brite = v.brite - 2
          if v.brite <= 0 then GC.rain_flash[k] = nil end
      end
  end
  
  local cs = params:get("scale_idx"); for x=1,16 do GC.led_buffer[x][7] = (x==cs) and 10 or 2 end
  GC.led_buffer[1][8] = GC.state.grid_shift_active and 14 or 4
  GC.led_buffer[2][8] = GC.hold_active and Globals.GRID.B_HOLD_ON or Globals.GRID.B_HOLD_OFF
  GC.led_buffer[3][8] = GC.latch_active and Globals.GRID.B_LATCH_ON or Globals.GRID.B_LATCH_OFF
  
  local active_seqs = (GC.state.mode == 1) and GC.seqs_synth or GC.seqs_rain
  for i=1,6 do
     local s = active_seqs[i]; local b = 2
     if s.state == "stopped" and #s.data > 0 then b = 6
     elseif s.state == "rec_armed" then b = fast_beat
     elseif s.state == "rec" then b = 15
     elseif s.state == "play" then b = 10
     elseif s.state == "overdub" then b = dub_pulse 
     end
     GC.led_buffer[3+i][8] = b
  end
  
  local pg = GC.state.current_page
  GC.led_buffer[10][8] = (pg == 7) and 15 or 6 
  for i=1,6 do GC.led_buffer[10+i][8] = (pg == i) and 15 or 4 end
  GC.redraw_grid()
end

function GC.key(x, y, z, state)
  GC.dirty = true
  if y <= 6 then
     if state.mode == 1 then
        if z==1 then GC.keys_down_count = GC.keys_down_count + 1; note_on_grid(x,y)
        else GC.keys_down_count = GC.keys_down_count - 1; note_off_grid(x,y) end
     else if z==1 then rain_trigger(x, y) end end
  elseif y == 7 then if z==1 then params:set("scale_idx", x); state.popup.name = "SCALE"; state.popup.value = Globals.SCALES[x].name; state.popup.deadline = util.time()+1; state.popup.active = true end
  elseif y == 8 then
     
     if x == 1 then 
        if z == 1 then
           state.grid_shift_active = true
           GC.shift_clicks = (GC.shift_clicks or 0) + 1
           if GC.shift_clicks == 1 then
              clock.run(function() clock.sleep(0.3); GC.shift_clicks = 0 end)
           elseif GC.shift_clicks == 2 then GC.panic(); GC.shift_clicks = 0 end
        else state.grid_shift_active = false end
        
     elseif x == 2 and z == 1 then
        if state.grid_shift_active then state.mode = (state.mode==1) and 2 or 1; state.popup.name="MODE"; state.popup.value=(state.mode==1) and "SYNTH" or "RAIN"; state.popup.deadline=util.time()+1; state.popup.active=true
        else GC.hold_active = not GC.hold_active; if GC.hold_active then GC.latch_active=false end; if not GC.hold_active then GC.soft_release_all() end end
        
     elseif x == 3 and z == 1 then
        GC.latch_active = not GC.latch_active; if GC.latch_active then GC.hold_active=false end; if not GC.latch_active then GC.soft_release_all() end
        
     elseif x>=4 and x<=9 then
        local idx = x-3; local seq = (state.mode == 1) and GC.seqs_synth[idx] or GC.seqs_rain[idx]
        local mode_type = (state.mode == 1) and "synth" or "rain"
        if z==1 then 
           seq.press_time = util.time()
           if seq.state == "stopped" and #seq.data == 0 then seq.state = "rec_armed"; seq.data = {}; seq.instant_rec = true else seq.instant_rec = false end
        else
           if not seq.instant_rec then
               if (util.time() - seq.press_time) > 1.0 then if seq.clock then clock.cancel(seq.clock) end; seq.state="stopped"; seq.data={}; seq.clicks=0
               else 
                  seq.clicks = seq.clicks + 1
                  if seq.clicks == 1 then
                     clock.run(function() clock.sleep(0.25)
                        if seq.clicks == 2 then if seq.clock then clock.cancel(seq.clock) end; seq.state="stopped"
                        else 
                           if seq.state=="stopped" then
                              if #seq.data==0 then seq.state="rec_armed"; seq.data={}
                              else seq.state="play"; seq.clock = clock.run(function() run_seq(seq, mode_type) end) end
                           elseif seq.state=="rec" or seq.state=="rec_armed" then 
                              if seq.state=="rec_armed" then seq.state="stopped" else seq.duration = util.time() - seq.start_time; seq.state="play"; seq.clock = clock.run(function() run_seq(seq, mode_type) end) end
                           elseif seq.state=="play" then seq.state="overdub"
                           elseif seq.state=="overdub" then seq.state="play" end
                        end
                        seq.clicks = 0
                     end)
                  end
               end
           end
        end
     elseif x==10 then if z==1 then state.current_page=7; state.synth_btn_held=true else state.synth_btn_held=false end
     elseif x>=11 then if z==1 then state.current_page=x-10 end end
  end
end

function GC.redraw_grid()
  local g = GC.grid; g:all(0)
  for x=1,16 do for y=1,8 do local v=math.floor(GC.led_buffer[x][y]); if v>0 then g:led(x,y,v) end end end
  g:refresh()
end

return GC
