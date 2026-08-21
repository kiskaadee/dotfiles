-- =============================================================================
-- Editor Configuration
-- =============================================================================

vim.opt.number = true          -- Show line numbers
vim.opt.relativenumber = true  -- Relative line numbers for easier navigation jumps
vim.opt.shiftwidth = 2         -- 2-space indents
vim.opt.tabstop = 2            -- Tab spacing
vim.opt.expandtab = true       -- Convert tabs to spaces
vim.opt.smartindent = true     -- Intelligent auto-indenting based on file syntax
vim.opt.wrap = false           -- Disable automatic line wrapping
vim.opt.termguicolors = true   -- Enable 24-bit RGB terminal colors
vim.opt.completeopt = { "menu", "menuone", "noinsert" } -- Smooth auto-completion behavior

-- Enable autoread so external file changes are recognized
vim.opt.autoread = true

-- =============================================================================
-- Completion
-- =============================================================================

-- Accept completion with Tab when the completion menu is visible
vim.keymap.set('i', '<Tab>', function()
  if vim.fn.pumvisible() == 1 then
    return '<C-y>'
  else
    return '<Tab>'
  end
end, { expr = true, silent = true })

-- =============================================================================
-- Window / Tmux Seamless Navigation (Ctrl-h/j/k/l)
-- =============================================================================

local function navigate(direction, tmux_direction)
  local current = vim.api.nvim_get_current_win()

  -- Attempt to move within Neovim splits
  vim.cmd('wincmd ' .. direction)

  -- If Neovim moved to another split, we are done
  if vim.api.nvim_get_current_win() ~= current then
    return
  end

  -- If at the boundary and running under tmux, cross into the adjacent tmux pane
  if vim.env.TMUX then
    vim.fn.system({ 'tmux', 'select-pane', tmux_direction })
  end
end

vim.keymap.set('n', '<C-h>', function() navigate('h', '-L') end, { desc = 'Navigate left (Nvim / Tmux)' })
vim.keymap.set('n', '<C-j>', function() navigate('j', '-D') end, { desc = 'Navigate down (Nvim / Tmux)' })
vim.keymap.set('n', '<C-k>', function() navigate('k', '-U') end, { desc = 'Navigate up (Nvim / Tmux)' })
vim.keymap.set('n', '<C-l>', function() navigate('l', '-R') end, { desc = 'Navigate right (Nvim / Tmux)' })

-- =============================================================================
-- Split Creation (Vocabulary matching Tmux: | vertical, - horizontal)
-- =============================================================================

vim.keymap.set('n', '<leader>|', '<cmd>vsplit<CR>', { desc = 'Split vertically' })
vim.keymap.set('n', '<leader>-', '<cmd>split<CR>',  { desc = 'Split horizontally' })
vim.keymap.set('n', '<leader>=', '<C-w>=',          { desc = 'Equalize split sizes' })

-- =============================================================================
-- External File Changes Synchronization (Focus / BufEnter)
-- =============================================================================

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('CheckExternalChanges', { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == '' then
      vim.cmd('checktime')
    end
  end,
})

-- =============================================================================
-- Load LSP & DAP Modules
-- =============================================================================

local lsp_config_path = vim.fn.stdpath('config') .. '/lsp.lua'
if vim.fn.filereadable(lsp_config_path) == 1 then
  dofile(lsp_config_path)
end

local dap_config_path = vim.fn.stdpath('config') .. '/dap.lua'
if vim.fn.filereadable(dap_config_path) == 1 then
  dofile(dap_config_path)
end

