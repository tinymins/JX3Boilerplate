--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 游戏环境库
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
--------------------------------------------------------------------------------
---@type Boilerplate
local X = Boilerplate
--------------------------------------------------------------------------------
local MODULE_PATH = X.NSFormatString('{$NS}_!Base/lib/Game.KObject.Target')
--------------------------------------------------------------------------------
--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'START')--[[#DEBUG END]]
--------------------------------------------------------------------------------
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')
--------------------------------------------------------------------------------

-- 获取目标类型（仅支持NPC或玩家）
---@param dwID number @目标ID
---@return number @目标类型
function X.GetTargetType(dwID)
	if X.IsPlayer(dwID) then
		return TARGET.PLAYER
	end
	return TARGET.NPC
end

-- 获取目标气血和最大气血
---@param kTar userdata @目标对象
---@return number @目标气血，最大气血
function X.GetTargetLife(kTar)
	if not kTar then
		return
	end
	return X.IS_REMAKE and kTar.fCurrentLife64 or kTar.nCurrentLife,
		X.IS_REMAKE and kTar.fMaxLife64 or kTar.nMaxLife
end

-- 获取目标内力和最大内力
---@param kTar userdata @目标对象
---@return number @目标内力，最大内力
function X.GetTargetMana(kTar)
	if not kTar then
		return
	end
	return kTar.nCurrentMana, kTar.nMaxMana
end

do
local CACHE = {}
local function GetTargetSceneIndex(dwID)
	local me = X.GetClientPlayer()
	if not me then
		return
	end
	if not X.IsMonsterMap(me.GetMapID()) then
		return
	end
	local scene = me.GetScene()
	if not scene then
		return
	end
	local nType = X.IsPlayer(dwID) and 0 or 1
	local nIndex = CACHE[dwID]
	if not nIndex or scene.GetTempCustomUnsigned4(1, nIndex * 20 + 1) ~= dwID then
		for i = 0, 9 do
			local nOffset = i * 20 + 1
			if scene.GetTempCustomUnsigned4(nType, nOffset) == dwID then
				CACHE[dwID] = i
				nIndex = i
				break
			end
		end
	end
	return scene, nType, nIndex
end

-- 获取目标精力和最大精力
---@param kTar userdata | number @目标对象或目标ID
---@return number @目标精力，最大精力
function X.GetTargetSpirit(kTar)
	local scene, nType, nIndex = GetTargetSceneIndex(X.IsUserdata(kTar) and kTar.dwID or kTar)
	if scene and nType and nIndex then
		return scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 4),
			scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 8)
	end
end

-- 获取目标耐力和最大耐力
---@param obj userdata | number @目标对象或目标ID
---@return number @目标耐力，最大耐力
function X.GetTargetEndurance(obj)
	local scene, nType, nIndex = GetTargetSceneIndex(X.IsUserdata(obj) and obj.dwID or obj)
	if scene and nType and nIndex then
		return scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 12),
			scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 16)
	end
end
end

-- 求坐标2在坐标1的面向角
---@param nX1 number @坐标1的X坐标
---@param nY1 number @坐标1的Y坐标
---@param nFace1 number @坐标1的面向[0, 255]
---@param nX2 number @坐标2的X坐标
---@param nY2 number @坐标2的Y坐标
---@param bAbs boolean @只允许返回正数角度
---@return number @面向角(-180, 180]
function X.GetPointFaceAngel(nX1, nY1, nFace1, nX2, nY2, bAbs)
	local nFace = (nFace1 * 2 * math.pi / 255) - math.pi
	local nSight = (nX1 == nX2 and ((nY1 > nY2 and math.pi / 2) or - math.pi / 2)) or math.atan((nY2 - nY1) / (nX2 - nX1))
	local nAngel = ((nSight - nFace) % (math.pi * 2) - math.pi) / math.pi * 180
	if bAbs then
		nAngel = math.abs(nAngel)
	end
	return nAngel
