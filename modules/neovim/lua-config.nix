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
  use { 'kevinhwang91/nvim-ufo', requires = 'kevinhwang91/promise-async' }
  use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim' }
  use {
    'nvim-telescope/telescope-fzf-native.nvim',
    run = 'nix-shell -p cmake --command "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release"'
  }
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
  }
  use {
    'phaazon/hop.nvim',
    branch = 'v1.3',
    config = function()
      -- see :h hop-config
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
vim.opt.wildignore = { '*/tmp/*', '*.so', '*.swp', '*.zip', '*.svg', '*.png', '*.jpg', '*.gif', 'node_modules', 'dist', 'build' }

local kmapopts = { silent = true }

${if config.desktop.hallmack then ''
vim.keymap.set('n', '<leader>h', ':set hlsearch!<CR>', { noremap = true })
'' else ''
vim.keymap.set('n', '<F3>', ':set hlsearch!<CR>', { noremap = true })
''}

vim.keymap.set('n', '<leader>cd', ':cd %:h<CR>', { noremap = true })
vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true })
vim.keymap.set('n', '<leader><leader>w', ':w!<CR>', { noremap = true })

vim.keymap.set('n', '<C-w>', ':bp|bd #<CR>', kmapopts)
vim.keymap.del('n', '<C-w><C-D>')
vim.keymap.del('n', '<C-w>d')

${if config.desktop.hallmack then ''
vim.keymap.set('n', '<C-g>', ':bp<CR>', kmapopts)
vim.keymap.set('n', '<C-o>', ':bn<CR>', kmapopts)
'' else ''
vim.keymap.set('n', '<C-h>', ':bp<CR>', kmapopts)
vim.keymap.set('n', '<C-l>', ':bn<CR>', kmapopts)
''}

