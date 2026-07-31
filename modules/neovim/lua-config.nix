{ config }:

''
require'packer'.startup(function(use)
  use 'L3MON4D3/LuaSnip'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-cmdline'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/nvim-cmp'
  use 'jiangmiao/auto-pairs'
  use 'junegunn/goyo.vim'
  use 'kyazdani42/nvim-tree.lua'
  use 'lukas-reineke/indent-blankline.nvim'
  use 'neovim/nvim-lspconfig'
  use 'numToStr/Comment.nvim'
  use 'nvim-lua/plenary.nvim'
  use 'nvim-lualine/lualine.nvim'
  use 'nvim-telescope/telescope.nvim'
  use 'rmehri01/onenord.nvim'
  use 'saadparwaiz1/cmp_luasnip'
  use 'tpope/vim-eunuch'
  use 'tpope/vim-surround'
  use 'lewis6991/gitsigns.nvim'
  use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim' }
  use {
    'nvim-telescope/telescope-fzf-native.nvim',
    run = 'nix-shell -p cmake --command "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release"'
  }
  use { 'nvim-telescope/telescope-ui-select.nvim', requires = 'nvim-telescope/telescope.nvim' }
  use { 'aznhe21/actions-preview.nvim', requires = 'nvim-telescope/telescope.nvim' }
  use {
    'smoka7/hop.nvim',
    config = function()
      require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
    end
  }
end)

--------------------------------------------------------------------------------
-- Common
--------------------------------------------------------------------------------

local HOME = os.getenv('HOME')

vim.g.mapleader = ' '

vim.opt.colorcolumn = { '81' }
vim.opt.compatible = false
vim.opt.completeopt = { 'menuone', 'longest', 'preview', 'noselect' }
vim.opt.conceallevel = 0
vim.opt.cursorline = true
vim.opt.encoding = 'UTF-8'
vim.opt.expandtab = true
vim.opt.hidden = true
vim.opt.history = 999
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.incsearch = true
vim.opt.number = true

vim.opt.scrolloff = 12

vim.opt.showcmd = true
vim.opt.showmode = false
vim.opt.showtabline = 2
vim.opt.signcolumn = 'yes'
vim.opt.smartcase = true
vim.opt.swapfile = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.ttimeoutlen = 0
-- Only reaches floats that pass no border of their own; telescope and cmp keep theirs.
vim.opt.winborder = 'rounded'
vim.opt.wildignore = { '*/tmp/*', '*.so', '*.swp', '*.zip', '*.svg', '*.png', '*.jpg', '*.gif', 'node_modules', 'dist', 'build' }

local kmapopts = { silent = true }

${if config.base.keyboard.layout == "hallmack" then ''
vim.keymap.set('n', '<leader>h', ':set hlsearch!<CR>', { noremap = true })
'' else ''
vim.keymap.set('n', '<F3>', ':set hlsearch!<CR>', { noremap = true })
''}

vim.keymap.set('n', '<leader>cd', ':cd %:h<CR>', { noremap = true })
vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true })
vim.keymap.set('n', '<leader><leader>w', ':w!<CR>', { noremap = true })

vim.keymap.set('n', '<C-w>', function()
  local bufs = vim.fn.getbufinfo({buflisted = 1})
  if #bufs > 1 then
    vim.cmd('bp|bd #')
  else
    vim.cmd('bd')
  end
end, kmapopts)
vim.keymap.del('n', '<C-w><C-D>')
vim.keymap.del('n', '<C-w>d')
vim.keymap.del('x', 'an')
vim.keymap.del('o', 'an')

${if config.base.keyboard.layout == "hallmack" then ''
vim.keymap.set('n', '<C-g>', ':bp<CR>', kmapopts)
vim.keymap.set('n', '<C-o>', ':bn<CR>', kmapopts)
'' else ''
vim.keymap.set('n', '<C-h>', ':bp<CR>', kmapopts)
vim.keymap.set('n', '<C-l>', ':bn<CR>', kmapopts)
''}

${if config.base.keyboard.layout == "hallmack" then ''
vim.keymap.set('n', '<C-A-e>', ':wincmd k<CR>', kmapopts)
vim.keymap.set('n', '<C-A-a>', ':wincmd j<CR>', kmapopts)
vim.keymap.set('n', '<C-A-g>', ':wincmd h<CR>', kmapopts)
vim.keymap.set('n', '<C-A-o>', ':wincmd l<CR>', kmapopts)
'' else ''
vim.keymap.set('n', '<C-A-k>', ':wincmd k<CR>', kmapopts)
vim.keymap.set('n', '<C-A-j>', ':wincmd j<CR>', kmapopts)
vim.keymap.set('n', '<C-A-h>', ':wincmd h<CR>', kmapopts)
vim.keymap.set('n', '<C-A-l>', ':wincmd l<CR>', kmapopts)
''}

