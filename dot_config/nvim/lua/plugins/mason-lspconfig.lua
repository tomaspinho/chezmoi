return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "postgres_lsp",
      "basedpyright",
    },
  },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
}
