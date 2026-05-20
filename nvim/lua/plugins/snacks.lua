return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            layout = {
              layout = {
                width = 70,
              },
            },
            win = {
              list = {
                keys = {
                  ["<CR>"] = "explorer_open",
                  ["o"] = "confirm",
                  ["t"] = "tab",
                  ["C"] = "explorer_cd",
                },
              },
            },
          },
        },
      },
    },
  },
}
