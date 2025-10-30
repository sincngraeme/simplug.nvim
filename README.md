# Simplug

Simplug is a "plugin manager" for Neovim designed with simplicity in mind.

I say plugin manager in quotes because it is *simply* a wrapper for the builtin plugin manager.

```lua
vim.pack.add("someplugin") -- This one
```

## Dependencies

Since this is a wrapper for the builtin package manager, you must have a Neovim version that includes this feature.
Please ensure you are using the most recent release.

## Pros/Cons

| Pros                                    | Cons                                                      |
| --------------------------------------- | --------------------------------------------------------- |
| - Simple and lightweight                | - No Lazy loading (limitation in builtin package manager) |
| - Easy plugin depency management        | - (Relatively) Untested                                   |
| - Quickly unload plugins at will        | - No fancy menus                                          |
| - Control over your directory structure | - I am a student with minimal time to maintain this repo  |

>[!note]
>I do not recommend this plugin for beginners as it is brand new and it is not unlikely you will run into issues. It is also intended to give more control than alternative package managers. If you are new to neovim/lua I recommend [lazy](https://lazy.folke.io/). It is very well documented and easy to setup.

## Installation

There are a few ways to install this plugin. 

**Option 1**

You can use the builtin package manager to install it early in your
configuration:

```lua
vim.pack.add({"https://github.com/sincngraeme/simplug.nvim"})
```

This is the way I recommend because it will update Simplug whenever there are changes.

**Option 2**

Install with git or download manually (this will not respond to updates so I don't recommend this). 

```git
git clone "https://github.com/sincngraeme/simplug.nvim"
```

If you choose this method, just copy the `simplug.lua` file into your config somewhere and require just that
file.

```lua
require("simplug").setup()
```

>[!note]
>The path will depend on where you put the module and where you require it from

If you want an example of how this works, see my Neovim config. I require the module directly rather than
installing with the package manager (because I wrote it). My `init.lua` file also gives a good example usage of
the plugin.

## Configuration

Configuration is simple. Calling `.setup()` is not even required if you are fine with the defaults.

```lua
require("simplug").setup({
    plugin_dir = "plugins"      -- location to load plugin configs from (can also be passed to the load function)
    always_update = false       -- whether or not to always run pack.update with load
    pack_lockfile = "nvim-pack-lock.json"   -- location of the lockfile if not in the default location
    confirm_update  = false     -- whether or not to ask the user for confirmation when updating plugins
})
```

>[!Note]
>The plugin assumes you have a similar directory structure to:
>
>nvim
>├── lua
>│   └── plugins
>│       ├── plugin1
>│       └── plugin2
>├── init.lua
>└── nvim-pack-lock.json
>
>If you have a flat structure (no lua folder) or a monolithic config file, you are best served with the default
>package manager. Simplug is intended for a "file per plugin" setup.

## Usage

Once installed and configured to your liking, you can run the install/config command (`.load()`) to install and
configure individual plugins.

```lua
require("simplug").load({
    "plugin1",
    "plugin2",
})
```

>[!Important]
>The name specified in `.load()` tables *must* be the same as the name of the config file for that plugin
>(without .lua). It does not need to be the same as the name of the plugin repo, or whatever name that plugin
>module uses (some of them are not consistent).

`.load()` will `require()` each plugin config *in this order*. This means that if you have a plugin with a
dependency, you can manage this simply by calling the dependency first.

`.load()` can be called anywhere in your config. I like to put my load tables in my `init.lua` because it organizes
the most relevant information at the highest level.

Multiple calls to `.load()` is allowed, though it should be noted that `.load()` will use a different directory
if passed with the optional parameter: `plugin_dir`. If this option is not used, `.load()` will use the default
directory, be it the true default ("plugins"), or the user configured default which can be set when calling
`.setup()`. This means that you can organize your plugins based on their purpose and use separate load tables.

For example separate colorscheme and plugin directories:

```lua
-- Load the colorschemes 
simplug.load({
    "kanagawa",
    "tokyonight",
}, "colorschemes")

-- Now we know which colorscheme to load
vim.cmd.colorscheme("kanagawa")

-- Load the plugins 
simplug.load({
    "nvim-notify",
    "treesitter",
--  ...
})
```

You may also separate your plugin load tables even if they are in the same directory, though this is likely 
noticeably slower than loading them all in one.

Once all plugins have been loaded, it is recommended to call `.clean()`. This function will check your
`nvim-pack-lock.json` file for plugins that you have not loaded but are still installed, and uninstall them. If
you have set `confirm_clean = true` then it waits for confirmation, but by default it does not.

If you wish to disable a plugin by removing it from the load list without uninstalling, `.clean()` takes an optional argument, `ignore_list`, a table of plugins to ignore when cleaning. 

>[!important]
>`ignore_list` entries must refer to the name of the plugin, not the name of the config file as with `.load()` since it will not be loaded

## Commands

Simplug only exposes one command: `SimplugUpdate`. This is used to manually run the update process. It accepts
the following arguments:

- `'all'`: Updates all plugins
- `plugin_name`: The name of an individual plugin to update

>[!note]
>Simplug does not allow for manual installation of plugins by default as it is intended to be run automatically.
