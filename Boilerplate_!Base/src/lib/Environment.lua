--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 环境相关
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
--------------------------------------------------------------------------------
local X = Boilerplate
--------------------------------------------------------------------------------
local MODULE_NAME = X.NSFormatString('{$NS}.Environment')
--------------------------------------------------------------------------------
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')
--------------------------------------------------------------------------------
X.ReportModuleLoading(MODULE_NAME, 'START')
--------------------------------------------------------------------------------

function X.AssertVersion(szKey, szCaption, szRequireVersion)
	if not X.IsString(szRequireVersion) then
		X.Sysmsg(_L(
			'%s requires a invalid base library version value: %s.',
			szCaption, X.EncodeLUAData(szRequireVersion)))
		return IsDebugClient() or false
	end
	if not (X.Semver(X.PACKET_INFO.VERSION) % szRequireVersion) then
		X.Sysmsg(_L(
			'%s requires base library version at %s, current at %s.',
			szCaption, szRequireVersion, X.PACKET_INFO.VERSION))
		return IsDebugClient() or false
	end
	return true
end

-- 获取功能屏蔽等级
do
local DELAY_EVENT = {}
local RESTRICTION = {}

-- 注册功能在不同分支下屏蔽状态
-- X.RegisterRestriction('SomeFunc', { ['*'] = true, intl = false })
function X.RegisterRestriction(szKey, tBranchRestricted)
	local bRestricted = nil
	if X.IsTable(tBranchRestricted) then
		if X.IsBoolean(tBranchRestricted[X.ENVIRONMENT.GAME_BRANCH]) then
			bRestricted = tBranchRestricted[X.ENVIRONMENT.GAME_BRANCH]
		elseif X.IsBoolean(tBranchRestricted['*']) then
			bRestricted = tBranchRestricted['*']
		end
	end
	if not X.IsBoolean(bRestricted) then
		--[[#DEBUG BEGIN]]
		X.Debug(X.PACKET_INFO.NAME_SPACE, 'Restriction should be a boolean value: ' .. szKey, X.DEBUG_LEVEL.ERROR)
		--[[#DEBUG END]]
		return
	end
	RESTRICTION[szKey] = bRestricted
end

-- 获取功能在当前分支是否已屏蔽
-- X.IsRestricted('SomeFunc')
function X.IsRestricted(szKey, ...)
	if select('#', ...) == 1 then
		-- 设置值
		local bRestricted = ...
		if not X.IsNil(bRestricted) then
			bRestricted = not not bRestricted
		end
		if RESTRICTION[szKey] == bRestricted then
			return
		end
		RESTRICTION[szKey] = bRestricted
		-- 发起事件通知
		local szEvent = X.NSFormatString('{$NS}.RESTRICTION')
		if szKey == '!' then
			for k, _ in pairs(DELAY_EVENT) do
				X.DelayCall(k, false)
			end
			DELAY_EVENT = {}
			szKey = nil
		else
			szEvent = szEvent .. '.' .. szKey
		end
		X.DelayCall(szEvent, 75, function()
			if X.IsPanelOpened() then
				X.ReopenPanel()
			end
			DELAY_EVENT[szEvent] = nil
			FireUIEvent(X.NSFormatString('{$NS}_RESTRICTION'), szKey)
		end)
		DELAY_EVENT[szEvent] = true
	else
		if not X.IsNil(RESTRICTION['!']) then
			return RESTRICTION['!']
		end
		return RESTRICTION[szKey] or false
	end
end
end

-- 获取是否测试客户端
-- (bool) X.IsDebugClient()
-- (bool) X.IsDebugClient(bool bManually = false)
-- (bool) X.IsDebugClient(string szKey[, bool bDebug, bool bSet])
do
local DELAY_EVENT = {}
local DEBUG = { ['*'] = X.PACKET_INFO.DEBUG_LEVEL <= X.DEBUG_LEVEL.DEBUG }
function X.IsDebugClient(szKey, bDebug, bSet)
	if not X.IsString(szKey) then
		szKey, bDebug, bSet = '*', szKey, bDebug
	end
	if bSet then
		-- 通用禁止设为空
		if szKey == '*' and X.IsNil(bDebug) then
			return
		end
		-- 设置值
		if DEBUG[szKey] == bDebug then
			return
		end
		DEBUG[szKey] = bDebug
		-- 发起事件通知
		local szEvent = X.NSFormatString('{$NS}#DEBUG')
		if szKey == '*' or szKey == '!' then
			for k, _ in pairs(DELAY_EVENT) do
				X.DelayCall(k, false)
			end
			szKey = nil
		else
			szEvent = szEvent .. '#' .. szKey
		end
		X.DelayCall(szEvent, 75, function()
			if X.IsPanelOpened() then
				X.ReopenPanel()
			end
			DELAY_EVENT[szEvent] = nil
			FireUIEvent(X.NSFormatString('{$NS}_DEBUG'), szKey)
		end)
		DELAY_EVENT[szEvent] = true
	else
		if not X.IsNil(DEBUG['!']) then
			return DEBUG['!']
		end
		if szKey == '*' and not bDebug then
			return IsDebugClient()
		end
		if not X.IsNil(DEBUG[szKey]) then
			return DEBUG[szKey]
		end
		return DEBUG['*']
	end
end
end

-- 获取是否测试服务器
function X.IsDebugServer()
	local ip = X.ENVIRONMENT.SERVER_ADDRESS
	if ip:find('^10%.') -- 10.0.0.0/8
		or ip:find('^127%.') -- 127.0.0.0/8
		or ip:find('^172%.1[6-9]%.') -- 172.16.0.0/12
		or ip:find('^172%.2[0-9]%.') -- 172.16.0.0/12
		or ip:find('^172%.3[0-1]%.') -- 172.16.0.0/12
		or ip:find('^192%.168%.') -- 192.168.0.0/16
	then
		return true
	end
	return false
end

X.ReportModuleLoading(MODULE_NAME, 'FINISH')
