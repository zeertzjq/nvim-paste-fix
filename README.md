# nvim-paste-fix

Fix Nvim's streamed pasting. Supports Normal, Visual, Select, Insert, Terminal, and Cmdline modes. Compatible with Nvim v0.4.0 and above.

This is mostly the same function as vim.paste() in <https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_editor.lua>, with some extra code for Nvim v0.4.0 compatibility, so you do not need this if you are using Nvim v0.8.0-dev or above.

## Usage

Install using a package manager, or by cloning this repository and adding the cloned directory into `'runtimepath'` from `init.vim` or `init.lua`. No extra steps are needed.
