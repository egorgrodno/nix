{ pkgs, config, username, ... }:

{
  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted
      rnix-lsp
      rust-analyzer
      cargo
      rustc
    ];

    xdg.configFile."nvim/snippets/all.lua".source = ./snippets.lua;

    xdg.configFile."nvim/lua/config.lua".text = ''
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
      vim.opt.shiftwidth = 2
      vim.opt.showcmd = true
      vim.opt.showmode = false
      vim.opt.showtabline = 2
      vim.opt.signcolumn = 'yes'
      vim.opt.smartcase = true
      vim.opt.swapfile = true
      vim.opt.tabstop = 2
      vim.opt.ttimeoutlen = 0
      vim.opt.wildignore = { '*/tmp/*', '*.so', '*.swp', '*.zip', '*.svg', '*.png', '*.jpg', '*.gif', 'node_modules', 'dist', 'build' }

      local kmapopts = { noremap = true, silent = true }

      ${if config.desktop.hallmack then ''
        vim.keymap.set('n', '<leader>sh', ':set hlsearch!<CR>', { noremap = true })
      '' else ''
        vim.keymap.set('n', '<F3>', ':set hlsearch!<CR>', { noremap = true })
      ''}

      vim.keymap.set('n', '<leader>cd', ':cd %:h<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true })
      vim.keymap.set('n', '<leader><leader>w', ':w!<CR>', { noremap = true })

      vim.keymap.set('n', '<C-w>', ':bp|bd #<CR>', kmapopts)
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
        vim.keymap.set({ 'n', 'x', 'o' }, 'A', 'J', kmapopts)
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
      '' else ""}

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
        vim.keymap.set('n', '<leader>f', vim.lsp.buf.formatting,      bufopts)
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

      local nvim_lsp = require'lspconfig'
      local servers = { 'tsserver', 'eslint', 'rnix', 'rust_analyzer' }
      local capabilities = require'cmp_nvim_lsp'.default_capabilities()

      for _, lsp in ipairs(servers) do
        nvim_lsp[lsp].setup {
          on_attach = lsp_on_attach,
          capabilities = capabilities,
          flags = { debounce_text_changes = 150 },
          handlers = {
            ['textDocument/publishDiagnostics'] = vim.lsp.with(
              vim.lsp.diagnostic.on_publish_diagnostics,
              { virtual_text = false }
            ),
          }
        }
      end

      require'luasnip.loaders.from_lua'.load({ paths = '~/.config/nvim/snippets' })

      --------------------------------------------------------------------------------
      -- TreeSitter
      --------------------------------------------------------------------------------

      require'nvim-treesitter.configs'.setup {
        ensure_installed = { 'c', 'cpp', 'css', 'go', 'haskell', 'html', 'javascript', 'jsonc', 'lua', 'nix', 'rust', 'scss', 'tsx', 'typescript', 'vim', 'yaml' },
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
      -- Neogit
      --------------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>g', ':Neogit<CR>', { noremap = true })

      --------------------------------------------------------------------------------
      -- GitSigns
      --------------------------------------------------------------------------------

      require('gitsigns').setup {
        signs = {
          add          = { hl = 'GitSignsAdd'   , text = '│', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn' },
          change       = { hl = 'GitSignsChange', text = '│', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn' },
          delete       = { hl = 'GitSignsDelete', text = '_', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn' },
          topdelete    = { hl = 'GitSignsDelete', text = '‾', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn' },
          changedelete = { hl = 'GitSignsChange', text = '~', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn' }
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

      --------------------------------------------------------------------------------
      -- Indent Blankline
      --------------------------------------------------------------------------------

      vim.opt.termguicolors = true
      vim.opt.list = true

      require'indent_blankline'.setup {
        char = '¦';
        show_end_of_line = true,
        show_trailing_blankline_indent = false,
        space_char_blankline = ' ',
        show_current_context = true,
        show_current_context_start = true
      }

      --------------------------------------------------------------------------------
      -- NvimTree
      --------------------------------------------------------------------------------

      local tree_cb = require'nvim-tree.config'.nvim_tree_callback
      require'nvim-tree'.setup {
        view = {
          adaptive_size = true,
          mappings = {
            custom_only = true,
            list = {
              { key = '<CR>',  cb = tree_cb('edit') },
              { key = '<C-]>', cb = tree_cb('cd') },
              { key = '<C-v>', cb = tree_cb('vsplit') },
              { key = '<C-x>', cb = tree_cb('split') },
              { key = '<C-t>', cb = tree_cb('tabnew') },
              { key = 'P',     cb = tree_cb('parent_node') },
              { key = '<BS>',  cb = tree_cb('close_node') },
              { key = '<Tab>', cb = tree_cb('preview') },
              ${if config.desktop.hallmack then ''
                { key = 'E',     cb = tree_cb('first_sibling') },
                { key = 'A',     cb = tree_cb('last_sibling') },
              '' else ''
                { key = 'K',     cb = tree_cb('first_sibling') },
                { key = 'J',     cb = tree_cb('last_sibling') },
              ''}
              { key = 'h',     cb = tree_cb('toggle_ignored') },
              { key = 'H',     cb = tree_cb('toggle_dotfiles') },
              { key = 'R',     cb = tree_cb('refresh') },
              ${if config.desktop.hallmack then ''
                { key = 'j',     cb = tree_cb('create') },
              '' else ''
                { key = 'a',     cb = tree_cb('create') },
              ''}
              { key = 'd',     cb = tree_cb('remove') },
              { key = 'D',     cb = tree_cb('trash') },
              { key = 'r',     cb = tree_cb('rename') },
              { key = '<C-r>', cb = tree_cb('full_rename') },
              { key = 'x',     cb = tree_cb('cut') },
              { key = 'c',     cb = tree_cb('copy') },
              { key = 'p',     cb = tree_cb('paste') },
              { key = 'y',     cb = tree_cb('copy_name') },
              { key = 'Y',     cb = tree_cb('copy_path') },
              ${if config.desktop.hallmack then ''
                { key = 'hy',    cb = tree_cb('copy_absolute_path') },
              '' else ''
                { key = 'gy',    cb = tree_cb('copy_absolute_path') },
              ''}
              { key = '-',     cb = tree_cb('dir_up') },
              { key = 's',     cb = tree_cb('system_open') },
              { key = 'q',     cb = tree_cb('close') },
              { key = '?',     cb = tree_cb('toggle_help') }
            }
          }
        },
        filters = { dotfiles = false },
        git = { ignore = false }
      }

      vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', kmapopts)
      vim.keymap.set('n', '<leader>j', ':NvimTreeFindFile<CR>', kmapopts)

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
            above = 'hcJ',
            below = 'hcj',
            eol = 'hcK'
          }
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
    '';

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = [{
        plugin = pkgs.vimPlugins.packer-nvim;
        config = ''
          packadd! packer.nvim
          lua require'config'
        '';
      }];
    };
  };
}
