
# Basic Factor LSP

This is an LSP for the factor programming language. It probably has a decent number of bugs. If you are using this, be prepared to debug issues with bad error messages. 
When reporting or debugging crashes, always make sure to look in the log file. Logging is disabled by default, but you can enable it by adding the name of the file as an input to the language server launch command

## Installation

Installing this LSP requires the [factor programming language](https://factorcode.org), but considering that you're using an LSP for it, you likely already have this installed. The easiest way to install the LSP (at the moment) is to clone this repo into the work directory inside of the root factor directory, and then to go follow the editor-specific instructions below.

## Features

- Code completion: shows the vocabulary and name of words, and automatically adds imports when they are missing (but rarely and inconsistantly that just doesn't work for some reason)
- Signature help: shows the stack effects and vocabularies of all words with a name
- Hover: displays the documentation of words as markdown
- Go-to-implementation: goes to the file and location that a word is defined in. Does not work if that file has unsaved changes, mearly taking you to the location of the old definition 
- References: works, with the same caveats as go-to-implementation. It may miss out on certain references due to limitations with factor's `usage` word

## Problems
When you open a file, it takes several seconds for the LSP to load. Also, there are probably at least a couple major bugs lingering around (though I use it myself and rarely encounter them)
  
## Editor Support

### Nvim

Apperently I need to have 100 stars (according to their [CONTRIBUTING.md](https://github.com/neovim/nvim-lspconfig/blob/master/CONTRIBUTING.md)) on github to even contribute this LSP config to nvim-lspconfig. This means you have to configure this the hard way

I'm gonna assume you have an LSP setup that provides stuff like keybindings. I'm not going to explain how to set this up here, but if you've already used neovim language servers before, you already probably have these set up 

The minimum possible additions to init.lua that I'm confident will provide some functionality are as follows:
```lua
-- this is needed in order to find the root of your factor directory.
-- you can theoretically exclude this if you're OK with the LSP having to go through the long setup process after you open any factor file, even if it's in the same project
-- it also might not work on windows
function find_factor_folder(path)
	path = vim.fs.normalize(path)
	local factorroots = os.getenv("FACTOR_ROOTS") or ''
	local seperator = ':'
	if vim.fn['has']("win32") then
		seperator = ';'
	end
	local default_factor_root = vim.fs.root(path, 'factor.image')
	if default_factor_root then
		if factorroots then factorroots = factorroots .. seperator end
		factorroots = 
			factorroots
			.. default_factor_root .. '/work' .. seperator 
			.. default_factor_root .. '/core' .. seperator 
			.. default_factor_root .. '/basis' .. seperator
			.. default_factor_root .. '/extra' .. seperator
	end
	local roots = mysplit(factorroots, seperator)
	local i = 1
	local path_to_check = path
	local last_folder_name = ""
	while true do
		if (path_to_check == "/") or (path_to_check == 'C:/') then
			path_to_check = path
			last_folder_name = ""
			i = i + 1
		elseif i > #roots then
			return nil
		elseif path_to_check == roots[i] then
			return path_to_check .. '/' .. last_folder_name
		else
			last_folder_name = vim.fs.basename(path_to_check)
			path_to_check = vim.fs.dirname(path_to_check)
		end
	end
end

-- from https://stackoverflow.com/questions/1426954/split-string-in-lua
function mysplit(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

vim.api.nvim_create_autocmd('FileType', {
      		pattern = 'factor',
      		callback = function(ev)
                local client = vim.lsp.start { 
			    	cmd = {'path/to/factor', '-run=factor-lsp', '~/lsp.log'}, -- delete the last arg to disable logging. you should probably do this
                    root_dir = find_factor_folder(vim.api.nvim_buf_get_name(ev.buf)), -- if you exclude find_factor_path, just delete this line as well			    
                    name = 'factor-lsp',
				    offset_encoding = 'utf-8',
			    }
			    if client then
				    vim.lsp.buf_attach_client(ev.buf, client)
			    end
            end,
})
```
### Sublime Text
Sublime Text has been confirmed to work out of the box

### Others

I suggest you look at your editor's lsp support to figure out how to deal with this yourself. It's possible that your editor's defaults will leave things to be desired, so you might have to do as much or more configuration than I had to do for nvim. You'll probably want to have some knowledge of whatever scripting language your editor uses for configuration

I do have some specific comments about some editors below:

- Writing vscode extensions makes me want to die, so support for it is not planned.
- Support for Emacs is planned, I just haven't gotten around to it yet. Let's hope it's not that difficult. You could also use [FUEL](https://github.com/mcandre/fuel)
- Same with regular vim (but you can't use FUEL of course)

An editor not being on this list does not mean that it is entirely unsupported. the language server protocol was designed to be cross-editor, after all
