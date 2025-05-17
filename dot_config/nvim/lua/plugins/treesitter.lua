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
      vim.filetype.add({
        extension = {
          bash = "bash",
        },
        pattern = {
          [".*%.sh.tmpl"] = "bash",
        },
      })
    end,
  },
}
