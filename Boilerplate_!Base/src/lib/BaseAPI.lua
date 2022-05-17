--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : ��Ϸͨ�ú���
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
--------------------------------------------------------------------------------
local X = Boilerplate
--------------------------------------------------------------------------------

-- Lua �������л�
---@overload fun(data: any, indent: string, level: number): string
---@param data any @Ҫ���л�������
---@param indent string @�����ַ���
---@param level number @��ǰ�㼶
---@return string @���л�����ַ���
X.EncodeLUAData = _G.var2str

-- Lua ���ݷ����л�
---@overload fun(data: string): any
---@param data string @Ҫ�����л����ַ���
---@return any @�����л��������
X.DecodeLUAData = _G.str2var or function(szText)
	local DECODE_ROOT = X.PACKET_INFO.DATA_ROOT .. '#cache/decode/'
	local DECODE_PATH = DECODE_ROOT .. GetCurrentTime() .. GetTime() .. math.random(0, 999999) .. '.jx3dat'
	CPath.MakeDir(DECODE_ROOT)
	SaveDataToFile(szText, DECODE_PATH)
	local data = LoadLUAData(DECODE_PATH)
	CPath.DelFile(DECODE_PATH)
	return data
end

-- ��ȡ��Ϸ�ӿ�
---@param szAddon string @�ӿڵ�������
---@param szInside string @�ӿ�ԭʼ����
---@return any @�ӿڶ���
function X.GetGameAPI(szAddon, szInside)
	local api = _G[szAddon]
	if not api and _DEBUG_LEVEL_ < X.DEBUG_LEVEL.NONE then
		local env = GetInsideEnv()
		if env then
			api = env[szInside or szAddon]
		end
	end
	return api
end

-- ��ȡ��Ϸ���ݱ�
---@param szTable string @���ݱ�����
---@param bPrintError boolean @�Ƿ��ӡ������Ϣ
---@return any @���ݱ�����
function X.GetGameTable(szTable, bPrintError)
	local b, t = (bPrintError and X.Call or pcall)(function() return g_tTable[szTable] end)
	if b then
		return t
	end
end

local LOG_MAX_FILE = 30
local LOG_MAX_LINE = 5000
local LOG_LINE_COUNT = 0
local LOG_CACHE
local LOG_PATH, LOG_DATE
local LOG_TAG = (GetCurrentTime() + 8 * 60 * 60) % (24 * 60 * 60)

-- ���һ����־����־�ļ�
---@vararg string ��־����㼶1, ��־����㼶2, ��־����㼶3, ..., ��־����㼶n, ��־����
function X.Log(...)
	local nType = select('#', ...) - 1
	local szText = select(nType + 1, ...)
	local tTime = TimeToDate(GetCurrentTime())
	local szDate = string.format('%04d-%02d-%02d', tTime.year, tTime.month, tTime.day)
	local szType = ''
	for i = 1, nType do
		szType = szType .. '[' .. select(i, ...) .. ']'
	end
	if szType ~= '' then
		szType = szType .. ' '
	end
	local szLog = string.format('%04d/%02d/%02d_%02d:%02d:%02d %s%s\n', tTime.year, tTime.month, tTime.day, tTime.hour, tTime.minute, tTime.second, szType, szText)
	if LOG_DATE ~= szDate or LOG_LINE_COUNT >= LOG_MAX_LINE then
		-- ϵͳδ��ʼ����ɣ����뻺������ȴ�д��
		if not X.GetPlayerGUID or not X.GetPlayerGUID() then
			if not LOG_CACHE then
				LOG_CACHE = {}
			end
			table.insert(LOG_CACHE, szLog)
			return
		end
		if LOG_PATH then
			Log(LOG_PATH, '', 'close')
		end
		LOG_PATH = X.FormatPath({
			'logs/'
				.. szDate .. '/JX3_'
				.. X.PACKET_INFO.NAME_SPACE
				.. '_' .. X.ENVIRONMENT.GAME_PROVIDER
				.. '_' .. X.ENVIRONMENT.GAME_EDITION
				.. '_' .. X.ENVIRONMENT.GAME_VERSION
				.. '_' .. LOG_TAG
				.. '_' .. string.format('%04d-%02d-%02d_%02d-%02d-%02d', tTime.year, tTime.month, tTime.day, tTime.hour, tTime.minute, tTime.second)
				.. '.log',
			X.PATH_TYPE.ROLE
		})
		LOG_DATE = szDate
		LOG_LINE_COUNT = 0
	end
	-- ������ڻ������ݣ��ȴ���
	if LOG_CACHE then
		for _, szLog in ipairs(LOG_CACHE) do
			Log(LOG_PATH, szLog)
			LOG_LINE_COUNT = LOG_LINE_COUNT + 1
		end
		LOG_CACHE = nil
	end
	LOG_LINE_COUNT = LOG_LINE_COUNT + 1
	Log(LOG_PATH, szLog, 'close')
end

