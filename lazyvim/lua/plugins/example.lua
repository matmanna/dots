-- since this is just an example spec, don't actually load anything here and return an empty spec
-- stylua: ignore
--if true then return {} end
--
local uv = require 'luv'

local current_time = ""
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

  local handle, pid = uv.spawn("wakatime-cli", {
    args = { "--today" },
    stdio = { stdin, stdout, stderr },
  }, function(code, signal) -- on exit
    stdin:close()
    stdout:close()
    stderr:close()
  end)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      current_time = "🕜 " .. data:sub(1, #data - 2) .. " "
    end
  end)
end

set_interval(5000, update_wakatime)

local function get_wakatime()
  return current_time
end

return { -- add gruvbox
  {
    "xiyaowong/transparent.nvim",
    config = function()
      require("transparent").setup({
        -- table: default groups
        groups = {
          "Normal",
          "NormalNC",
          "Comment",
          "Constant",
          "Special",
          "Identifier",
          "Statement",
          "PreProc",
          "Type",
          "Underlined",
          "Todo",
          "String",
          "Function",
          "Conditional",
          "Repeat",
          "Operator",
          "Structure",
          "LineNr",
          "NonText",
          "SignColumn",
          "CursorLine",
          "CursorLineNr",
          "StatusLine",
          "StatusLineNC",
          "EndOfBuffer",
        },
        -- table: additional groups that should be cleared
        extra_groups = {},
        -- table: groups you don't want to clear
        exclude_groups = {},
        -- function: code to be executed after highlight groups are cleared
        -- Also the user event "TransparentClear" will be triggered
        on_clear = function() end,
      })
      vim.cmd(":TransparentEnable")
    end,
  },
  { "wakatime/vim-wakatime", priority = 100, lazy = false },
  --{ "ellisonleao/gruvbox.nvim" },

  -- Configure LazyVim to load gruvbox
  --{
  --  "LazyVim/LazyVim",
  --  opts = {
  --    colorscheme = "gruvbox",
  --  },
  --},
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local my_filename = require("lualine.components.filename"):extend()
      my_filename.apply_icon = require("lualine.components.filetype").apply_icon
      my_filename.icon_hl_cache = {}

      require("lualine").setup({
        theme = "tokyonight",
        disabled_filetypes = { "neo-tree" },
        sections = {
          lualine_y = {
            get_wakatime,
          },
        },
      })
    end,
  },
}
