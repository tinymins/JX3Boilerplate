--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 弹出菜单
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local string, math, table = string, math, table
-- lib apis caching
local X = Boilerplate
local UI, ENVIRONMENT, CONSTANT, wstring, lodash = X.UI, X.ENVIRONMENT, X.CONSTANT, X.wstring, X.lodash
-------------------------------------------------------------------------------------------------------

local PLUGIN_NAME = X.NSFormatString('{$NS}_DragDrop')

local DRAG_FRAME_NAME = X.NSFormatString('{$NS}_UI__Drag')
local DROP_FRAME_NAME = X.NSFormatString('{$NS}_UI__Drop')

local D = {}
local DATA, HOVER_EL

function D.IsOpened()
	return DATA ~= nil
end

function D.Open(raw, capture, ...)
	if D.IsOpened() then
		return
	end
	local captureEl
	local nX, nY = Cursor.GetPos()
	local nW, nH
	local nCaptureX, nCaptureY
	if X.IsElement(capture) then
		captureEl = capture
	elseif X.IsTable(capture) then
		captureEl = capture.element
		nCaptureX = capture.x
		nCaptureY = capture.y
		nW = capture.w
		nH = capture.h
	end
	if not captureEl then
		captureEl = raw
	end
	if not nCaptureX then
		nCaptureX = 0
	end
	if not nCaptureY then
		nCaptureY = 0
	end
	if not nW then
		nW = captureEl:GetW()
	end
	if not nH then
		nH = captureEl:GetH()
	end
	local nCaptureW, nCaptureH = captureEl:GetW(), captureEl:GetH()
	-- 拽入位置提示
	local frame = Wnd.OpenWindow(X.PACKET_INFO.FRAMEWORK_ROOT .. '/ui/DragDrop.ini', DROP_FRAME_NAME)
	frame:SetAlpha(100)
	frame:Hide()
	-- 拖拽状态提示
	local frame = Wnd.OpenWindow(X.PACKET_INFO.FRAMEWORK_ROOT .. '/ui/DragDrop.ini', DRAG_FRAME_NAME)
	frame:Lookup('', ''):SetSize(nW + 4, nH + 4)
	frame:Lookup('', 'Image_Background'):SetSize(nW + 4, nH + 4)
	frame:Lookup('', 'Handle_ScreenShot'):SetSize(nW, nH)
	frame:Lookup('', 'Handle_ScreenShot/Image_ScreenShot'):SetSize(nCaptureW, nCaptureH)
	frame:Lookup('', 'Handle_ScreenShot/Image_ScreenShot'):SetRelPos(-nCaptureX, -nCaptureY)
	if captureEl:GetBaseType() == 'Wnd' then
		frame:Lookup('', 'Handle_ScreenShot/Image_ScreenShot'):FromWindow(captureEl)
	else
		frame:Lookup('', 'Handle_ScreenShot/Image_ScreenShot'):FromItem(captureEl)
	end
	frame:Lookup('', 'Handle_ScreenShot'):FormatAllItemPos()
	frame:SetRelPos(nX, nY)
	frame:SetSize(nW, nH)
	frame:StartMoving()
	frame:BringToTop()
	Cursor.Switch(UI.CURSOR.ON_DRAG)
	DATA = X.Pack(...)
	X.DelayCall(X.NSFormatString('{$NS}_UI__DragDrop_Clear'), false)
end

function D.Close()
	local frame = Station.SearchFrame(DRAG_FRAME_NAME)
	if frame then
		local xData = DATA
		local dropEl = HOVER_EL
		HOVER_EL = nil
		X.DelayCall(X.NSFormatString('{$NS}_UI__DragDrop_Clear'), 50, function() DATA = nil end) -- 由于 Click 在 DragEnd 之后
		Cursor.Switch(UI.CURSOR.NORMAL)
		frame:EndMoving()
		Wnd.CloseWindow(DRAG_FRAME_NAME)
		Wnd.CloseWindow(DROP_FRAME_NAME)
		return dropEl, X.Unpack(xData)
	end
end

function D.GetData()
	if DATA then
		return X.Unpack(DATA)
	end
end

function D.SetHoverEl(el, rect)
	if not D.IsOpened() then
		return
	end
	local frame = Station.SearchFrame(DROP_FRAME_NAME)
	if not frame then
		return
	end
	if el then
		local nX, nY, nW, nH
		if X.IsTable(rect) then
			nX = rect.x
			nY = rect.y
			nW = rect.w
			nH = rect.h
		end
		if not nX then
			nX = el:GetAbsX()
		end
		if not nY then
			nY = el:GetAbsY()
		end
		if not nW then
			nW = el:GetW()
		end
		if not nH then
			nH = el:GetH()
		end
		frame:SetRelPos(nX - 2, nY - 2)
		frame:Lookup('', ''):SetSize(nW + 4, nH + 4)
		frame:Lookup('', 'Image_Background'):SetSize(nW + 4, nH + 4)
		frame:Show()
	else
		frame:Hide()
	end
	HOVER_EL = el
end

-- Global exports
do
local settings = {
	name = PLUGIN_NAME,
	exports = {
		{
			preset = 'UIEvent',
			fields = {
				'IsOpened',
				'Open',
				'Close',
				'GetData',
				'SetHoverEl',
			},
			root = D,
		},
	},
}
_G[PLUGIN_NAME] = X.CreateModule(settings)
end

UI.IsDragDropOpened = D.IsOpened
UI.OpenDragDrop = D.Open
UI.CloseDragDrop = D.Close
UI.GetDragDropData = D.GetData
UI.SetDragDropHoverEl = D.SetHoverEl
