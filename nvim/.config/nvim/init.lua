-- ~/.config/nvim/init.lua — minimal IDE config matching blog Part 1.
-- lazy.nvim bootstrap, LSP via Mason, Telescope, gitsigns, nvim-cmp.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ---------- Options ----------
local o = vim.opt
o.number         = true
o.relativenumber = true
o.expandtab      = true
o.shiftwidth     = 2
o.tabstop        = 2
o.smartindent    = true
o.clipboard      = "unnamedplus"
o.termguicolors  = true
o.signcolumn     = "yes"
o.updatetime     = 250
o.ignorecase     = true
o.smartcase      = true
o.scrolloff      = 8

-- ---------- Bootstrap lazy.nvim ----------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ---------- Plugins ----------
require("lazy").setup({

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "ts_ls", "rust_analyzer", "lua_ls" },
        automatic_installation = true,
      })
      local lsp = require("lspconfig")
      lsp.pyright.setup({})
      lsp.ts_ls.setup({})
      lsp.rust_analyzer.setup({})
      lsp.lua_ls.setup({
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })

      vim.keymap.set("n", "gd", vim.lsp.buf.definition,    { desc = "Go to definition" })
      vim.keymap.set("n", "K",  vim.lsp.buf.hover,         { desc = "Hover" })
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation,{ desc = "Go to implementation" })
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,{ desc = "Rename symbol" })
    end,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    event = "VimEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local t = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", t.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", t.live_grep,  { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", t.buffers,    { desc = "Switch buffers" })
      vim.keymap.set("n", "<leader>fh", t.help_tags,  { desc = "Help tags" })
    end,
  },

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args) require("luasnip").lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping.select_next_item(),
          ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip"  },
        }, {
          { name = "buffer"   },
        }),
      })
    end,
  },
})
