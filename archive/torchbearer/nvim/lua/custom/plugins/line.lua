local uv = require 'luv'

local current_time = ''
local function set_interval(interval, callback)
  local timer = uv.new_timer()
  local function ontimeout()
    callback(timer)
  end
  uv.timer_start(timer, interval, interval, ontimeout)
  return timer
end

local function update_wakatime()
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, pid = uv.spawn('wakatime-cli', {
    args = { '--today' },
    stdio = { stdin, stdout, stderr },
  }, function(code, signal) -- on exit
    stdin:close()
    stdout:close()
    stderr:close()
  end)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      current_time = '🕜 ' .. data:sub(1, #data - 2) .. ' '
    end
  end)
end

set_interval(5000, update_wakatime)

local function get_wakatime()
  return current_time
end

return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('lualine').setup {
      theme = 'gruvbox',
      disabled_filetypes = { 'neo-tree' },
      sections = {
        lualine_y = {
          get_wakatime,
        },
      },
    }
  end,
}
