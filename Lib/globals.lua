-- archivo: lib/globals.lua
-- versión: V211 (Manual Semitones Scales)

local Globals = {}

Globals.GRID = {
  WIDTH = 16, NAV_ROW = 8,
  B_OFF = 0, B_DIM = 1, B_MED = 5, B_HI = 14,
  B_HOLD_OFF = 4, B_HOLD_ON = 12,
  B_LATCH_OFF = 5, B_LATCH_ON = 14,
  DOUBLE_CLICK_TIME = 0.4, LONG_PRESS_TIME = 1.0, LATCH_WINDOW = 0.08
}

Globals.LFO_SHAPES = {"SINE", "TRI", "SAW", "SQUARE", "S&H", "SMOOTH"}

-- DEFINICIÓN HÍBRIDA:
-- type="12TET" -> Usa 'intervals' (semitonos)
-- type="JI"    -> Usa 'ratios' (multiplicadores)

Globals.SCALES = {
  -- GRUPO A: Occidentales (Intervalos Semitonos)
  {name = "Major", type = "12TET", intervals = {0, 2, 4, 5, 7, 9, 11}},
  {name = "Minor", type = "12TET", intervals = {0, 2, 3, 5, 7, 8, 10}},
  {name = "Dorian", type = "12TET", intervals = {0, 2, 3, 5, 7, 9, 10}},
  {name = "Phrygian", type = "12TET", intervals = {0, 1, 3, 5, 7, 8, 10}},
  {name = "Lydian", type = "12TET", intervals = {0, 2, 4, 6, 7, 9, 11}},
  {name = "Mixolydian", type = "12TET", intervals = {0, 2, 4, 5, 7, 9, 10}},
  {name = "Min Pent", type = "12TET", intervals = {0, 3, 5, 7, 10}},
  {name = "Maj Pent", type = "12TET", intervals = {0, 2, 4, 7, 9}},
  
  -- GRUPO B: Color
  {name = "Hirajoshi", type = "12TET", intervals = {0, 2, 3, 7, 8}}, -- 5 notas
  {name = "Insen", type = "12TET", intervals = {0, 1, 5, 7, 10}},     -- 5 notas
  {name = "Harm Minor", type = "12TET", intervals = {0, 2, 3, 5, 7, 8, 11}},
  {name = "Whole Tone", type = "12TET", intervals = {0, 2, 4, 6, 8, 10}},
  
  -- GRUPO C: JI (Ratios)
  {name = "JI 5-Lim Maj", type = "JI", ratios = {1, 1.125, 1.25, 1.333, 1.5, 1.666, 1.875}},
  {name = "JI 7-Lim Blues", type = "JI", ratios = {1, 1.166, 1.333, 1.4, 1.5, 1.75}},
  {name = "JI Pythagor", type = "JI", ratios = {1, 1.125, 1.265, 1.333, 1.5, 1.687, 1.898}},
  {name = "JI La Monte", type = "JI", ratios = {1, 1.107, 1.125, 1.148, 1.3125, 1.291, 1.476}}
}

function Globals.new()
  local s = {
    current_page = 1, k1_held = false, grid_shift_active = false, mode = 1, 
    popup = { active = false, name = "", value = "", deadline = 0 },
    PAGES = { MAIN = 1, PHYSICS = 2, TEXTURE = 3, MISC = 4, DIVERGENCE = 5, OUTPUT = 6, SYNTH = 7 },
    PAGE_NAMES = {"MAIN", "PHYSICS", "TEXTURE", "MISC", "DIVERGENCE", "OUTPUT", "SYNTH"}
  }
  return s
end

return Globals
