-- Seamless window/pane navigation across nvim splits and tmux panes.
--
-- Without this plugin, pressing <C-h> at nvim's leftmost split is a no-op:
-- tmux has already forwarded the key to nvim (see the `bind -n C-h ...` lines
-- in ~/.tmux.conf), so tmux never gets to switch panes. smart-splits closes
-- the loop — after attempting a split move, if the cursor didn't actually
-- change windows, it shells out to `tmux select-pane -L/-D/-U/-R`.
--
-- These keymaps override LazyVim's default <C-h/j/k/l> = <C-w>h/j/k/l
-- because lazy.nvim applies plugin keys after the LazyVim core keymaps.
--
-- Prerequisites already in place:
--   - tmux smart-pane-switching forwards C-h/j/k/l to vim/nvim/vimdiff/nvimdiff
--     (the (^|\\/)n?vim(diff)?$ regex in ~/.tmux.conf)

return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  keys = {
    { "<C-h>", function() require("smart-splits").move_cursor_left() end,  desc = "Move to left split / tmux pane" },
    { "<C-j>", function() require("smart-splits").move_cursor_down() end,  desc = "Move to lower split / tmux pane" },
    { "<C-k>", function() require("smart-splits").move_cursor_up() end,    desc = "Move to upper split / tmux pane" },
    { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split / tmux pane" },
  },
  opts = {
    -- The plugin auto-detects tmux via $TMUX; no extra config needed.
    -- It uses `tmux select-pane -L/-D/-U/-R` under the hood.
  },
}
