-- .config/nvim/lua/plugins/treesitter.lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, _)
      vim.filetype.add({
        extension = {
          gotmpl = "gotmpl",
        },
        pattern = {
          [".*%.tpl"] = "helm",
          [".*%.ya?ml"] = "helm",
          ["helmfile.*%.ya?ml"] = "helm",
        },
      })
    end,
  },
}
