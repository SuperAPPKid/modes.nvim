local utils = require('modes.utils')

local M = {}
local config = {}
local default_config = {
	colors = {},
	line_opacity = {
		copy = 0.15,
		delete = 0.15,
		insert = 0.15,
		visual = 0.15,
	},
	set_cursor = true,
	set_cursorline = true,
	set_number = true,
	set_signcolumn = true,
	ignore_filetypes = {
		'NvimTree',
		'lspinfo',
		'packer',
		'checkhealth',
		'help',
		'man',
		'TelescopePrompt',
		'TelescopeResults',
	},
}
local winhighlight = {
	default = {
		CursorLine = 'CursorLine',
		CursorLineNr = 'CursorLineNr',
		CursorLineSign = 'CursorLineSign',
		CursorLineFold = 'CursorLineFold',
		Visual = 'Visual',
	},
	copy = {
		CursorLine = 'ModesCopyCursorLine',
		CursorLineNr = 'ModesCopyCursorLineNr',
		CursorLineSign = 'ModesCopyCursorLineSign',
		CursorLineFold = 'ModesCopyCursorLineFold',
	},
	insert = {
		CursorLine = 'ModesInsertCursorLine',
		CursorLineNr = 'ModesInsertCursorLineNr',
		CursorLineSign = 'ModesInsertCursorLineSign',
		CursorLineFold = 'ModesInsertCursorLineFold',
	},
	delete = {
		CursorLine = 'ModesDeleteCursorLine',
		CursorLineNr = 'ModesDeleteCursorLineNr',
		CursorLineSign = 'ModesDeleteCursorLineSign',
		CursorLineFold = 'ModesDeleteCursorLineFold',
	},
	visual = {
		CursorLine = 'ModesVisualCursorLine',
		CursorLineNr = 'ModesVisualCursorLineNr',
		CursorLineSign = 'ModesVisualCursorLineSign',
		CursorLineFold = 'ModesVisualCursorLineFold',
		Visual = 'ModesVisualVisual',
	},
}
local colors = {}
local blended_colors = {}
local operator_started = false
local tracking_key = ''
local in_ignored_buffer = function()
	return vim.api.nvim_buf_get_option(0, 'buftype') ~= '' -- not a normal buffer
		 or not vim.api.nvim_buf_get_option(0, 'buflisted') -- unlisted buffer
		 or vim.tbl_contains(config.ignore_filetypes, vim.bo.filetype)
end

M.reset = function()
	M.highlight('default')
	operator_started = false
end

---Update highlights
---@param scene 'default'|'insert'|'visual'|'copy'|'delete'|
M.highlight = function(scene)
	if in_ignored_buffer() then
		return
	end

	local winhl_map = {}
	local prev_value = vim.api.nvim_win_get_option(0, 'winhighlight')

	-- mapping the old value of 'winhighlight'
	if prev_value ~= '' then
		for _, winhl in ipairs(vim.split(prev_value, ',')) do
			local pair = vim.split(winhl, ':')
			winhl_map[pair[1]] = pair[2]
		end
	end

	-- overrides 'builtin':'hl' if the current scene has a mapping for it
	for builtin, hl in pairs(winhighlight[scene]) do
		winhl_map[builtin] = hl
	end

	if not config.set_number then
		winhl_map.CursorLineNr = nil
	end

	if not config.set_signcolumn then
		winhl_map.CursorLineSign = nil
	end

	local new_value = {}
	for builtin, hl in pairs(winhl_map) do
		table.insert(new_value, ('%s:%s'):format(builtin, hl))
	end
	vim.api.nvim_win_set_option(0, 'winhighlight', table.concat(new_value, ','))

	if vim.api.nvim_get_option('showmode') then
		if scene == 'visual' then
			utils.set_hl('ModeMsg', { link = 'ModesVisualModeMsg' })
		elseif scene == 'insert' then
			utils.set_hl('ModeMsg', { link = 'ModesInsertModeMsg' })
		end
	end

	if config.set_cursor then
		if scene == 'delete' then
			utils.set_hl('ModesOperator', { link = 'ModesDelete' })
		elseif scene == 'copy' then
			utils.set_hl('ModesOperator', { link = 'ModesCopy' })
		end
	end
end

