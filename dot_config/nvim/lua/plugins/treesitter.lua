-- .config/nvim/lua/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    opts.ensure_installed = {
      "bash",
      "css",
      "elixir",
      "go",
      "gotmpl",
      "hyprlang",
      "ruby",
      "terraform",
    }

    vim.filetype.add({
      extension = {
        gotmpl = "gotmpl",
      },
      pattern = {
        [".*%.tpl"] = "helm",
        ["helmfile.*%.ya?ml"] = "helm",
      },
    })
    vim.filetype.add({
      pattern = {
        [".*%.sh.tmpl"] = "bash",
      },
    })
    vim.filetype.add({
      pattern = {
        [".*/hypr/.*%.conf.tmpl"] = "hyprlang",
      },
    })
  end,
}
