return {

  'akinsho/flutter-tools.nvim',
  lazy = false,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'stevearc/dressing.nvim',
    'neovim/nvim-lspconfig',
  },
  config = function()
    require('flutter-tools').setup {
      lsp = {
        color = {
          enabled = true,
          background = true,
          virtual_text = false,
        },
        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          enableSnippets = true,
        },
        -- Remove the on_attach if you want to use the default keymaps
      },
    }
    require('telescope').load_extension 'flutter'
  end,
}
