return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    -- Commented until mason-lspconfig is pinned in LazyVim to v2 which will
    -- make it possible to install postgres_lsp

    -- ensure_installed = { "postgres_lsp" },
  },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
}
