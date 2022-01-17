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
      rnix-lsp
    ];

    xdg.configFile."nvim/lua/config.lua".text = ''
      require'packer'.startup(function(use)
        use 'hrsh7th/cmp-buffer'
        use 'hrsh7th/cmp-cmdline'
        use 'hrsh7th/cmp-nvim-lsp'
        use 'hrsh7th/cmp-path'
        use 'hrsh7th/cmp-vsnip'
        use 'hrsh7th/nvim-cmp'
        use 'hrsh7th/vim-vsnip'
        use 'jiangmiao/auto-pairs'
        use 'junegunn/goyo.vim'
        use 'kyazdani42/nvim-tree.lua'
        use 'neovim/nvim-lspconfig'
        use 'numToStr/Comment.nvim'
        use 'nvim-lua/plenary.nvim'
        use 'nvim-lualine/lualine.nvim'
        use 'nvim-telescope/telescope.nvim'
        use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
        use 'rmehri01/onenord.nvim'
        use 'tpope/vim-eunuch'
        use 'tpope/vim-surround'
      end)

      --------------------------------------------------------------------------------
      -- Common
      --------------------------------------------------------------------------------

      function map_(mode, shortcut, command)
        vim.api.nvim_set_keymap(mode, shortcut, command, { noremap = true, silent = true })
      end

      function map(shortcut, command)
        map_(''', shortcut, command)
      end

      function nmap(shortcut, command)
        map_('n', shortcut, command)
      end

      local HOME = os.getenv("HOME")

      vim.g.mapleader = ' '

      vim.opt.autochdir = true
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
      vim.opt.relativenumber = true
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

      nmap('<F3>', ':set hlsearch!<CR>')

      nmap('<leader>w', ':w<CR>')
      nmap('<leader><leader>w', ':w!<CR>')

      nmap('<C-w>', ':bp|bd #<CR>')
      ${if config.desktop.hallmack then ''
        nmap('<C-g>', ':bp<CR>')
        nmap('<C-o>', ':bn<CR>')
      '' else ''
        nmap('<C-h>', ':bp<CR>')
        nmap('<C-l>', ':bn<CR>')
      ''}

      ${if config.desktop.hallmack then ''
        nmap('<C-A-e>', ':wincmd k<CR>')
        nmap('<C-A-a>', ':wincmd j<CR>')
        nmap('<C-A-g>', ':wincmd h<CR>')
        nmap('<C-A-o>', ':wincmd l<CR>')
      '' else ''
        nmap('<C-A-k>', ':wincmd k<CR>')
        nmap('<C-A-j>', ':wincmd j<CR>')
        nmap('<C-A-h>', ':wincmd h<CR>')
        nmap('<C-A-l>', ':wincmd l<CR>')
      ''}

      ${if config.desktop.hallmack then ''
        -- swap h g
        map('g', 'h')
        map('G', 'H')
        map('h', 'g')
        map('H', 'G')
        map('hh', 'gg')

        -- swap j a
        map('a', 'j')
        map('A', 'J')
        map('j', 'o')
        map('J', 'O')

        -- swap k e
        map('e', 'k')
        map('E', 'K')
        map('k', 'a')
        map('K', 'A')

        -- swap l o
        map('o', 'l')
        map('O', 'L')
        map('l', 'e')
        map('L', 'E')
      '' else ""}

      --------------------------------------------------------------------------------
      -- Language Server protocol & completion
      --------------------------------------------------------------------------------

      local on_attach = function(client, bufnr)
        local function buf_set_option(name, value)
          vim.api.nvim_buf_set_option(bufnr, name, value)
        end
        local function nmapb(shortcut, command)
          vim.api.nvim_buf_set_keymap(bufnr, 'n', shortcut, command, { noremap = true, silent = true })
        end

        -- enable completion triggered by <C-x><C-o>
        buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

        -- see `:help vim.lsp.*` for documentation on any of the below functions
        ${if config.desktop.hallmack then ''
          nmapb('<C-a>',     '<cmd>lua vim.diagnostic.goto_next()<cr>')
          nmapb('<C-e>',     '<cmd>lua vim.diagnostic.goto_prev()<cr>')
          nmapb('E',         '<cmd>lua vim.lsp.buf.hover()<cr>')
          nmapb('hd',        '<cmd>lua vim.lsp.buf.definition()<cr>')
          nmapb('hi',        '<cmd>lua vim.lsp.buf.implementation()<cr>')
          nmapb('hr',        '<cmd>lua vim.lsp.buf.references()<cr>')
        '' else ''
          nmapb('<C-j>',     '<cmd>lua vim.diagnostic.goto_next()<cr>')
          nmapb('<C-k>',     '<cmd>lua vim.diagnostic.goto_prev()<cr>')
          nmapb('K',         '<cmd>lua vim.lsp.buf.hover()<cr>')
          nmapb('gd',        '<cmd>lua vim.lsp.buf.declaration()<cr>')
          nmapb('gi',        '<cmd>lua vim.lsp.buf.implementation()<cr>')
          nmapb('gr',        '<cmd>lua vim.lsp.buf.references()<cr>')
        ''}
        nmapb('<leader>d', '<cmd>lua vim.lsp.buf.type_definition()<cr>')
        nmapb('<leader>r', '<cmd>lua vim.lsp.buf.rename()<cr>')
        nmapb('<leader>a', '<cmd>lua vim.lsp.buf.code_action()<cr>')
        nmapb('<leader>e', '<cmd>lua vim.diagnostic.open_float()<cr>')
        nmapb('<leader>f', '<cmd>lua vim.lsp.buf.formatting()<cr>')
      end

      local cmp = require'cmp'

      cmp.setup {
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        mapping = {
          ['<C-space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item({ 'i', 'c' })),
          ['<S-Tab>'] = cmp.mapping(cmp.mapping.select_prev_item({ 'i', 'c' })),
          ['<C-e>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
        },
        sources = cmp.config.sources {
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
        }, {
          { name = 'buffer' },
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
      local servers = { 'tsserver', 'rnix' }
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require'cmp_nvim_lsp'.update_capabilities(capabilities)

      for _, lsp in ipairs(servers) do
        nvim_lsp[lsp].setup {
          on_attach = on_attach,
          capabilities = capabilities,
          flags = { debounce_text_changes = 150 },
          handlers = {
            ["textDocument/publishDiagnostics"] = vim.lsp.with(
              vim.lsp.diagnostic.on_publish_diagnostics,
              { virtual_text = false }
            ),
          }
        }
      end

      --------------------------------------------------------------------------------
      -- TreeSitter
      --------------------------------------------------------------------------------

      require'nvim-treesitter.configs'.setup {
        ensure_installed = { "c", "cpp", "css", "go", "haskell", "html", "javascript", "json5", "lua", "nix", "rust", "scss", "tsx", "typescript", "vim", "yaml" },
        sync_install = false,
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
      -- NvimTree
      --------------------------------------------------------------------------------

      local tree_cb = require'nvim-tree.config'.nvim_tree_callback
      require'nvim-tree'.setup {
        view = {
          mappings = {
            custom_only = true,
            list = {
              { key = "<CR>",  cb = tree_cb("edit") },
              { key = "<C-]>", cb = tree_cb("cd") },
              { key = "<C-v>", cb = tree_cb("vsplit") },
              { key = "<C-x>", cb = tree_cb("split") },
              { key = "<C-t>", cb = tree_cb("tabnew") },
              { key = "P",     cb = tree_cb("parent_node") },
              { key = "<BS>",  cb = tree_cb("close_node") },
              { key = "<Tab>", cb = tree_cb("preview") },
              ${if config.desktop.hallmack then ''
                { key = "E",     cb = tree_cb("first_sibling") },
                { key = "A",     cb = tree_cb("last_sibling") },
              '' else ''
                { key = "K",     cb = tree_cb("first_sibling") },
                { key = "J",     cb = tree_cb("last_sibling") },
              ''}
              { key = "I",     cb = tree_cb("toggle_ignored") },
              { key = "H",     cb = tree_cb("toggle_dotfiles") },
              { key = "R",     cb = tree_cb("refresh") },
              ${if config.desktop.hallmack then ''
                { key = "j",     cb = tree_cb("create") },
              '' else ''
                { key = "a",     cb = tree_cb("create") },
              ''}
              { key = "d",     cb = tree_cb("remove") },
              { key = "D",     cb = tree_cb("trash") },
              { key = "r",     cb = tree_cb("rename") },
              { key = "<C-r>", cb = tree_cb("full_rename") },
              { key = "x",     cb = tree_cb("cut") },
              { key = "c",     cb = tree_cb("copy") },
              { key = "p",     cb = tree_cb("paste") },
              { key = "y",     cb = tree_cb("copy_name") },
              { key = "Y",     cb = tree_cb("copy_path") },
              ${if config.desktop.hallmack then ''
                { key = "hy",    cb = tree_cb("copy_absolute_path") },
              '' else ''
                { key = "gy",    cb = tree_cb("copy_absolute_path") },
              ''}
              { key = "-",     cb = tree_cb("dir_up") },
              { key = "s",     cb = tree_cb("system_open") },
              { key = "q",     cb = tree_cb("close") },
              { key = "?",     cb = tree_cb("toggle_help") }
            }
          }
        }
      }

      nmap('<C-n>', ':NvimTreeToggle<CR>')
      nmap('<leader>j', ':NvimTreeFindFile<CR>')

      --------------------------------------------------------------------------------
      -- Telescope
      --------------------------------------------------------------------------------

      require'telescope'.setup {
        defaults = {
          file_ignore_patterns = { "node_modules" },
          borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
        }
      }

      nmap('<leader>t', ':Telescope find_files<cr>')

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

      nmap('cs', '<Plug>Csurround')

      --------------------------------------------------------------------------------
      -- VimEunuch
      --------------------------------------------------------------------------------

      nmap('<leader>z', ':SudoEdit<CR>')

      --------------------------------------------------------------------------------
      -- Matchit.vim
      --------------------------------------------------------------------------------

      vim.api.nvim_set_var('loaded_matchit', true)
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
          lua require('config')
        '';
      }];
    };
  };
}
