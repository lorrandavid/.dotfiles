return {
  {
    "tjdevries/colorbuddy.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    priority = 999,
    config = function()
      vim.cmd("colorscheme subliminal_next")
    end,
  },
}