${if config.base.keyboard.layout == "hallmack" then ''
-- swap h g
vim.keymap.set({ 'n', 'x', 'o' }, 'g', 'h', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'G', 'H', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'h', 'g', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'H', 'G', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'hh', 'gg', kmapopts)

-- ftplugins (e.g. markdown) re-add gO after startup; delete it so g (left) has no ambiguity
vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  callback = function(ev)
    pcall(vim.keymap.del, 'n', 'gO', { buffer = ev.buf })
  end
})

-- swap j a
vim.keymap.set({ 'n', 'x', 'o' }, 'a', 'j', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'A', 'mzJ`z', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'j', 'o', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'J', 'O', kmapopts)

-- swap k e
vim.keymap.set({ 'n', 'x', 'o' }, 'e', 'k', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'E', 'K', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'k', 'a', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'K', 'A', kmapopts)

-- swap l o
vim.keymap.set({ 'n', 'x', 'o' }, 'o', 'l', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'O', 'L', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'l', 'e', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'L', 'E', kmapopts)
vim.keymap.set('v', '<leader>s', 'o', kmapopts)
vim.keymap.set('v', '<leader>S', 'O', kmapopts)
'' else ""}

${if config.base.keyboard.layout == "hallmack" then ''
vim.keymap.set('v', 'A', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'E', ":m '<-2<CR>gv=gv")
'' else ''
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")
''}
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('x', '<leader>p', '"_dP')

--------------------------------------------------------------------------------
-- Language Server protocol & completion
--------------------------------------------------------------------------------

local hover_opts = {
  title_pos = 'left',
  max_width = 80,
  max_height = 20,
  anchor_bias = 'above',
}

-- Hashed from the client name, not assigned by attachment order, so the colour
-- of a server's hover title is stable across sessions.
local client_color_names = { 'blue', 'green', 'yellow', 'purple', 'cyan' }

