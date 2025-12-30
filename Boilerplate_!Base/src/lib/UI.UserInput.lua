--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : UserInput
-- @copyright: Emil Zhai <root@zhaiyiming.com>
--------------------------------------------------------------------------------
---@class (partial) Boilerplate
local X = Boilerplate
--------------------------------------------------------------------------------
local MODULE_PATH = X.NSFormatString('{$NS}_!Base/lib/UI.UserInput')
--------------------------------------------------------------------------------
--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'START')--[[#DEBUG END]]
--------------------------------------------------------------------------------
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')
--------------------------------------------------------------------------------

local DEFAULT_W, DEFAULT_H = 420, 140
local DEFAULT_MULTILINE_W, DEFAULT_MULTILINE_H = 520, 320
local BTN_H, BTN_W = 30, 100
local PADDING = 10

local function OpenSingleLineInput(opt)
	local szFrameName = opt.name or X.NSFormatString('{$NS}_DefaultUserInput')
	X.UI.CloseFrame(szFrameName)

	local ui
	local function OnResize()
		local nW, nH = ui:ContainerSize()
		ui:Fetch('WndEditBox')
			:Pos(PADDING, PADDING)
			:Size(nW - PADDING * 2, nH - PADDING * 3 - BTN_H)
		ui:Fetch('Btn_Confirm')
			:Pos((nW - BTN_W) / 2, nH - PADDING - BTN_H)
			:Size(BTN_W, BTN_H)
	end

	ui = X.UI.CreateFrame(szFrameName, {
		w = opt.w or DEFAULT_W,
		h = opt.h or DEFAULT_H,
		alpha = opt.alpha or 180,
		text = opt.title or _L['User Input'],
		anchor = opt.anchor or { s = 'CENTER', r = 'CENTER', x = 0, y = 0 },
		theme = X.UI.FRAME_THEME.SIMPLE,
		close = true,
		esc = true,
		resize = true,
		minimize = false,
		onSizeChange = OnResize,
	})

	ui:Append('WndEditBox', {
		name = 'WndEditBox',
		x = PADDING,
		y = PADDING,
		w = (opt.w or DEFAULT_W) - PADDING * 2,
		h = (opt.h or DEFAULT_H) - PADDING * 3 - BTN_H,
		multiline = false,
		text = opt.initialValue and tostring(opt.initialValue) or '',
		placeholder = opt.placeholder,
		alignHorizontal = 0,
		alignVertical = 0,
		maxLength = opt.maxLength,
		onSpecialKeyDown = function(_, szKey)
			if szKey == 'Enter' then
				ui:Fetch('Btn_Confirm'):Click()
				return 1
			end
		end,
	})

	ui:Append('WndButton', {
		name = 'Btn_Confirm',
		x = 0,
		y = 0,
		w = BTN_W,
		h = BTN_H,
		text = opt.confirmText or (g_tStrings and g_tStrings.STR_HOTKEY_SURE) or 'OK',
		onClick = function()
			local szValue = ui:Fetch('WndEditBox'):Text() or ''
			opt.fnAction(szValue)
			ui:Remove()
		end,
	})

	ui:Focus()
	OnResize()
	return ui
end

local function OpenMultiLineInput(opt)
	local szFrameName = opt.name or X.NSFormatString('{$NS}_DefaultUserInput_Multiline')
	X.UI.CloseFrame(szFrameName)

	local ui
	local function OnResize()
		local nW, nH = ui:ContainerSize()
		ui:Fetch('WndEditBox')
			:Pos(PADDING, PADDING)
			:Size(nW - PADDING * 2, nH - PADDING * 3 - BTN_H)
		ui:Fetch('Btn_Confirm')
			:Pos((nW - BTN_W) / 2, nH - PADDING - BTN_H)
			:Size(BTN_W, BTN_H)
	end

	ui = X.UI.CreateFrame(szFrameName, {
		w = opt.w or DEFAULT_MULTILINE_W,
		h = opt.h or DEFAULT_MULTILINE_H,
		alpha = opt.alpha or 180,
		text = opt.title or _L['User Input'],
		anchor = opt.anchor or { s = 'CENTER', r = 'CENTER', x = 0, y = 0 },
		theme = X.UI.FRAME_THEME.SIMPLE,
		close = true,
		esc = true,
		resize = true,
		minimize = false,
		onSizeChange = OnResize,
	})

	ui:Append('WndEditBox', {
		name = 'WndEditBox',
		x = PADDING,
		y = PADDING,
		w = (opt.w or DEFAULT_MULTILINE_W) - PADDING * 2,
		h = (opt.h or DEFAULT_MULTILINE_H) - PADDING * 3 - BTN_H,
		multiline = true,
		text = opt.initialValue and tostring(opt.initialValue) or '',
		placeholder = opt.placeholder,
		alignHorizontal = 0,
		alignVertical = 0,
		maxLength = opt.maxLength,
	})

	ui:Append('WndButton', {
		name = 'Btn_Confirm',
		x = 0,
		y = 0,
		w = BTN_W,
		h = BTN_H,
		text = opt.confirmText or (g_tStrings and g_tStrings.STR_HOTKEY_SURE) or 'OK',
		onClick = function()
			local szValue = ui:Fetch('WndEditBox'):Text() or ''
			opt.fnAction(szValue)
			ui:Remove()
		end,
	})

	ui:Focus()
	OnResize()
	return ui
end

-- Global API
---@class UI_GetUserInput_Options @用户输入参数
---@field placeholder string? @占位提示
---@field initialValue string|number? @初始值（内部会 tostring）
---@field multiline boolean? @是否多行
---@field maxLength number? @最大长度
---@field name string? @窗体名（用于复用/关闭）
---@field title string? @标题
---@field w number? @宽度
---@field h number? @高度
---@field alpha number? @透明度
---@field anchor FrameAnchor? @位置
---@field confirmText string? @确认按钮文本
---@field fnAction fun(value: string) @确认回调

---@param opt UI_GetUserInput_Options @参数
---@return any ui @窗体对象（由 UI.CreateFrame 返回）
function X.UI.GetUserInput(opt)
	if not X.IsTable(opt) or type(opt.fnAction) ~= 'function' then
		return
	end
	if opt.multiline then
		return OpenMultiLineInput(opt)
	end
	return OpenSingleLineInput(opt)
end

---@class UI_GetUserInputNumber_Options @数字输入参数
---@field placeholder string? @占位提示
---@field initialValue number? @初始值
---@field min number? @最小值
---@field max number? @最大值
---@field maxLength number? @最大长度
---@field w number? @宽度
---@field h number? @高度
---@field alpha number? @透明度
---@field anchor FrameAnchor? @位置
---@field confirmText string? @确认按钮文本
---@field fnAction fun(value: number) @确认回调

---@param opt UI_GetUserInputNumber_Options @参数
---@return any ui @窗体对象（由 UI.CreateFrame 返回）
function X.UI.GetUserInputNumber(opt)
	if not X.IsTable(opt) or type(opt.fnAction) ~= 'function' then
		return
	end
	return X.UI.GetUserInput({
		placeholder = opt.placeholder,
		initialValue = opt.initialValue,
		multiline = false,
		maxLength = opt.maxLength,
		w = opt.w,
		h = opt.h,
		alpha = opt.alpha,
		anchor = opt.anchor,
		confirmText = opt.confirmText,
		fnAction = function(szText)
			local n = tonumber(szText)
			if not n then
				return
			end
			if not X.IsNil(opt.min) and n < opt.min then
				return
			end
			if not X.IsNil(opt.max) and n > opt.max then
				return
			end
			opt.fnAction(n)
		end,
	})
end

--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'FINISH')--[[#DEBUG END]]
