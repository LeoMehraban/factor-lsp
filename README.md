
# Basic Factor LSP

This is a very buggy LSP for the factor programming language, in its very early stages (or maybe very late stages, if I end up abandoning this project)
If you are using this, be prepared to debug issues with bad error messages (or sometimes none at all). 
When reporting or debugging crashes, always make sure to look in the log file. Logging is disabled by default, but you can enable it by adding the name of the file as an input to the language server launch command

## Installation

Installing this LSP requires the [factor programming language](https://factorcode.org), but considering that you're using an LSP for it, you likely already have this installed. The easiest way to install the LSP (at the moment) is to clone this repo into the work directory inside of the root factor directory, and then to go follow the editor-specific instructions below.

## Features

- Code completion: shows the vocabulary and name of words, and automatically adds imports when they are missing
- Signature help: shows the stack effects and vocabularies of all words with a name
- Diagnostics: when working as intended, shows compiler errors (not lexer or parser errors, because Factor throws them when reading a file, instead of saving them to be read later on)
- Hover: displays the documentation of words as markdown
- Go-to-definition: goes to the file and location that a word is defined in. Does not work if that file has unsaved changes, mearly taking you to the location of the old definition 

## Problems

Oh god, where do I even start?
- First of all, when you open a file, it takes several seconds for the LSP to load.
- Diagnostics appear sometimes, but it's so unreliable that it's just annoying when it happens.
- Editor support is hard to configure, and your editor's defaults probably won't work or won't work well.
- There are other problems, but since they are likely nvim-specific, I'll save those for the editor support section.

## Editor Support

### Nvim

Apperently I need to have 100 stars (according to their [CONTRIBUTING.md](https://github.com/neovim/nvim-lspconfig/blob/master/CONTRIBUTING.md)) on github to even contribute this LSP config to nvim-lspconfig. This means you have to configure this the hard way

I'm gonna assume you have an LSP setup that provides stuff like keybindings. I'm not going to explain how to set this up here, but if you've already used neovim language servers before, you already probably have these set up 

The minimum possible additions to init.lua that I'm confident will provide some functionality are as follows:
```lua
-- this is needed in order to find the root of your factor directory. you can theoretically exclude this if you're OK with the LSP having to go through a long setup process after you open any factor file
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
	local path_to_test = path
	local last_folder_name = ""
	while true do
		if (path_to_test == "/") or (path_to_test == 'C:/') then
			path_to_test = path
			last_folder_name = ""
			i = i + 1
		elseif i > #roots then
			return nil
		elseif path_to_test == roots[i] then
			return path_to_test .. '/' .. last_folder_name
		else
			last_folder_name = vim.fs.basename(path_to_test)
			path_to_test = vim.fs.dirname(path_to_test)
		end
	end
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

There is a minor problems with just having this: code blocks in markdown that have been sent over by the LSP will not display with factor syntax highlighting, which is annoying for both hovering and signature help

the solution to this requires extensive configuration

#### The solution to that

To some extent, this problem can be solved with a simple revision to the call to vim.lsp.start:
```lua
local client = vim.lsp.start { 
	cmd = {'path/to/factor', '-run=factor-lsp', '~/lsp.log'}, -- delete the last arg to disable logging. you should probably do this
	root_dir = find_factor_folder(vim.api.nvim_buf_get_name(ev.buf)), -- if you exclude find_factor_path, just delete this line as well	
	name = 'factor-lsp',
	offset_encoding = 'utf-8',
	handlers = {
		["textDocument/hover"] = function(err, result, ctx, config)
			if result then
				local content = result.contents.value
				if content then
					local bufnr, winnr = vim.lsp.util.open_floating_preview({content}, "markdown")
					vim.api.nvim_set_option_value("modifiable", true, {buf=bufnr})
					vim.api.nvim_win_call(winnr, function() vim.treesitter.stop(bufnr) end)
					vim.lsp.util.stylize_markdown(bufnr, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), {})
					vim.api.nvim_set_option_value("modifiable", false, {buf=bufnr})
				end
			end
		end,
		["textDocument/signatureHelp"] = function(err, result, ctx, config)
			if result then
				local i = 1
				local lines = 0
				local content = ''
				local content_language = ''
				local greatest_valuelen = 0
			    while i <= #result.signatures do
					local sig = result.signatures[i].documentation
					content_language = sig.language
					local valuelen = string.len(sig.value or '')							   	 
					if valuelen > 0 then
						local option_string = " ! option " .. i .. '\n'
						if #result.signatures == 1 then option_string = '\n' end 
						content = content .. sig.value .. option_string
						lines = lines + 1
					    if #content > greatest_valuelen then greatest_valuelen = #content end
					end
					i = i + 1
				end
				if #content > 0 then
					vim.lsp.util.open_floating_preview(
						split_by_lines(content), 
						content_language, 
						vim.lsp.util.make_floating_popup_options(greatest_valuelen, lines, {})
					)
				end
			end
		end				
    }
}
```

this essentially overwrites the handling of some messages sent by factor-lsp. 
the first handler gets the response to the message sent by the server, then opens a floating window with markdown highlighting. 
`open_floating_preview` uses treesitter to parse the markdown, which is one of the things causing problem two in the first place, so you need to turn it off as a next step. 
Lastly, you need to call `stylize_markdown`, which sets lines in code blocks to use the correct syntax highlighting.

Unfortunatly, this solution has one major flaw: it makes links really long. For some reason, while the creator of the markdown syntax file created a setting to conceal most markdown formatting when you aren't on the particular line with that formatting, they didn't make this apply to links. The reason why this is a flaw with this method, and not just with vim markdown support in general, is because the treesitter syntax file, which had to be disabled, includes this feature. 
I have submitted a pull request to the vim-markdown github repo where the syntax file is stored to attempt to resolve this, but even if it is accepted there, it still has to make its way into vim, then nvim, then finally nvim stable. Until that happens (if it even does), you can manually solve this problem. 
First, go into your nvim runtime file folder. mine is at /opt/homebrew/Cellar/neovim/0.10.4/share/nvim/runtime, but this will vary quite a bit based on how you installed neovim in the first place.
Then, open runtime/syntax/markdown.vim and delete lines 103-104. After that, delete lines starting from 107, and going down to the line that says `exe 'syn region markdownItalic...`.
Then, copy and paste this in its place:

```vimscript
let s:concealends = ''
let s:conceal = ''
if has('conceal') && get(g:, 'markdown_syntax_conceal', 1) == 1
  let s:concealends = ' concealends'
  let s:conceal = ' conceal'
endif
exe 'syn region markdownLinkText matchgroup=markdownLinkTextDelimiter start="!\=\[\%(\_[^][]*\%(\[\_[^][]*\]\_[^][]*\)*]\%( \=[[(]\)\)\@=" end="\]\%( \=[[(]\)\@=" nextgroup=markdownLink,markdownId skipwhite contains=@markdownInline,markdownLineStart' . s:concealends
" the destination of a link should be fully concealed
exe 'syn region markdownLink matchgroup=markdownLinkDelimiter start="(" end=")" contains=markdownUrl keepend contained' . s:conceal
```
essentially, this just adds `conceal` and `concealends` to particular parts of a link when the `markdown_syntax_conceal` option is set to 1

the second handler is more complex because it needs to handle multiple different signatures that the server sends, but in terms of actual displaying, it's much simpler, just creating a window with the correct highlighing

### Others

I suggest you look at your editor's lsp support to figure out how to deal with this yourself. There's a high chance that your editor's defaults will leave things to be desired, so you might have to do as much or more configuration than I had to do for nvim. You'll probably want to have some knowlage of whatever scripting language your editor uses for configuration

I do have some specific comments about some editors below:

- Writing vscode extensions makes me want to die, so support for it is not planned.
- Support for Emacs is planned, I just haven't gotten around to it yet. Let's hope it's not that difficult. You could also just use the more feature-filled [FUEL](https://github.com/mcandre/fuel)
- Same with regular vim (but you can't use FUEL of course)

An editor not being on this list does not mean that it is entirely unsupported. the language server protocol was designed to be cross-editor, after all
