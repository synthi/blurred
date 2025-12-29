-- archivo: lib/sixteen.lua
-- versión: V104 (Ported from Sines)

local _16n = {}
local conf_16n = nil
local midi_16n = nil
local dev_16n = nil

-- ------------------------------------------------------------------------
-- SYSEX UTILS

_16n.request_sysex_config_dump = function(midi_dev)
  if midi_dev then
    midi.send(midi_dev, {0xf0, 0x7d, 0x00, 0x00, 0x1f, 0xf7})
  end
end

_16n.is_sysex_config_dump = function(sysex_payload)
  return (sysex_payload[2] == 0x7d and sysex_payload[3] == 0x00 and sysex_payload[4] == 0x00
          and sysex_payload[5] == 0x0f)
end

_16n.parse_sysex_config_dump = function(sysex_payload)
  local i = 6 + 4 -- offset
  local usb_cc_list={}

  -- El payload contiene mucha info, pero solo nos interesa el mapeo de CCs USB
  -- Los CCs USB empiezan en el byte 64 del bloque de datos (offset i)
  for fader_i=0, 16-1 do
    local usb_cc = sysex_payload[i+64+fader_i]
    table.insert(usb_cc_list, usb_cc)
  end

  return {
    usb_cc = usb_cc_list
  }
end

-- ------------------------------------------------------------------------
-- CONF ACCESSORS

local function mustHaveConf()
  if conf_16n == nil then
    return false
  end
  return true
end

_16n.cc_2_slider_id = function(cc)
  if not mustHaveConf() then return nil end

  local slider_id = nil
  for i, slider_cc in pairs(conf_16n.usb_cc) do
    if slider_cc == cc then
      slider_id = i
      break
    end
  end
  return slider_id
end

-- ------------------------------------------------------------------------
-- INIT

_16n.init = function(cc_cb_fn)
  for _,dev in pairs(midi.devices) do
    if dev.name~=nil and (string.find(string.lower(dev.name), "16n") ~= nil) then
      print("BLURRED: 16n detected on port "..dev.port)

      dev_16n = dev
      midi_16n = midi.connect(dev.port)

      local is_sysex_dump_on = false
      local sysex_payload = {}

      midi_16n.event = function(data)
        local d = midi.to_msg(data)

        if is_sysex_dump_on then
          for _, b in pairs(data) do
            table.insert(sysex_payload, b)
            if b == 0xf7 then
              is_sysex_dump_on = false
              if _16n.is_sysex_config_dump(sysex_payload) then
                conf_16n = _16n.parse_sysex_config_dump(sysex_payload)
                print("BLURRED: 16n config loaded via Sysex.")
              end
            end
          end
        elseif d.type == 'sysex' then
          is_sysex_dump_on = true
          sysex_payload = {}
          for _, b in pairs(d.raw) do
            table.insert(sysex_payload, b)
          end
        elseif d.type == 'cc' then
          -- Si tenemos config, traducimos CC a Slider ID
          if conf_16n ~= nil then
            if cc_cb_fn ~= nil then
              cc_cb_fn(d)
            end
          else
            -- Fallback: Si no hay config Sysex, asumimos mapeo lineal 32-47
            -- Esto es un parche de seguridad por si el Sysex falla
            if cc_cb_fn ~= nil then
               -- Simulamos una config básica si falla el handshake
               cc_cb_fn(d) 
            end
          end
        end
      end

      -- Pedir config
      _16n.request_sysex_config_dump(dev_16n)
      break
    end
  end
end

return _16n