-- ������־�ļ�
function X.DeleteAncientLogs()
	local szRoot = X.FormatPath({'logs/', X.PATH_TYPE.ROLE})
	local aFiles = {}
	for _, filename in ipairs(CPath.GetFileList(szRoot)) do
		local year, month, day = filename:match('^(%d+)%-(%d+)%-(%d+)$')
		if year then
			year = tonumber(year)
			month = tonumber(month)
			day = tonumber(day)
			table.insert(aFiles, { time = DateToTime(year, month, day, 0, 0, 0), filepath = szRoot .. filename })
		end
	end
	if #aFiles <= LOG_MAX_FILE then
		return
	end
	table.sort(aFiles, function(a, b)
		return a.time > b.time
	end)
	for i = LOG_MAX_FILE + 1, #aFiles do
		CPath.DelDir(aFiles[i].filepath)
	end
end

-- ����һ�������ջ��־�������¼�
---@vararg string @������Ϣ���ı�
---@return void
function X.ErrorLog(...)
	local aLine, xLine = {}, nil
	for i = 1, select('#', ...) do
		xLine = select(i, ...)
		aLine[i] = tostring(xLine)
	end
	local szFull = table.concat(aLine, '\n') .. '\n'
	FireUIEvent('CALL_LUA_ERROR', szFull)
end

--[[#DEBUG BEGIN]]
local MODULE_TIME, MODULE_TOTAL_TIME = {}, 0
local MODULE_TIME_RANK = {}
RegisterEvent('LOADING_END', function()
	for szModule, _ in pairs(MODULE_TIME) do
		X.Log('MODULE_LOADING_REPORT', '"' .. szModule .. '" missing FINISH report!!!')
	end
	X.Log('MODULE_LOADING_REPORT', 'All modules loaded during ' .. MODULE_TOTAL_TIME .. 'ms.')
	table.sort(MODULE_TIME_RANK, function(a, b) return a.nTime > b.nTime end)
	local aTop, nMaxModule = {}, 0
	for i, p in ipairs(MODULE_TIME_RANK) do
		if i > 10 or p.nTime < 5 then
			break
		end
		nMaxModule = math.max(nMaxModule, p.szModule:len())
		table.insert(aTop, p)
	end
	if #aTop > 0 then
		X.Log('MODULE_LOADING_REPORT', 'Top ' .. #aTop ..  ' modules loading time:')
	end
	local nTopTime = 0
	for i, p in ipairs(aTop) do
		nTopTime = nTopTime + p.nTime
		X.Log('MODULE_LOADING_REPORT', string.format('%d. %' .. nMaxModule .. 's: %dms', i, p.szModule, p.nTime))
	end
	X.Log('MODULE_LOADING_REPORT', string.format('Top modules total loading time: %dms', nTopTime))
end)
--[[#DEBUG END]]
-- �ű��������ܼ��
---@param szModule string @ģ������
---@param szStatus "'START'" | "'FINISH'" @����״̬
---@return void
function X.ReportModuleLoading(szModule, szStatus)
	--[[#DEBUG BEGIN]]
	if szStatus == 'START' then
		if MODULE_TIME[szModule] then
			X.Log('MODULE_LOADING_REPORT', '"' .. szModule .. '" is already START!!!')
		else
			MODULE_TIME[szModule] = GetTime()
		end
	elseif szStatus == 'FINISH' then
		if MODULE_TIME[szModule] then
			local nTime = GetTime() - MODULE_TIME[szModule]
			MODULE_TIME[szModule] = nil
			MODULE_TOTAL_TIME = MODULE_TOTAL_TIME + nTime
			table.insert(MODULE_TIME_RANK, { szModule = szModule, nTime = nTime })
			X.Log('MODULE_LOADING_REPORT', '"' .. szModule .. '" loaded during ' .. nTime .. 'ms.')
		else
			X.Log('MODULE_LOADING_REPORT', '"' .. szModule .. '" not exist!!!')
		end
	end
	--[[#DEBUG END]]
end

-- ��ʼ�����Թ���
if X.PACKET_INFO.DEBUG_LEVEL < X.DEBUG_LEVEL.NONE then
	if not X.SHARED_MEMORY.ECHO_LUA_ERROR then
		RegisterEvent('CALL_LUA_ERROR', function()
			OutputMessage('MSG_SYS', 'CALL_LUA_ERROR:\n' .. arg0 .. '\n')
		end)
		X.SHARED_MEMORY.ECHO_LUA_ERROR = X.PACKET_INFO.NAME_SPACE
	end
	if not X.SHARED_MEMORY.RELOAD_UI_ADDON then
		TraceButton_AppendAddonMenu({{
			szOption = 'ReloadUIAddon',
			fnAction = function()
				ReloadUIAddon()
			end,
		}})
		X.SHARED_MEMORY.RELOAD_UI_ADDON = X.PACKET_INFO.NAME_SPACE
	end
end
X.Log('[' .. X.PACKET_INFO.NAME_SPACE .. '] Debug level ' .. X.PACKET_INFO.DEBUG_LEVEL .. ' / delog level ' .. X.PACKET_INFO.LOG_LEVEL)