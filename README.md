
# Basic Factor LSP

This is a very buggy LSP for the factor programming language, in its very early stages (or maybe very late stages, if I end up abandoning this project)

## Installation

Installing this LSP requires the [factor programming language](https://factorcode.org), but considering that you're using an LSP for it, you likely already have this installed. The easiest way to install the LSP (at the moment) is to clone this repo into the work directory inside of the root factor directory, and then to go follow the editor-specific instructions below.

## Features

- At the moment, code completion is supported 
- In addition, there is hover support, which allows for quick and easy viewing of the stack effects of words.
- The buggiest feature at the moment is diagnostics, which is practically unusable and very unreliable. When it works, it's nice at least
- Perhaps the most useful feature is signature help, which is hooked up to the the factor help system, and thus allows you to get on-demand documentation for words in markdown format.
- There is some basic go-to-definition support. factor makes this easy by storing where every word is defined, but there probably are still problems with this

## Problems

Oh god, where do I even start?
- First of all, when you open a file, it takes several seconds for the LSP to load.
- Diagnostics appear sometimes, but it's so unreliable that it's just annoying when it happens.
- Editor support is hard to configure, and your editor's defaults probably won't work or won't work well.
- There are other problems, but since they are likely nvim-specific, I'll save those for the editor support section.

## Editor Support

### Nvim

The minimum possible additions to init.lua that I'm confident will provide some functionality are as follows:
```lua
vim.api.nvim_create_autocmd('FileType', {
      		pattern = 'factor',
      		callback = function(ev)
                local client = vim.lsp.start { 
			    	cmd = {'path/to/factor', '-run=factor-lsp'},
                    root_dir = '/', -- just always re-use client. there's no workspace support yet anyway, so seperate processes are never needed
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
vim.api.nvim_create_autocmd('FileType', {
      		pattern = 'factor',
      		callback = function(ev)
                local client = vim.lsp.start { 
				    cmd = {vim.fs.dirname(vim.fs.dirname(find_factor_folder(vim.api.nvim_buf_get_name(ev.buf)))) .. "/factor", '-run=factor-lsp'},
				    root_dir = find_factor_folder(vim.api.nvim_buf_get_name(ev.buf)),
				    name = 'factor-lsp',
				    offset_encoding = 'utf-8',
				    handlers = {
					    ["textDocument/hover"] = function(err, result, ctx, config)
						    if result then
							    local valuelen = string.len(result.contents.value or '')
							    if valuelen > 0 then
							    	vim.lsp.util.open_floating_preview({result.contents.value}, result.contents.language, vim.lsp.util.make_floating_popup_options(valuelen, 1, {}))
							    end
						    end
					    end,
					    ["textDocument/signatureHelp"] = function(err, result, ctx, config)
						    if result then
							    local signature = result.signatures[1].documentation.value
                                if signature then
							        local bufnr, winnr = vim.lsp.util.open_floating_preview({signature}, "markdown")
							        vim.api.nvim_set_option_value("modifiable", true, {buf=bufnr})
							        vim.api.nvim_win_call(winnr, function() vim.treesitter.stop(bufnr) end)
							        vim.lsp.util.stylize_markdown(bufnr, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), {})
							        vim.api.nvim_set_option_value("modifiable", false, {buf=bufnr})
                                end
						    end
					    end
				    }
			    }
			    if client then
				    vim.lsp.buf_attach_client(ev.buf, client)
		    	end
        end,
})

```

this essentially overwrites the handling of some messages sent by factor-lsp. 
the first handler creates a window that specifically uses factor as the language to highlight the text with, but the second handler has to be more complex because it has to handle markdown text mixed with factor text
it first gets the response to the message sent by the server, then opens a floating window with markdown highlighting. 
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

### Others

I suggest you look at your editor's lsp support to figure out how to deal with this yourself. There's a high chance that your editor's defaults will leave things to be desired, so you might have to do as much or more configuration than I had to do for nvim. You'll probably want to have some knowlage of whatever scripting language your editor uses for configuration

I do have some specific comments about some editors below:

- Writing vscode extensions makes me want to die, so support for it is not planned.
- Support for Emacs is planned, I just haven't gotten around to it yet. Let's hope it's not that difficult
- Same with regular vim