M.define = function()
	colors = {
		bg = config.colors.bg or utils.get_bg('Normal', 'Normal'),
		copy = config.colors.copy or utils.get_bg('ModesCopy', '#f5c359'),
		delete = config.colors.delete or utils.get_bg('ModesDelete', '#c75c6a'),
		insert = config.colors.insert or utils.get_bg('ModesInsert', '#78ccc5'),
		visual = config.colors.visual or utils.get_bg('ModesVisual', '#9745be'),
	}
	blended_colors = {
		copy = utils.blend(colors.copy, colors.bg, config.line_opacity.copy),
		delete = utils.blend(
			colors.delete,
			colors.bg,
			config.line_opacity.delete
		),
		insert = utils.blend(
			colors.insert,
			colors.bg,
			config.line_opacity.insert
		),
		visual = utils.blend(
			colors.visual,
			colors.bg,
			config.line_opacity.visual
		),
	}

	---Create highlight groups
	if colors.copy ~= "" then
		vim.cmd('hi ModesCopy guibg=' .. colors.copy)
	end
	if colors.delete ~= "" then
		vim.cmd('hi ModesDelete guibg=' .. colors.delete)
	end
	if colors.insert ~= "" then
		vim.cmd('hi ModesInsert guibg=' .. colors.insert)
	end
	if colors.visual ~= "" then
		vim.cmd('hi ModesVisual guibg=' .. colors.visual)
	end

	local default_cursorline = utils.get_bg('CursorLine', '#26233a')

	if config.set_number then
		vim.cmd('hi CursorLineNr guibg=' .. default_cursorline)
	end

	if config.set_signcolumn then
		vim.cmd('hi CursorLineSign guibg=' .. default_cursorline)
	end

	for _, mode in ipairs({ 'Copy', 'Delete', 'Insert', 'Visual' }) do
		if colors[mode:lower()] ~= "" then
			local def = { bg = blended_colors[mode:lower()] }
			utils.set_hl(('Modes%sCursorLine'):format(mode), def)
			utils.set_hl(('Modes%sCursorLineNr'):format(mode), def)
			utils.set_hl(('Modes%sCursorLineSign'):format(mode), def)
			utils.set_hl(('Modes%sCursorLineFold'):format(mode), def)
		end
	end

	if colors.insert ~= "" then
		utils.set_hl('ModesInsertModeMsg', { fg = colors.insert })
	end
	if colors.visual ~= "" then
		utils.set_hl('ModesVisualModeMsg', { fg = colors.visual })
		utils.set_hl('ModesVisualVisual', { bg = blended_colors.visual })
	end
end

M.enable_managed_ui = function()
	if in_ignored_buffer() then
		return
	end

	if config.set_cursor then
		vim.opt.guicursor:append('v-sm:ModesVisual')
		vim.opt.guicursor:append('i-ci-ve:ModesInsert')
		vim.opt.guicursor:append('r-cr-o:ModesOperator')
	end

	if config.set_cursorline then
		vim.opt.cursorline = true
	end
end

M.disable_managed_ui = function()
	if in_ignored_buffer() then
		return
	end

	if config.set_cursor then
		vim.opt.guicursor:remove('v-sm:ModesVisual')
		vim.opt.guicursor:remove('i-ci-ve:ModesInsert')
		vim.opt.guicursor:remove('r-cr-o:ModesOperator')
	end

	if config.set_cursorline then
		vim.opt.cursorline = false
	end
end

M.setup = function(opts)
	opts = vim.tbl_extend('keep', opts or {}, default_config)
	if opts.focus_only then
		print(
			'modes.nvim – `focus_only` has been removed and is now the default behaviour'
		)
	end

	config = vim.tbl_deep_extend('force', default_config, opts)

	if type(config.line_opacity) == 'number' then
		config.line_opacity = {
			copy = config.line_opacity,
			delete = config.line_opacity,
			insert = config.line_opacity,
			visual = config.line_opacity,
		}
	end

	M.define()

	vim.on_key(function(key)
		tracking_key = key
		local ok, current_mode = pcall(vim.fn.mode)
		if not ok then
			M.reset()
			return
		end

		if current_mode == 'n' then
			-- reset if coming back from operator pending mode
			if operator_started then
				M.reset()
				return
			end
		end
	end)

	---Set highlights when colorscheme changes
	vim.api.nvim_create_autocmd('ColorScheme', {
		pattern = '*',
		callback = M.define,
	})

	---Set insert highlight
	vim.api.nvim_create_autocmd('InsertEnter', {
		pattern = '*',
		callback = function()
			M.highlight('insert')
		end,
	})

	---Set visual highlight
	vim.api.nvim_create_autocmd('ModeChanged', {
		pattern = '*:[vV\x16]',
		callback = function()
			M.highlight('visual')
		end,
	})

	---Reset visual highlight
	vim.api.nvim_create_autocmd('ModeChanged', {
		pattern = '[vV\x16]:n',
		callback = M.reset,
	})

	--Tracking copy and delete mode
	vim.api.nvim_create_autocmd('ModeChanged', {
		pattern = '*:*o',
		callback = function(_)
			if tracking_key == 'y' then
				operator_started = true
				M.highlight('copy')
			end

			if tracking_key == 'd' then
				operator_started = true
				M.highlight('delete')
			end
		end,
	})

	---Reset highlights
	vim.api.nvim_create_autocmd(
		{ 'CmdlineLeave', 'InsertLeave', 'TextYankPost', 'WinLeave' },
		{
			pattern = '*',
			callback = M.reset,
		}
	)

	---Enable managed UI initially
	M.enable_managed_ui()

	---Enable managed UI for current window
	vim.api.nvim_create_autocmd('WinEnter', {
		pattern = '*',
		callback = M.enable_managed_ui,
	})

	---Disable managed UI for unfocused windows
	vim.api.nvim_create_autocmd('WinLeave', {
		pattern = '*',
		callback = M.disable_managed_ui,
	})
end

return M
