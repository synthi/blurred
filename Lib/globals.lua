-- archivo: lib/globals.lua
-- versión: V107 (Page Rename)

local Globals = {}

Globals.MODES = {
  SCRAPE = 1,
  RAIN = 2
}

Globals.GRID = {
  WIDTH = 16,
  NAV_ROW = 8,
  B_OFF = 0,
  B_DIM = 2,
  B_MED = 6,
  B_HI = 11,
  B_MAX = 15,
  DOUBLE_CLICK_TIME = 0.4,
  LONG_PRESS_TIME = 1.0
}

Globals.LFO_SHAPES = {"SINE", "TRI", "SAW", "SQUARE", "S&H", "SMOOTH"}

function Globals.new()
  local s = {
    current_page = 1,
    k1_held = false,
    grid_shift_active = false,
    
    -- Estado del Popup
    popup = {
      active = false,
      name = "",
      value = "",
      deadline = 0
    },
    
    PAGES = {
      MAIN = 1,
      PHYSICS = 2,
      TEXTURE = 3,
      MISC = 4,      -- RENOMBRADO DE DYNAMICS
      DIVERGENCE = 5,
      OUTPUT = 6
    },
    PAGE_NAMES = {"MAIN", "PHYSICS", "TEXTURE", "MISC", "DIVERGENCE", "OUTPUT"}
  }
  return s
end

return Globals
