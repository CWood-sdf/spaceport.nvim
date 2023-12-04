# spaceport.nvim

The launchpad for neovim.

## Why?

I got really bored with the pattern of cd'ing to a project folder then doing `nvim .` then starting to program. I wanted to just type `nvim` and then a few keystrokes later, be in a project.

## How?

Spaceport automatically keeps track of every file and directory you open neovim to. It then uses this information to provide a list of the most recently used projects. On top of that, some projects can be tagged so that they always appear as the first project on a list. For example, I have my neovim dotfiles as tag 1, so in a new terminal window, I can type `nvim` and then `1p` and instantly be at my dotfiles, rather than having to type `cd ~/.config/nvim<CR>nvim .`.

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
  'CWood-sdf/spaceport.nvim',
  opts = {
      replaceDirs = { {"~/projects", "_" } }, -- replace ~/projects with _
      replaceHome = true, -- replace /home/user with ~ (also works on windows)
      projectEntry = "Oil .", -- The cmd to run when opening a project
  },
  lazy = false, -- load spaceport immediately
}
```

</details>

## Usage

Spaceport automatically loads after neovim has started.
