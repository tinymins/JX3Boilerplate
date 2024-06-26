--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 游戏环境库
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
--------------------------------------------------------------------------------
local X = Boilerplate
--------------------------------------------------------------------------------
local MODULE_PATH = X.NSFormatString('{$NS}_!Base/lib/Game.MapCD')
--------------------------------------------------------------------------------
--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'START')--[[#DEBUG END]]
--------------------------------------------------------------------------------
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')
--------------------------------------------------------------------------------

-- 获取秘境CD列表（异步）
-- (table) X.GetMapSaveCopy(fnAction)
-- (number|nil) X.GetMapSaveCopy(dwMapID, fnAction)
do
local QUEUE = {}
local SAVED_COPY_CACHE, REQUEST_FRAME
function X.GetMapSaveCopy(arg0, arg1)
	local dwMapID, fnAction
	if X.IsFunction(arg0) then
		fnAction = arg0
	elseif X.IsNumber(arg0) then
		if X.IsFunction(arg1) then
			fnAction = arg1
		end
		dwMapID = arg0
	end
	if SAVED_COPY_CACHE then
		if dwMapID then
			if fnAction then
				fnAction(SAVED_COPY_CACHE[dwMapID])
			end
			return SAVED_COPY_CACHE[dwMapID]
		else
			if fnAction then
				fnAction(SAVED_COPY_CACHE)
			end
			return SAVED_COPY_CACHE
		end
	else
		if fnAction then
			table.insert(QUEUE, { dwMapID = dwMapID, fnAction = fnAction })
		end
		if REQUEST_FRAME ~= GetLogicFrameCount() then
			ApplyMapSaveCopy()
			REQUEST_FRAME = GetLogicFrameCount()
		end
	end
end

function X.IsDungeonResetable(dwMapID)
	if not SAVED_COPY_CACHE then
		return
	end
	if not X.IsDungeonMap(dwMapID, false) then
		return false
	end
	return SAVED_COPY_CACHE[dwMapID]
end

local function onApplyPlayerSavedCopyRespond()
	SAVED_COPY_CACHE = arg0
	for _, v in ipairs(QUEUE) do
		if v.dwMapID then
			v.fnAction(SAVED_COPY_CACHE[v.dwMapID])
		else
			v.fnAction(SAVED_COPY_CACHE)
		end
	end
	QUEUE = {}
end
X.RegisterEvent('ON_APPLY_PLAYER_SAVED_COPY_RESPOND', onApplyPlayerSavedCopyRespond)

local function onCopyUpdated()
	SAVED_COPY_CACHE = nil
end
X.RegisterEvent('ON_RESET_MAP_RESPOND', onCopyUpdated)
X.RegisterEvent('ON_MAP_COPY_PROGRESS_UPDATE', onCopyUpdated)
end

-- 获取日常周常下次刷新时间和刷新周期
-- (dwTime, dwCircle) X.GetRefreshTime(szType)
-- @param szType {string} 刷新类型 daily weekly half-weekly
-- @return dwTime {number} 下次刷新时间
-- @return dwCircle {number} 刷新周期
function X.GetRefreshTime(szType)
	local nNextTime, nCircle = 0, 0
	local nTime = GetCurrentTime()
	local date = TimeToDate(nTime)
	if szType == 'daily' then -- 每天7点
		if date.hour < 7 then
			nNextTime = nTime + (7 - date.hour) * 3600 + (0 - date.minute) * 60 + (0 - date.second)
		else
			nNextTime = nTime + (7 + 24 - date.hour) * 3600 + (0 - date.minute) * 60 + (0 - date.second)
		end
		nCircle = 86400
	elseif szType == 'half-weekly' then -- 周一7点 周五7点
		if ((date.weekday == 1 and date.hour >= 7) or date.weekday >= 2)
		and ((date.weekday == 5 and date.hour < 7) or date.weekday <= 4) then -- 周一7点 - 周五7点
			nNextTime = nTime + (5 - date.weekday) * 86400 + (7 * 3600 - date.hour * 3600) + (0 - date.minute) * 60 + (0 - date.second)
			nCircle = 345600
		else
			if date.weekday == 0 or date.weekday == 1 then -- 周日0点 - 周一7点
				nNextTime = nTime + (1 - date.weekday) * 86400 + (7 * 3600 - date.hour * 3600) + (0 - date.minute) * 60 + (0 - date.second)
			else -- 周五7点 - 周六24点
				nNextTime = nTime + (8 - date.weekday) * 86400 + (7 * 3600 - date.hour * 3600) + (0 - date.minute) * 60 + (0 - date.second)
			end
			nCircle = 259200
		end
	else -- if szType == 'weekly' then -- 周一7点
		if date.weekday == 0 or (date.weekday == 1 and date.hour < 7) then -- 周日0点 - 周一7点
			nNextTime = nTime + (1 - date.weekday) * 86400 + (7 * 3600 - date.hour * 3600) + (0 - date.minute) * 60 + (0 - date.second)
		else -- 周一7点 - 周六24点
			nNextTime = nTime + (8 - date.weekday) * 86400 + (7 * 3600 - date.hour * 3600) + (0 - date.minute) * 60 + (0 - date.second)
		end
		nCircle = 604800
	end
	return nNextTime, nCircle
end

function X.IsInSameRefreshTime(szType, dwTime)
	local nNextTime, nCircle = X.GetRefreshTime(szType)
	return nNextTime > dwTime and nNextTime - dwTime <= nCircle
end

-- 获取秘境地图刷新时间
-- (number nNextTime, number nCircle) X.GetDungeonRefreshTime(dwMapID)
function X.GetDungeonRefreshTime(dwMapID)
	local _, nMapType, nMaxPlayerCount = GetMapParams(dwMapID)
	if nMapType == MAP_TYPE.DUNGEON then
		if nMaxPlayerCount <= 5 then -- 5人本
			return X.GetRefreshTime('daily')
		end
		if nMaxPlayerCount <= 10 then -- 10人本
			return X.GetRefreshTime('half-weekly')
		end
		if nMaxPlayerCount <= 25 then -- 25人本
			return X.GetRefreshTime('weekly')
		end
	end
	return 0, 0
end

---获取地图秘境进度信息
---@param dwMapID number @要获取的地图ID
---@param nProcessID number @要获取的进度ID
---@return table @秘境首领与进度状态列表
function X.GetMapCDProcessInfo(dwMapID, nProcessID)
	if GetCDProcessInfo then
		local aInfo = {}
		for _, v in ipairs(GetCDProcessInfo(dwMapID, nProcessID) or X.CONSTANT.EMPTY_TABLE) do
			table.insert(aInfo, {
				dwBossIndex = v.BossIndex,
				dwMapID = v.MapID,
				szName = v.Name,
				dwProgressID = v.ProgressID,
			})
		end
		return aInfo
	end
	return Table_GetCDProcessBoss(dwMapID, nProcessID)
end

--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'FINISH')--[[#DEBUG END]]