end

-- 求目标2在目标1的面向角
---@param kTar1 userdata @目标1
---@param kTar2 userdata @目标2
---@param bAbs boolean @只允许返回正数角度
---@return number @面向角(-180, 180]
function X.GetTargetFaceAngel(kTar1, kTar2, bAbs)
	return X.GetPointFaceAngel(kTar1.nX, kTar1.nY, kTar1.nFaceDirection, kTar2.nX, kTar2.nY, bAbs)
end

--------------------------------------------------------------------------------
-- 角色状态
--------------------------------------------------------------------------------

-- 获取目标是否无敌
---@param kTar userdata @要获取的目标
---@return boolean @目标是否无敌
function X.IsTargetInvincible(kTar)
	if X.GetBuff(kTar, 961) then
		return true
	end
	return false
end

-- 获取目标是否被隔离
---@param kTar userdata @要获取的目标
---@return boolean @目标是否被隔离
function X.IsTargetIsolated(kTar)
	if X.IS_CLASSIC then
		return false
	end
	return kTar.bIsolated
end

--------------------------------------------------------------------------------
-- 角色模型屏蔽状态
--------------------------------------------------------------------------------

do
local CURRENT_NPC_SHOW_ALL = true
local CURRENT_PLAYER_SHOW_ALL = true
local CURRENT_PLAYER_SHOW_PARTY_OVERRIDE = false
X.RegisterEvent('ON_REPRESENT_CMD', 'LIB#PLAYER_DISPLAY_MODE', function()
	if arg0 == 'show npc' then
		CURRENT_NPC_SHOW_ALL = true
	elseif arg0 == 'hide npc' then
		CURRENT_NPC_SHOW_ALL = false
	elseif arg0 == 'show player' then
		CURRENT_PLAYER_SHOW_ALL = true
	elseif arg0 == 'hide player' then
		CURRENT_PLAYER_SHOW_ALL = false
	elseif arg0 == 'show or hide party player 1' then
		CURRENT_PLAYER_SHOW_PARTY_OVERRIDE = true
	elseif arg0 == 'show or hide party player 0' then
		CURRENT_PLAYER_SHOW_PARTY_OVERRIDE = false
	end
end)

--- 获取 NPC 显示状态
---@return boolean @NPC 是否显示
function X.GetNpcVisibility()
	return CURRENT_NPC_SHOW_ALL
end

--- 设置 NPC 显示状态
---@param bShow boolean @NPC 是否显示
function X.SetNpcVisibility(bShow)
	if bShow then
		rlcmd('show npc')
	else
		rlcmd('hide npc')
	end
end

--- 获取玩家显示状态
---@return boolean, boolean @玩家是否显示 @队友是否强制显示
function X.GetPlayerVisibility()
	if UIGetPlayerDisplayMode and PLAYER_DISPLAY_MODE then
		local eMode = UIGetPlayerDisplayMode()
		if eMode == PLAYER_DISPLAY_MODE.ALL then
			return true, true
		end
		if eMode == PLAYER_DISPLAY_MODE.ONLY_PARTY then
			return false, true
		end
		if eMode == PLAYER_DISPLAY_MODE.ONLY_SELF then
			return false, false
		end
		return true, false
	end
	return CURRENT_PLAYER_SHOW_ALL, CURRENT_PLAYER_SHOW_PARTY_OVERRIDE
end

--- 设置玩家显示状态
---@param bShowAll boolean @玩家是否显示
---@param bShowPartyOverride boolean @队友是否强制显示
function X.SetPlayerVisibility(bShowAll, bShowPartyOverride)
	if UISetPlayerDisplayMode and PLAYER_DISPLAY_MODE then
		if bShowAll then
			return UISetPlayerDisplayMode(PLAYER_DISPLAY_MODE.ALL)
		end
		if bShowPartyOverride then
			return UISetPlayerDisplayMode(PLAYER_DISPLAY_MODE.ONLY_PARTY)
		end
		return UISetPlayerDisplayMode(PLAYER_DISPLAY_MODE.ONLY_SELF)
	end
	if bShowAll then
		rlcmd('show player')
	else
		rlcmd('hide player')
	end
	if bShowPartyOverride then
		rlcmd('show or hide party player 1')
	else
		rlcmd('show or hide party player 0')
	end
