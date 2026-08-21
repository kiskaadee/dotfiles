-- Minimal Native Neovim LSP Setup (Neovim 0.11+)

-- Python LSP: Pyright (Type checking and navigation)
if vim.lsp.config then
  vim.lsp.config('pyright', {})
  vim.lsp.enable('pyright')

  -- Python LSP: Ruff (Ultra-fast Linting and Auto-formatting)
  vim.lsp.config('ruff', {
    on_attach = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  })
  vim.lsp.enable('ruff')

  -- Rust LSP: Rust Analyzer
  vim.lsp.config('rust_analyzer', {})
  vim.lsp.enable('rust_analyzer')

  -- TypeScript LSP: ts_ls
  vim.lsp.config('ts_ls', {})
  vim.lsp.enable('ts_ls')

  -- Lua LSP: lua_ls
  vim.lsp.config('lua_ls', {})
  vim.lsp.enable('lua_ls')

  -- Java LSP: Eclipse jdtls
  vim.lsp.config('jdtls', {})
  vim.lsp.enable('jdtls')

  -- TOML LSP: taplo
  vim.lsp.config('taplo', {})
  vim.lsp.enable('taplo')

  -- Markdown LSP: marksman
  vim.lsp.config('marksman', {})
  vim.lsp.enable('marksman')

  -- KDL LSP: kdl-lsp (KDL Language Server for Niri configs)
  vim.lsp.config('kdl_lsp', {
    cmd = { 'kdl-lsp' },
    filetypes = { 'kdl' },
    root_markers = { '.git' },
  })
  vim.lsp.enable('kdl_lsp')
end


-- Configure LSP Keybindings and features on attach
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local opts = { buffer = ev.buf }
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    
    -- Standard navigation & actions
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

    -- Enable built-in LSP completion
    if client and client.supports_method and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end


    -- Auto-format on save using LSP
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = ev.buf,
      callback = function()
        vim.lsp.buf.format({ async = false })
      end,
    })
  end,
})