${if config.desktop.hallmack then ''
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

${if config.desktop.hallmack then ''
-- swap h g
vim.keymap.set({ 'n', 'x', 'o' }, 'g', 'h', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'G', 'H', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'h', 'g', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'H', 'G', kmapopts)
vim.keymap.set({ 'n', 'x', 'o' }, 'hh', 'gg', kmapopts)

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

vim.keymap.set('v', 'A', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'E', ":m '<-2<CR>gv=gv")
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('x', '<leader>p', '"_dP')

--------------------------------------------------------------------------------
-- Language Server protocol & completion
--------------------------------------------------------------------------------

local lsp_on_attach = function(client, bufnr)
  -- enable completion triggered by <C-x><C-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- see `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap = true, silent = true, buffer = bufnr }

  ${if config.desktop.hallmack then ''
  vim.keymap.set('n', '<C-a>', vim.diagnostic.goto_next,    bufopts)
  vim.keymap.set('n', '<C-e>', vim.diagnostic.goto_prev,    bufopts)
  vim.keymap.set('n', 'E',     vim.lsp.buf.hover,           bufopts)
  vim.keymap.set('n', 'hd',    vim.lsp.buf.definition,      bufopts)
  vim.keymap.set('n', 'htd',   vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', 'hi',    vim.lsp.buf.implementation,  bufopts)
  vim.keymap.set('n', 'hr',    vim.lsp.buf.references,      bufopts)
  '' else ''
  vim.keymap.set('n', '<C-j>', vim.diagnostic.goto_next,    bufopts)
  vim.keymap.set('n', '<C-k>', vim.diagnostic.goto_prev,    bufopts)
  vim.keymap.set('n', 'K',     vim.lsp.buf.hover,           bufopts)
  vim.keymap.set('n', 'gd',    vim.lsp.buf.definition,      bufopts)
  vim.keymap.set('n', 'gtd',   vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', 'gi',    vim.lsp.buf.implementation,  bufopts)
  vim.keymap.set('n', 'gr',    vim.lsp.buf.references,      bufopts)
  ''}
  vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename,          bufopts)
  vim.keymap.set('n', '<leader>a', vim.lsp.buf.code_action,     bufopts)
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float,   bufopts)
  vim.keymap.set('n', '<leader>f', vim.lsp.buf.format,      bufopts)
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

local nvim_lsp = require('lspconfig')
local lsp_servers = { 'bashls', 'eslint', 'hls', 'nil_ls', 'rust_analyzer' }
local lsp_capabilities = require'cmp_nvim_lsp'.default_capabilities()
local lsp_flags = {
  debounce_text_changes = 15
}
local lsp_handlers = {
  ['textDocument/publishDiagnostics'] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    { virtual_text = false }
  ),
}

for _, lsp in ipairs(lsp_servers) do
  nvim_lsp[lsp].setup {
    on_attach = lsp_on_attach,
    capabilities = lsp_capabilities,
    flags = lsp_flags,
    handlers = lsp_handlers,
  }
end

vim.keymap.set('n', '<leader>b', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end)

nvim_lsp.ts_ls.setup {
  on_attach = lsp_on_attach,
  capabilities = lsp_capabilities,
  flags = lsp_flags,
  handlers = lsp_handlers,
  settings = {
    typescript = {
      inlayHints = {
        -- You can set this to 'all' or 'literals' to enable more hints
        includeInlayParameterNameHints = "none", -- 'none' | 'literals' | 'all'
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = false,
        includeInlayVariableTypeHints = false,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = false,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        -- You can set this to 'all' or 'literals' to enable more hints
        includeInlayParameterNameHints = "none", -- 'none' | 'literals' | 'all'
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayVariableTypeHints = false,
        includeInlayFunctionParameterTypeHints = false,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = false,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
}

require'luasnip.loaders.from_lua'.load({ paths = '~/.config/nvim/snippets' })

--------------------------------------------------------------------------------
-- TreeSitter
--------------------------------------------------------------------------------

require'nvim-treesitter.configs'.setup {
  ensure_installed = { 'c', 'cpp', 'css', 'dockerfile', 'go', 'haskell', 'html', 'javascript', 'jsonc', 'lua', 'nix', 'rust', 'scss', 'tsx', 'typescript', 'vim', 'yaml' },
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false
  },
  indent = {
    enable = true
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<CR>',
      scope_incremental = '<CR>',
      node_incremental = '<TAB>',
      node_decremental = '<S-TAB>'
    }
  }
}

--------------------------------------------------------------------------------
-- UFO
--------------------------------------------------------------------------------

local handler = function(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = (' 󰁂 %d '):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, {chunkText, hlGroup})
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2nd argument, need padding
      if curWidth + chunkWidth < targetWidth then
          suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, {suffix, 'MoreMsg'})
  return newVirtText
end
vim.o.foldcolumn = '1' -- or '0'
vim.o.foldlevel = 99 -- configurable
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

require('ufo').setup({
  fold_virt_text_handler = handler,
  provider_selector = function(bufnr, filetype, buftype)
    return {'treesitter', 'indent'}
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

    ${if config.desktop.hallmack then ''
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
  vim.keymap.set('n', 'j', api.fs.create, opts('Create'))
  -- vim.keymap.set('n', 'bd', api.marks.bulk.delete, opts('Delete Bookmarked'))
  -- vim.keymap.set('n', 'bt', api.marks.bulk.trash, opts('Trash Bookmarked'))
  -- vim.keymap.set('n', 'bmv', api.marks.bulk.move, opts('Move Bookmarked'))
  vim.keymap.set('n', 'B', api.tree.toggle_no_buffer_filter, opts('Toggle Filter: No Buffer'))
  vim.keymap.set('n', 'c', api.fs.copy.node, opts('Copy'))
  vim.keymap.set('n', 'C', api.tree.toggle_git_clean_filter, opts('Toggle Filter: Git Clean'))
  vim.keymap.set('n', '[c', api.node.navigate.git.prev, opts('Prev Git'))
  vim.keymap.set('n', ']c', api.node.navigate.git.next, opts('Next Git'))
  vim.keymap.set('n', 'd', api.fs.remove, opts('Delete'))
  vim.keymap.set('n', 'D', api.fs.trash, opts('Trash'))
  vim.keymap.set('n', 'L', api.tree.expand_all, opts('Expand All'))
  -- vim.keymap.set('n', '<e', api.fs.rename_basename, opts('Rename: Basename'))
  -- vim.keymap.set('n', ']e', api.node.navigate.diagnostics.next, opts('Next Diagnostic'))
  -- vim.keymap.set('n', '[e', api.node.navigate.diagnostics.prev, opts('Prev Diagnostic'))
  vim.keymap.set('n', 'F', api.live_filter.clear, opts('Clean Filter'))
  vim.keymap.set('n', 'f', api.live_filter.start, opts('Filter'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('Help'))
  -- vim.keymap.set('n', 'gy', api.fs.copy.absolute_path, opts('Copy Absolute Path'))
  -- vim.keymap.set('n', 'H', api.tree.toggle_hidden_filter, opts('Toggle Filter: Dotfiles'))
  vim.keymap.set('n', 'I', api.tree.toggle_gitignore_filter, opts('Toggle Filter: Git Ignore'))
  vim.keymap.set('n', 'A', api.node.navigate.sibling.last, opts('Last Sibling'))
  vim.keymap.set('n', 'E', api.node.navigate.sibling.first, opts('First Sibling'))
  vim.keymap.set('n', 'm', api.marks.toggle, opts('Toggle Bookmark'))
  -- vim.keymap.set('n', 'o', api.node.open.edit, opts('Open'))
  -- vim.keymap.set('n', 'O', api.node.open.no_window_picker, opts('Open: No Window Picker'))
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

require'telescope'.setup {
  defaults = {
    file_ignore_patterns = { 'node_modules' },
    borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
    mappings = {
      ${if config.desktop.hallmack then ''
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
    }
  }
}

require'telescope'.load_extension'fzf'

vim.keymap.set('n', 'tf', ':Telescope find_files<cr>', kmapopts)
vim.keymap.set('n', 'tb', ':Telescope buffers<cr>', kmapopts)
vim.keymap.set('n', 'tt', ':Telescope git_files<cr>', kmapopts)
vim.keymap.set('n', 'tg', ':Telescope live_grep<cr>', kmapopts)
vim.keymap.set('n', 'ts', ':Telescope grep_string<cr>', kmapopts)

--------------------------------------------------------------------------------
-- Comment
--------------------------------------------------------------------------------

vim.keymap.del('o', 'gc')
vim.keymap.del('x', 'gc')
vim.keymap.del('x', 'gx')
vim.keymap.del('n', 'gc')
vim.keymap.del('n', 'gcc')
vim.keymap.del('n', 'gx')

${if config.desktop.hallmack then ''
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
