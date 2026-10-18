-- Minimal Neovim config
vim.g.mapleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"

vim.pack.add({ "https://github.com/tjdevries/colorbuddy.nvim" })
vim.cmd.colorscheme("zedokai_darker_black")
