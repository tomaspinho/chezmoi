-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

map("n", "<leader>ps", "<cmd>execute '!openscad '.expand('%:p').'&'<cr>", { desc = "Preview with OpenSCAD" })

map("t", "<leader><Esc>", "<C-\\><C-n>", { silent = true })