local function client_hl(name)
  local sum = 0
  for i = 1, #name do sum = sum + name:byte(i) end
  local idx = (sum % #client_color_names) + 1
  local group = 'LspHoverClient' .. idx
  -- Palette resolved on use: it is only loadable once onenord.setup has run,
  -- which happens further down this file.
  vim.api.nvim_set_hl(0, group, {
    fg = require('onenord.colors').load()[client_color_names[idx]],
    bold = true,
  })
  return group
end

local function lsp_hover()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if c:supports_method('textDocument/hover') then names[#names + 1] = c.name end
  end
  -- Chunks, because vim.lsp.buf.hover never hands the window back: a title given
  -- as [text, highlight] pairs is the only way to colour parts of it separately.
  local title = nil
  if #names > 0 then
    title = {}
    for i, name in ipairs(names) do
      if i > 1 then title[#title + 1] = { '·', 'FloatBorder' } end
      title[#title + 1] = { ' ' .. name .. ' ', client_hl(name) }
    end
  end
  vim.lsp.buf.hover(vim.tbl_extend('force', hover_opts, { title = title }))
end

-- One float configuration behind every diagnostic key, so they cannot drift.
vim.diagnostic.config {
  -- The sign column and the float already carry the diagnostic.
  virtual_text = false,
  float = {
    header = "",              -- drops the redundant "Diagnostics:" line
    source = 'if_many',       -- names the server only when more than one attaches
    severity_sort = true,
  },
  -- Written by codepoint, not as literals: the glyphs live in the font's private
  -- use area and do not survive every pipe and editor they pass through.
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = vim.fn.nr2char(0xf057) .. ' ',  -- times-circle
      [vim.diagnostic.severity.WARN]  = vim.fn.nr2char(0xf071) .. ' ',  -- warning triangle
      [vim.diagnostic.severity.INFO]  = vim.fn.nr2char(0xf05a) .. ' ',  -- info-circle
      [vim.diagnostic.severity.HINT]  = vim.fn.nr2char(0xf0eb) .. ' ',  -- lightbulb
    },
  },
  severity_sort = true,       -- an error outranks a warning for the one sign slot
}

local severity_hl = {
  [vim.diagnostic.severity.ERROR] = 'DiagnosticError',
  [vim.diagnostic.severity.WARN]  = 'DiagnosticWarn',
  [vim.diagnostic.severity.INFO]  = 'DiagnosticInfo',
  [vim.diagnostic.severity.HINT]  = 'DiagnosticHint',
}

-- Border takes the colour of the worst diagnostic it holds. winhighlight is
-- per window, so it is unreachable through vim.diagnostic.config and has to
-- wait for open_float to return the window id.
local function diagnostic_float(opts, severity)
  local _, winid = vim.diagnostic.open_float(opts)
  if not winid then return end
  local worst = severity
  if not worst then
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
    for _, d in ipairs(vim.diagnostic.get(0, { lnum = lnum })) do
      if not worst or d.severity < worst then worst = d.severity end
    end
  end
  local hl = severity_hl[worst]
  if hl then vim.wo[winid].winhighlight = 'FloatBorder:' .. hl end
end

-- The float must open inside on_jump, not after the jump returns: its default
-- close_events include CursorMoved, which the jump itself queues.
local function diagnostic_jump(count)
  return function()
    vim.diagnostic.jump {
      count = count,
      on_jump = function(diagnostic, bufnr)
        diagnostic_float(
          { bufnr = bufnr, scope = 'cursor', focus = false },
          diagnostic and diagnostic.severity
        )
      end,
    }
  end
end

local lsp_on_attach = function(client, bufnr)
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  local bufopts = { noremap = true, silent = true, buffer = bufnr }

  ${if config.base.keyboard.layout == "hallmack" then ''
  vim.keymap.set('n', '<C-a>', diagnostic_jump(1),          bufopts)
  vim.keymap.set('n', '<C-e>', diagnostic_jump(-1),         bufopts)
  vim.keymap.set('n', 'E',     lsp_hover,                   bufopts)
  vim.keymap.set('n', 'hd',    vim.lsp.buf.definition,      bufopts)
  vim.keymap.set('n', 'htd',   vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', 'hi',    vim.lsp.buf.implementation,  bufopts)
  vim.keymap.set('n', 'hr',    vim.lsp.buf.references,      bufopts)
  '' else ''
  vim.keymap.set('n', '<C-j>', diagnostic_jump(1),          bufopts)
  vim.keymap.set('n', '<C-k>', diagnostic_jump(-1),         bufopts)
  vim.keymap.set('n', 'K',     lsp_hover,                   bufopts)
  vim.keymap.set('n', 'gd',    vim.lsp.buf.definition,      bufopts)
  vim.keymap.set('n', 'gtd',   vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', 'gi',    vim.lsp.buf.implementation,  bufopts)
  vim.keymap.set('n', 'gr',    vim.lsp.buf.references,      bufopts)
  ''}
  vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename,          bufopts)
  -- Visual mode too: the range is what makes extract-to-function offerable.
  vim.keymap.set({ 'n', 'x' }, '<leader>a', function()
    require('actions-preview').code_actions()
  end, bufopts)
  vim.keymap.set('n', '<leader>e', diagnostic_float,            bufopts)
  vim.keymap.set('n', '<leader>f', vim.lsp.buf.format,          bufopts)
  vim.keymap.set('n', '<leader>l', vim.diagnostic.setloclist,   bufopts)
end

local cmp = require'cmp'
local luasnip = require'luasnip'
local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

cmp.setup {
  snippet = {
    expand = function(args)
      require'luasnip'.lsp_expand(args.body)
    end,
  },
  mapping = {
    ['<C-space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
    ['<Tab>'] = {
      i = function()
        if luasnip.expandable() then
          luasnip.expand()
        elseif cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.jumpable(1) then
          luasnip.jump(1)
        else
          vim.api.nvim_feedkeys(t('<Tab>'), 'n', true)
        end
      end,
      c = function()
        cmp.select_next_item()
      end,
      s = function()
        luasnip.jump(1)
      end
    },
    ['<S-Tab>'] = {
      i = function()
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          vim.api.nvim_feedkeys(t('<C-d>'), 'n', true)
        end
      end,
      c = function()
        cmp.select_prev_item()
      end,
      s = function()
        luasnip.jump(-1)
      end
    },
    ['<C-e>'] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
  },
  sources = cmp.config.sources {
    { name = 'nvim_lsp' },
    { name = 'luasnip' }
  }
}

cmp.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  }
})

cmp.setup.cmdline(':', {
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})

-- Server names: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
-- Servers needing settings of their own are set up below rather than listed here.
local lsp_servers = {
  'arduino_language_server', 'bashls', 'clangd', 'cssls', 'dockerls', 'eslint',
  'gopls', 'hls', 'html', 'jsonls', 'marksman', 'rust_analyzer', 'yamlls',
}

local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()

local lsp_flags = {
  debounce_text_changes = 15
}

-- vim.lsp.config deep-merges onto whatever nvim-lspconfig ships for the server,
-- so opts only has to carry what differs from that default.
local function lsp_setup(name, opts)
  vim.lsp.config(name, vim.tbl_extend('force', {
    on_attach = lsp_on_attach,
    capabilities = lsp_capabilities,
    flags = lsp_flags,
  }, opts or {}))
  vim.lsp.enable(name)
end

for _, lsp in ipairs(lsp_servers) do
  lsp_setup(lsp)
end

vim.keymap.set('n', '<leader>b', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end)

-- vtsls, not ts_ls: it answers codeAction/resolve, so a refactor carries its edit
-- and can be previewed before it is applied. Running both at once is unsupported.
-- Settings take the VSCode names, not tsserver's includeInlay* ones, and every
-- hint not named here is already off by default.
lsp_setup('vtsls', {
  settings = {
    typescript = {
      inlayHints = {
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
    javascript = {
      inlayHints = {
        functionLikeReturnTypes = { enabled = true },
      },
    },
  },
})

-- nil implements no formatter of its own and silently answers an empty edit list
-- unless handed a command. Bracket syntax because nil is a Lua keyword.
lsp_setup('nil_ls', {
  settings = {
    ['nil'] = {
      formatting = { command = { 'nixfmt' } },
    },
  },
})

-- Only VIMRUNTIME goes in the library: pulling all of runtimepath in makes every
-- plugin a workspace file and stalls the server on this config's own directory.
lsp_setup('lua_ls', {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
      workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
    },
  },
})

-- Remove built-in LSP keybindings that conflict with custom ones in lsp_on_attach
-- Alternatives: gr=references, gi=implementation, gtd=type_def, <leader>r=rename, <leader>a=code_action
vim.keymap.del('n', 'gO')
vim.keymap.del('n', 'gra')
vim.keymap.del('x', 'gra')
vim.keymap.del('n', 'gri')
vim.keymap.del('n', 'grn')
vim.keymap.del('n', 'grr')
vim.keymap.del('n', 'grt')
vim.keymap.del('n', 'grx')

require'luasnip.loaders.from_lua'.load({ paths = '~/.config/nvim/snippets' })

--------------------------------------------------------------------------------
-- TreeSitter
--------------------------------------------------------------------------------

-- The `main` branch of nvim-treesitter starts nothing on its own, so highlighting,
-- indenting and the selection maps below attach per buffer, and only where a
-- parser for the filetype actually loaded.

-- Ancestor node stack backing the incremental selection maps, one per buffer.
local ts_sel = {}

-- Reselect a node charwise. Node ends are exclusive; an end column of 0 means
-- the node stops at the start of the line, so the selection ends on the one above.
local function ts_reselect(node)
  local srow, scol, erow, ecol = node:range()
  if ecol == 0 then
    if erow == 0 then return end
    erow = erow - 1
    ecol = #(vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or "")
  end
  if vim.fn.mode():match('[vV\22]') then
    vim.cmd('normal! ' .. vim.keycode('<Esc>'))
  end
  vim.fn.setpos("'<", { 0, srow + 1, scol + 1, 0 })
  vim.fn.setpos("'>", { 0, erow + 1, ecol, 0 })
  vim.cmd('normal! gv')
end

-- Ranges captured as @local.scope by the language's locals query, keyed for
-- lookup by an ancestor walk.
local function ts_scope_ranges(buf)
  local ranges = {}
  local parser = vim.treesitter.get_parser(buf, nil, { error = false })
  local query = parser and vim.treesitter.query.get(parser:lang(), 'locals')
  if not query then return ranges end
  for id, node in query:iter_captures(parser:parse()[1]:root(), buf, 0, -1) do
    if query.captures[id] == 'local.scope' then
      ranges[table.concat({ node:range() }, ',')] = true
    end
  end
  return ranges
end

-- Walk up from the top of the stack until `accept` takes an ancestor, pushing it.
local function ts_grow(accept)
  local buf = vim.api.nvim_get_current_buf()
  local stack = ts_sel[buf]
  if not stack or #stack == 0 then return end
  local node = stack[#stack]:parent()
  while node do
    if accept(node) then
      stack[#stack + 1] = node
      ts_reselect(node)
      return
    end
    node = node:parent()
  end
end

local function ts_sel_init()
  local buf = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(buf, nil, { error = false })
  if not parser then return end
  parser:parse()  -- parsing is otherwise driven by redraw, and may not have run yet
  local node = vim.treesitter.get_node()
  if not node then return end
  ts_sel[buf] = { node }
  ts_reselect(node)
end

-- <TAB>: the next ancestor that actually covers more text than the current node.
local function ts_sel_node_incremental()
  local stack = ts_sel[vim.api.nvim_get_current_buf()]
  local current = stack and stack[#stack]
  if not current then return end
  local range = table.concat({ current:range() }, ',')
  ts_grow(function(node) return table.concat({ node:range() }, ',') ~= range end)
end

-- <CR> in visual mode: the next ancestor the locals query calls a scope.
local function ts_sel_scope_incremental()
  local scopes = ts_scope_ranges(vim.api.nvim_get_current_buf())
  ts_grow(function(node) return scopes[table.concat({ node:range() }, ',')] end)
end

local function ts_sel_node_decremental()
  local stack = ts_sel[vim.api.nvim_get_current_buf()]
  if not stack or #stack < 2 then return end
  stack[#stack] = nil
  ts_reselect(stack[#stack])
end

vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if not lang or not pcall(vim.treesitter.start, args.buf, lang) then return end

    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

    -- Buffer-local so that quickfix, netrw, Neogit and the pickers keep their <CR>.
    local opts = { silent = true, buffer = args.buf }
    vim.keymap.set('n', '<CR>', ts_sel_init, opts)
    vim.keymap.set('x', '<CR>', ts_sel_scope_incremental, opts)
    vim.keymap.set('x', '<TAB>', ts_sel_node_incremental, opts)
    vim.keymap.set('x', '<S-TAB>', ts_sel_node_decremental, opts)
  end,
})

-- Stacks hold TSNodes, which keep their tree alive; drop them with the buffer.
vim.api.nvim_create_autocmd('BufDelete', {
  callback = function(args) ts_sel[args.buf] = nil end,
})

--------------------------------------------------------------------------------
-- Folding (uses TreeSitter)
--------------------------------------------------------------------------------

vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldlevel = 99         -- Start with folds open but manageable
vim.opt.foldlevelstart = 99    -- Prevents mass collapsing on first fold

--------------------------------------------------------------------------------
-- View peristance
--------------------------------------------------------------------------------

vim.opt.viewoptions:remove('curdir') -- Omit current working directory

-- Ordinary file buffers only; Neogit and NvimTree carry path-shaped names that
-- mkview would otherwise write views for. Tests the current buffer, not the
-- event's, because mkview acts on the window in focus.
local function view_worthy()
  return #vim.bo.buftype == 0 and #vim.api.nvim_buf_get_name(0) > 0
end

-- noautocmd is load-bearing: every view file ends in `doautoall SessionLoadPost`,
-- and Neogit answers that event by wiping every buffer it owns.
vim.api.nvim_create_autocmd('BufWinLeave', {
  callback = function()
    if view_worthy() then vim.cmd('silent! noautocmd mkview') end
  end
})

vim.api.nvim_create_autocmd('BufWinEnter', {
  callback = function()
    if view_worthy() then vim.cmd('silent! noautocmd loadview') end
  end
})

--------------------------------------------------------------------------------
-- Neogit
--------------------------------------------------------------------------------

local neogit = require('neogit')
neogit.setup()
vim.keymap.set('n', '<leader>g', ':Neogit<CR>', { noremap = true })

--------------------------------------------------------------------------------
-- GitSigns
--------------------------------------------------------------------------------

require('gitsigns').setup {
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  signs_staged = {
    add          = { text = '┃' },
    change       = { text = '┃' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  signcolumn = true,           -- Toggle with `:Gitsigns toggle_signs`
  numhl      = true,           -- Toggle with `:Gitsigns toggle_numhl`
  linehl     = false,          -- Toggle with `:Gitsigns toggle_linehl`
  word_diff  = false,          -- Toggle with `:Gitsigns toggle_word_diff`
  current_line_blame = false,  -- Toggle with `:Gitsigns toggle_current_line_blame`
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function mapb(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    ${if config.base.keyboard.layout == "hallmack" then ''
      local hunk_mapping_next = ',a'
      local hunk_mapping_prev = ',e'
    '' else ''
      local hunk_mapping_next = ',j'
      local hunk_mapping_prev = ',k'
    ''}

    -- Navigation
    mapb('n', hunk_mapping_next, function()
      if vim.wo.diff then return hunk_mapping_next end
      vim.schedule(function() gs.next_hunk() end)
      return '<Ignore>'
    end, { expr = true })

    mapb('n', hunk_mapping_prev, function()
      if vim.wo.diff then return hunk_mapping_prev end
      vim.schedule(function() gs.prev_hunk() end)
      return '<Ignore>'
    end, { expr = true })

    -- Actions
    mapb({ 'n', 'v' }, '<leader>,s', ':Gitsigns stage_hunk<CR>')
    mapb('n',          '<leader>,S', gs.stage_buffer)
    mapb({ 'n', 'v' }, '<leader>,r', ':Gitsigns reset_hunk<CR>')
    mapb('n',          '<leader>,R', gs.reset_buffer)
    mapb('n', '<leader>,u', gs.undo_stage_hunk)
    mapb('n', ',p', gs.preview_hunk)
    mapb('n', ',b', function() gs.blame_line { full = true } end)
    mapb('n', ',d', gs.diffthis)
    mapb('n', ',D', function() gs.diffthis('~') end)

    -- Text object
    mapb({ 'o', 'x' }, 'in', ':<C-U>Gitsigns select_hunk<CR>')
  end
}

--------------------------------------------------------------------------------
-- Hop
--------------------------------------------------------------------------------

local hop = require'hop'
local hop_after_cursor = require'hop.hint'.HintDirection.AFTER_CURSOR
local hop_before_cursor = require'hop.hint'.HintDirection.BEFORE_CURSOR

local hop_char = function(direction, inclusive_jump)
  return function()
    hop.hint_char1({ direction = direction, current_line_only = true, inclusive_jump = inclusive_jump })
  end
end

local hop_word = function(inclusive_jump)
  return function()
    hop.hint_words({ inclusive_jump = inclusive_jump })
  end
end

vim.keymap.set('n', 'f', hop_char(hop_after_cursor,  false), { noremap = true })
vim.keymap.set('n', 'F', hop_char(hop_before_cursor, false), { noremap = true })
vim.keymap.set('o', 'f', hop_char(hop_after_cursor,  true),  { noremap = true })
vim.keymap.set('o', 'F', hop_char(hop_before_cursor, true),  { noremap = true })
vim.keymap.set('o', 't', hop_char(hop_after_cursor,  false), { noremap = true })
vim.keymap.set('o', 'T', hop_char(hop_before_cursor, false), { noremap = true })
vim.keymap.set({ 'n', 'v' }, 'm', hop_word(false), { noremap = true })
vim.keymap.set('o',          'm', hop_word(true),  { noremap = true })

--------------------------------------------------------------------------------
-- Theme & Status line
--------------------------------------------------------------------------------

require'onenord'.setup {
  theme = 'dark'
}

require'lualine'.setup {
  options = { theme = 'onenord' },
  tabline = { lualine_a = { 'buffers' } }
}
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })

-- Below onenord.setup, which defines both groups itself and would win otherwise.
local float_palette = require('onenord.colors').load()
vim.api.nvim_set_hl(0, 'FloatBorder', { fg = float_palette.light_gray, bg = 'none' })
vim.api.nvim_set_hl(0, 'FloatTitle', { fg = float_palette.blue, bg = 'none', bold = true })

--------------------------------------------------------------------------------
-- GitSigns staged highlights
--------------------------------------------------------------------------------

-- gitsigns derives its GitSignsStaged* groups when required and later skips any
-- already set, so requiring it above the colorscheme freezes them off-palette.
-- Redefining below onenord puts them back on the unstaged hue.

local function blend(fg, bg, alpha)
  local out = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local f, b = math.floor(fg / shift) % 256, math.floor(bg / shift) % 256
    out = out + math.floor(f + (b - f) * alpha + 0.5) * shift
  end
  return out
end

local function gitsigns_staged_hl()
  local bg = tonumber(require('onenord.colors').load().bg:sub(2), 16)
  for _, ty in ipairs({ 'Add', 'Change', 'Delete', 'Changedelete', 'Topdelete', 'Untracked' }) do
    local unstaged = vim.api.nvim_get_hl(0, { name = 'GitSigns' .. ty, link = false })
    if unstaged.fg then
      -- Same hue, sunk toward the background: the sign character already carries
      -- the staged/unstaged distinction, so the colour only has to recede.
      local fg = blend(unstaged.fg, bg, 0.4)
      -- Nr and Cul are separate groups because numhl and cursorline are both on.
      for _, kind in ipairs({ "", 'Nr', 'Cul' }) do
        vim.api.nvim_set_hl(0, 'GitSignsStaged' .. ty .. kind, { fg = fg })
      end
    end
  end
end

gitsigns_staged_hl()
-- Registered after gitsigns' own ColorScheme handler, so it overwrites rather
-- than being skipped.
vim.api.nvim_create_autocmd('ColorScheme', { callback = gitsigns_staged_hl })

--------------------------------------------------------------------------------
-- Indent Blankline
--------------------------------------------------------------------------------

vim.opt.termguicolors = true
vim.opt.list = true

local highlight = {
  'CursorColumn',
  'Whitespace',
}
require('ibl').setup {
  indent = { highlight = highlight, char = "" },
  whitespace = {
    highlight = highlight,
    remove_blankline_trail = false,
  },
  scope = { enabled = false },
}

--------------------------------------------------------------------------------
-- NvimTree
--------------------------------------------------------------------------------

local api = require 'nvim-tree.api'
local function nvimtree_on_attach(bufnr)
  local function opts(desc)
    return {
      desc = 'nvim-tree: ' .. desc,
      buffer = bufnr,
      noremap = true,
      silent = true,
      nowait = true
    }
  end

  vim.keymap.set('n', '<C-]>', api.tree.change_root_to_node, opts('CD'))
  vim.keymap.set('n', '<C-e>', api.node.show_info_popup, opts('Info'))
  vim.keymap.set('n', '<C-r>', api.fs.rename_sub, opts('Rename: Omit Filename'))
  vim.keymap.set('n', '<C-t>', api.node.open.tab, opts('Open: New Tab'))
  vim.keymap.set('n', '<C-v>', api.node.open.vertical, opts('Open: Vertical Split'))
  vim.keymap.set('n', '<C-x>', api.node.open.horizontal, opts('Open: Horizontal Split'))
  vim.keymap.set('n', '<BS>', api.node.navigate.parent_close, opts('Close Directory'))
  vim.keymap.set('n', '<CR>', api.node.open.edit, opts('Open'))
  vim.keymap.set('n', '<Tab>', api.node.open.preview, opts('Open Preview'))
  vim.keymap.set('n', '>', api.node.navigate.sibling.next, opts('Next Sibling'))
  vim.keymap.set('n', '<', api.node.navigate.sibling.prev, opts('Previous Sibling'))
  vim.keymap.set('n', '.', api.node.run.cmd, opts('Run Command'))
  vim.keymap.set('n', '-', api.tree.change_root_to_parent, opts('Up'))
  ${if config.base.keyboard.layout == "hallmack" then ''
  vim.keymap.set('n', 'j', api.fs.create, opts('Create'))
  '' else ''
  vim.keymap.set('n', 'o', api.fs.create, opts('Create'))
  ''}
  vim.keymap.set('n', 'B', api.tree.toggle_no_buffer_filter, opts('Toggle Filter: No Buffer'))
  vim.keymap.set('n', 'c', api.fs.copy.node, opts('Copy'))
  vim.keymap.set('n', 'C', api.tree.toggle_git_clean_filter, opts('Toggle Filter: Git Clean'))
  vim.keymap.set('n', '[c', api.node.navigate.git.prev, opts('Prev Git'))
  vim.keymap.set('n', ']c', api.node.navigate.git.next, opts('Next Git'))
  vim.keymap.set('n', 'd', api.fs.remove, opts('Delete'))
  vim.keymap.set('n', 'D', api.fs.trash, opts('Trash'))
  vim.keymap.set('n', 'L', api.tree.expand_all, opts('Expand All'))
  vim.keymap.set('n', 'F', api.live_filter.clear, opts('Clean Filter'))
  vim.keymap.set('n', 'f', api.live_filter.start, opts('Filter'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('Help'))
  vim.keymap.set('n', 'I', api.tree.toggle_gitignore_filter, opts('Toggle Filter: Git Ignore'))
  vim.keymap.set('n', 'A', api.node.navigate.sibling.last, opts('Last Sibling'))
  vim.keymap.set('n', 'E', api.node.navigate.sibling.first, opts('First Sibling'))
  vim.keymap.set('n', 'm', api.marks.toggle, opts('Toggle Bookmark'))
  vim.keymap.set('n', 'p', api.fs.paste, opts('Paste'))
  vim.keymap.set('n', 'P', api.node.navigate.parent, opts('Parent Directory'))
  vim.keymap.set('n', 'q', api.tree.close, opts('Close'))
  vim.keymap.set('n', 'r', api.fs.rename, opts('Rename'))
  vim.keymap.set('n', 'R', api.tree.reload, opts('Refresh'))
  vim.keymap.set('n', 's', api.node.run.system, opts('Run System'))
  vim.keymap.set('n', 'S', api.tree.search_node, opts('Search'))
  vim.keymap.set('n', 'U', api.tree.toggle_custom_filter, opts('Toggle Filter: Hidden'))
  vim.keymap.set('n', 'W', api.tree.collapse_all, opts('Collapse'))
  vim.keymap.set('n', 'x', api.fs.cut, opts('Cut'))
  vim.keymap.set('n', 'y', api.fs.copy.filename, opts('Copy Name'))
  vim.keymap.set('n', 'Y', api.fs.copy.relative_path, opts('Copy Relative Path'))
  vim.keymap.set('n', '<2-LeftMouse>', api.node.open.edit, opts('Open'))
  vim.keymap.set('n', '<2-RightMouse>', api.tree.change_root_to_node, opts('CD'))
end

require'nvim-tree'.setup {
  sort_by = "case_sensitive",
  view = { adaptive_size = true },
  filters = { dotfiles = false },
  renderer = { group_empty = true },
  git = { ignore = false },
  on_attach = nvimtree_on_attach
}
vim.keymap.set('n', '<C-n>', api.tree.toggle, {
  desc = "nvim-tree: Toggle Tree",
  noremap = true,
  silent = true,
  nowait = true
})
vim.keymap.set('n', '<leader>j', ':NvimTreeFindFile<CR>', {
  desc = "nvim-tree: Find File",
  noremap = true,
  silent = true,
  nowait = true
})

--------------------------------------------------------------------------------
-- Telescope
--------------------------------------------------------------------------------

require('telescope').setup {
  defaults = {
    file_ignore_patterns = { 'node_modules', 'build', 'dist' },
    borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
    mappings = {
      ${if config.base.keyboard.layout == "hallmack" then ''
        n = {
          ['j'] = false,
          ['k'] = false,
          ['gg'] = false,
          ['G'] = false,
          ['a'] = 'move_selection_next',
          ['e'] = 'move_selection_previous',
          ['hh'] = 'move_to_top',
          ['H'] = 'move_to_bottom'
        }
      '' else ""}
    }
  },
  extensions = {
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case"         -- or "ignore_case" or "respect_case"
    },
    ['ui-select'] = { require('telescope.themes').get_dropdown {} }
  }
}

require('telescope').load_extension('fzf')

-- Routes every vim.ui.select through telescope, which is what the LSP rename
-- conflict prompts and the plugins' own pickers fall back to.
require('telescope').load_extension('ui-select')

local tls_builtin = require('telescope.builtin')

vim.keymap.set('n', 'tf', tls_builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', 'tt', tls_builtin.git_files, { desc = 'Telescope find git files' })
vim.keymap.set('n', 'tg', tls_builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', 'ts', tls_builtin.grep_string, { desc = 'Telescope grep string under cursor' })
vim.keymap.set('n', 'tb', tls_builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', 'th', tls_builtin.help_tags, { desc = 'Telescope help tags' })

--------------------------------------------------------------------------------
-- Code actions
--------------------------------------------------------------------------------

-- Replaces the bare vim.lsp.buf.code_action list on <leader>a with a picker that
-- previews each action as a diff before it is applied. Without highlight_command
-- that preview is plain text; delta renders it in a terminal buffer instead.
require('actions-preview').setup {
  telescope = require('telescope.themes').get_dropdown {},
  highlight_command = { require('actions-preview.highlight').delta() },
}

--------------------------------------------------------------------------------
-- Comment
--------------------------------------------------------------------------------

vim.keymap.del('o', 'gc')
vim.keymap.del('x', 'gc')
vim.keymap.del('x', 'gx')
vim.keymap.del('n', 'gc')
vim.keymap.del('n', 'gcc')
vim.keymap.del('n', 'gx')

${if config.base.keyboard.layout == "hallmack" then ''
require'Comment'.setup {
  toggler = {
    line = 'hcc',
    block = 'hbc'
  },
  opleader = {
    line = 'hc',
    block = 'hb'
  },
  extra = {
    above = 'hcA',
    below = 'hca',
    eol = 'hcE'
  },
}
'' else ''
require'Comment'.setup {
  toggler = {
    line = 'gcc',
    block = 'gbc'
  },
  opleader = {
    line = 'gc',
    block = 'gb'
  },
  extra = {
    above = 'gcO',
    below = 'gco',
    eol = 'gcE'
  }
}
''}

--------------------------------------------------------------------------------
-- VimSurround
--------------------------------------------------------------------------------

vim.api.nvim_set_var('surround_no_mappings', true)
vim.keymap.set('n', 'cs', '<Plug>Csurround', kmapopts)

--------------------------------------------------------------------------------
-- VimEunuch
--------------------------------------------------------------------------------

vim.keymap.set('n', '<leader>z', ':SudoEdit %<CR>', { noremap = true })

--------------------------------------------------------------------------------
-- Disable default plugins to avoid keymap conflicts
--------------------------------------------------------------------------------

vim.api.nvim_set_var('loaded_matchit', true)
vim.api.nvim_set_var('loaded_netrwPlugin', true)
''
