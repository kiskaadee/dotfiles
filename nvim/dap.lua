-- Debug Adapter Protocol (DAP) Setup for Neovim

local ok, dap = pcall(require, 'dap')
if not ok then
  return
end

-- 1. Standard Debug Keybindings
vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F9>', function() dap.toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<F10>', function() dap.step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F11>', function() dap.step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F12>', function() dap.step_out() end, { desc = 'Debug: Step Out' })

vim.keymap.set('n', '<leader>b', function() dap.toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function()
  vim.ui.input({ prompt = 'Breakpoint Condition: ' }, function(input)
    if input then dap.set_breakpoint(input) end
  end)
end, { desc = 'Debug: Conditional Breakpoint' })

vim.keymap.set('n', '<leader>dr', function() dap.repl.open() end, { desc = 'Debug: Open REPL' })
vim.keymap.set('n', '<leader>dl', function() dap.run_last() end, { desc = 'Debug: Run Last' })

-- 2. Debug UI Integration (if nvim-dap-ui is installed)
local ui_ok, dapui = pcall(require, 'dapui')
if ui_ok then
  dapui.setup()
  dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
  dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
  dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

  vim.keymap.set('n', '<leader>du', function() dapui.toggle() end, { desc = 'Debug: Toggle UI' })
end

-- 3. Language Debug Adapters

-- Python Debugging (via debugpy)
dap.adapters.python = {
  type = 'executable',
  command = 'python',
  args = { '-m', 'debugpy.adapter' },
}

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = 'Launch File',
    program = '${file}',
    pythonPath = function()
      local venv = vim.fn.getenv('VIRTUAL_ENV')
      if venv ~= vim.NIL and venv ~= '' then
        return venv .. '/bin/python'
      end
      return '/usr/bin/python'
    end,
  },
}

-- Rust / C / C++ Debugging (via codelldb / gdb)
dap.adapters.codelldb = {
  type = 'server',
  port = '${port}',
  executable = {
    command = 'codelldb',
    args = { '--port', '${port}' },
  },
}

dap.configurations.rust = {
  {
    name = 'Launch Rust Binary',
    type = 'codelldb',
    request = 'launch',
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
}

-- JavaScript / TypeScript Debugging (via node / pwa-node)
dap.adapters.node2 = {
  type = 'executable',
  command = 'node',
  args = { vim.fn.stdpath('data') .. '/mason/packages/node-debug2-adapter/out/src/nodeDebug.js' },
}

dap.configurations.javascript = {
  {
    name = 'Launch Node File',
    type = 'node2',
    request = 'launch',
    program = '${file}',
    cwd = '${workspaceFolder}',
  },
}
dap.configurations.typescript = dap.configurations.javascript
