return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "basedpyright",
      "postgres_lsp",
      "templ",
    },
  },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
}