end
end

--------------------------------------------------------------------------------
-- 目标获取相关接口
--------------------------------------------------------------------------------

-- 取得指定目标的目标类型和ID
---@param kTar userdata @指定的目标
---@return number, number @目标的目标类型, 目标的目标ID
function X.GetTargetTarget(kTar)
	if kTar and kTar.GetTarget then
		return kTar.GetTarget()
	end
	return TARGET.NO_TARGET, 0
end

X.RegisterRestriction('X.SET_TARGET', { ['*'] = true, intl = false })

-- 根据 dwType 类型和 dwID 设置目标
---@param dwType number @目标类型
---@param dwID number @目标ID
---@return boolean @是否成功调用
function X.SetClientPlayerTarget(dwType, dwID)
	if dwType == TARGET.PLAYER then
		if X.IsInShieldedMap() and not X.IsParty(dwID) and X.IsRestricted('X.SET_TARGET') then
			--[[#DEBUG BEGIN]]
			X.OutputDebugMessage('SetClientPlayerTarget', 'Set target to player is forbiden in current map.', X.DEBUG_LEVEL.WARNING)
			--[[#DEBUG END]]
			return false
		end
	elseif dwType == TARGET.NPC then
		local npc = X.GetNpc(dwID)
		if npc and not npc.IsSelectable() and X.IsRestricted('X.SET_TARGET') then
			--[[#DEBUG BEGIN]]
			X.OutputDebugMessage('SetClientPlayerTarget', 'Set target to unselectable npc.', X.DEBUG_LEVEL.WARNING)
			--[[#DEBUG END]]
			return false
		end
	elseif dwType == TARGET.DOODAD then
		if X.IsRestricted('X.SET_TARGET') then
			--[[#DEBUG BEGIN]]
			X.OutputDebugMessage('SetClientPlayerTarget', 'Set target to doodad.', X.DEBUG_LEVEL.WARNING)
			--[[#DEBUG END]]
			return false
		end
	end
	SetTarget(dwType, dwID)
	return true
end

do
local CALLBACK_LIST
-- 获取到当前角色并执行函数
-- @param {function} callback 回调函数
function X.WithClientPlayer(callback)
	local me = X.GetClientPlayer()
	if me then
		X.SafeCall(callback, me)
	elseif CALLBACK_LIST then
		table.insert(CALLBACK_LIST, callback)
	else
		CALLBACK_LIST = {callback}
		X.BreatheCall(X.NSFormatString('{$NS}.WithClientPlayer'), function()
			local me = X.GetClientPlayer()
			if me then
				for _, callback in ipairs(CALLBACK_LIST) do
					X.SafeCall(callback, me)
				end
				CALLBACK_LIST = nil
				X.BreatheCall(X.NSFormatString('{$NS}.WithClientPlayer'), false)
			end
		end)
	end
end
end

-- 获取指定名字的右键菜单
function X.InsertPlayerContextMenu(t, szName, dwID, szGlobalID)
	-- 数据库获取 dwID, szGlobalID 补全信息
	if (not dwID or not szGlobalID) and _G.MY_Farbnamen and _G.MY_Farbnamen.Get then
		local tInfo = _G.MY_Farbnamen.Get(szName)
		if tInfo then
			if not dwID then
				dwID = tonumber(tInfo.dwID)
			end
			if not szGlobalID and X.IsGlobalID(tInfo.szGlobalID) then
				szGlobalID = tInfo.szGlobalID
			end
		end
	end
	-- 跨服处理
	local szOriginName, szServerName = X.DisassemblePlayerGlobalName(szName, true)
	-- 复制
	table.insert(t, {
		szOption = _L['Copy to chat input'],
		fnAction = function()
			X.SendChat(X.GetClientPlayer().szName, '[' .. szName .. ']')
		end,
	})
	-- 密聊 好友 邀请入帮 跟随
	X.Call(InsertPlayerCommonMenu, t, dwID, szName)
	-- 组队
	if szName and InsertInviteTeamMenu then
		InsertInviteTeamMenu(t, szName)
	end
	-- 查看装备
	if (dwID and X.GetClientPlayerID() ~= dwID) or (szGlobalID and szGlobalID ~= X.GetClientPlayerGlobalID()) then
		table.insert(t, {
			szOption = _L['View equipment'],
			fnAction = function()
				if szServerName and X.IsGlobalID(szGlobalID) then
					local dwServerID = X.GetServerIDByName(szServerName)
					X.ViewOtherPlayerByGlobalID(dwServerID, szGlobalID)
				elseif dwID then
					X.ViewOtherPlayerByID(dwID)
				end
			end,
		})
	end
	-- 查看名剑大会信息
	table.insert(t, {
		szOption = g_tStrings.LOOKUP_CORPS,
		-- fnDisable = function() return not X.GetPlayer(dwID) end,
		fnAction = function()
			X.UI.CloseFrame('ArenaCorpsPanel')
			OpenArenaCorpsPanel(true, dwID)
		end,
	})
	-- 加入角色备注
	if _G.MY_PlayerRemark and _G.MY_PlayerRemark.OpenEditPanel then
		table.insert(t, {
			szOption = _L['Edit in MY_PlayerRemark'],
			fnAction = function()
				_G.MY_PlayerRemark.OpenEditPanel(szServerName, dwID, szOriginName, szGlobalID)
			end,
		})
	end
	-- 奇穴 -- 标记
	if dwID and InsertTargetMenu then
		local tx = {}
		InsertTargetMenu(tx, TARGET.PLAYER, dwID, szName)
		for _, v in ipairs(tx) do
			if v.szOption == g_tStrings.LOOKUP_INFO or v.szOption == g_tStrings.STR_LOOKUP_MORE then
				for _, vv in ipairs(v) do
					if vv.szOption == g_tStrings.LOOKUP_NEW_TANLENT then -- 查看奇穴
						table.insert(t, vv)
						break
					end
				end
				break
			end
		end
		for _, v in ipairs(tx) do
			if v.szOption == g_tStrings.STR_ARENA_INVITE_TARGET -- 邀请入名剑队
			or v.szOption == g_tStrings.LOOKUP_INFO             -- 查看更多信息
			or v.szOption == g_tStrings.STR_LOOKUP_MORE         -- 查看更多
			or v.szOption == g_tStrings.CHANNEL_MENTOR          -- 师徒
			or v.szOption == g_tStrings.STR_ADD_SHANG           -- 发布悬赏
			or v.szOption == g_tStrings.STR_MARK_TARGET         -- 标记目标
			or v.szOption == g_tStrings.STR_MAKE_TRADDING       -- 交易
			or v.szOption == g_tStrings.REPORT_RABOT            -- 举报外挂
			then
				table.insert(t, v)
			end
		end
	end

	if IsCtrlKeyDown() and X.IsDebugClient(true) then
		table.insert(t, {
			szOption = _L['Copy debug information'],
			fnAction = function()
				local tDebugInfo
				if _G.MY_Farbnamen and _G.MY_Farbnamen.Get then
					tDebugInfo = _G.MY_Farbnamen.Get(szName)
				else
					tDebugInfo = {
						szName = szName,
						dwID = dwID,
						szGlobalID = szGlobalID,
					}
				end
				X.UI.OpenTextEditor(X.EncodeLUAData(tDebugInfo, '\t'))
			end,
		})
	end

	return t
end

--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'FINISH')--[[#DEBUG END]]
