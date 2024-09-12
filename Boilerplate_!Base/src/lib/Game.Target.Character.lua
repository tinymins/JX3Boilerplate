--------------------------------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : ��Ϸ������
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

X.RegisterRestriction('X.SET_TARGET', { ['*'] = true, intl = false })

-- ��ȡĿ�����ͣ���֧��NPC����ң�
---@param dwID number @Ŀ��ID
---@return number @Ŀ������
function X.GetCharacterType(dwID)
	if X.IsPlayer(dwID) then
		return TARGET.PLAYER
	end
	return TARGET.NPC
end

-- ��ȡĿ����󣨽�֧��NPC����ң�
---@param dwID number @Ŀ��ID
---@return userdata | nil @Ŀ����󣬻�ȡʧ�ܷ��� nil
function X.GetCharacterHandle(dwID)
	if X.IsPlayer(dwID) then
		return X.GetPlayer(dwID)
	end
	return X.GetNpc(dwID)
end

-- ͨ������������ȡ��ɫID����֧��NPC����ң�
---@param szName string @��ɫ����
---@return number | nil @��ɫID����ȡʧ�ܷ��� nil
function X.SearchCharacterID(szName)
	local dwID = X.SearchNearPlayerID(szName)
	if dwID then
		return dwID
	end
	local dwID = X.SearchNearNpcID(szName)
	if dwID then
		return dwID
	end
end

-- ͨ������������ȡ��ɫ���󣨽�֧��NPC����ң�
---@param szName string @��ɫ����
---@return userdata | nil @��ɫ���󣬻�ȡʧ�ܷ��� nil
function X.SearchCharacterHandle(szName)
	local dwID = X.SearchCharacterID(szName)
	if dwID then
		return X.GetCharacterHandle(dwID)
	end
end

-- ��ȡĿ����Ѫ�������Ѫ
---@param kTar userdata @Ŀ�����
---@return number @Ŀ����Ѫ�������Ѫ
function X.GetCharacterLife(kTar)
	if not kTar then
		return
	end
	return X.IS_REMAKE and kTar.fCurrentLife64 or kTar.nCurrentLife,
		X.IS_REMAKE and kTar.fMaxLife64 or kTar.nMaxLife
end

-- ��ȡĿ���������������
---@param kTar userdata @Ŀ�����
---@return number @Ŀ���������������
function X.GetCharacterMana(kTar)
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

-- ��ȡĿ�꾫���������
---@param kTar userdata | number @Ŀ������Ŀ��ID
---@return number @Ŀ�꾫���������
function X.GetCharacterSpirit(kTar)
	local scene, nType, nIndex = GetTargetSceneIndex(X.IsUserdata(kTar) and kTar.dwID or kTar)
	if scene and nType and nIndex then
		return scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 4),
			scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 8)
	end
end

-- ��ȡĿ���������������
---@param obj userdata | number @Ŀ������Ŀ��ID
---@return number @Ŀ���������������
function X.GetCharacterEndurance(obj)
	local scene, nType, nIndex = GetTargetSceneIndex(X.IsUserdata(obj) and obj.dwID or obj)
	if scene and nType and nIndex then
		return scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 12),
			scene.GetTempCustomUnsigned4(nType, nIndex * 20 + 1 + 16)
	end
end
end

-- ȡ��ָ��Ŀ���Ŀ�����ͺ�ID
---@param kTar userdata @ָ����Ŀ��
---@return number, number @Ŀ���Ŀ������, Ŀ���Ŀ��ID
function X.GetCharacterTarget(kTar)
	if kTar and kTar.GetTarget then
		return kTar.GetTarget()
	end
	return TARGET.NO_TARGET, 0
end

-- ������2������1�������
---@param nX1 number @����1��X����
---@param nY1 number @����1��Y����
---@param nFace1 number @����1������[0, 255]
---@param nX2 number @����2��X����
---@param nY2 number @����2��Y����
---@param bAbs boolean @ֻ�������������Ƕ�
---@return number @�����(-180, 180]
function X.GetPointFaceAngel(nX1, nY1, nFace1, nX2, nY2, bAbs)
	local nFace = (nFace1 * 2 * math.pi / 255) - math.pi
	local nSight = (nX1 == nX2 and ((nY1 > nY2 and math.pi / 2) or - math.pi / 2)) or math.atan((nY2 - nY1) / (nX2 - nX1))
	local nAngel = ((nSight - nFace) % (math.pi * 2) - math.pi) / math.pi * 180
	if bAbs then
		nAngel = math.abs(nAngel)
	end
	return nAngel
end

-- ��Ŀ��2��Ŀ��1�������
---@param kTar1 userdata @Ŀ��1
---@param kTar2 userdata @Ŀ��2
---@param bAbs boolean @ֻ�������������Ƕ�
---@return number @�����(-180, 180]
function X.GetCharacterFaceAngel(kTar1, kTar2, bAbs)
	return X.GetPointFaceAngel(kTar1.nX, kTar1.nY, kTar1.nFaceDirection, kTar2.nX, kTar2.nY, bAbs)
end

--------------------------------------------------------------------------------
-- ��ɫ״̬
--------------------------------------------------------------------------------

-- ��ȡĿ���Ƿ��޵�
---@param kTar userdata @Ҫ��ȡ��Ŀ��
---@return boolean @Ŀ���Ƿ��޵�
function X.IsCharacterInvincible(kTar)
	if X.GetBuff(kTar, 961) then
		return true
	end
	return false
end

-- ��ȡĿ���Ƿ񱻸���
---@param kTar userdata @Ҫ��ȡ��Ŀ��
---@return boolean @Ŀ���Ƿ񱻸���
function X.IsCharacterIsolated(kTar)
	if X.IS_CLASSIC then
		return false
	end
	return kTar.bIsolated
end

-- ��ȡ����Ŀ��
---@return number, number @������Ŀ������, ������Ŀ��ID
function X.GetClientPlayerTarget()
	local me = X.GetClientPlayer()
	return X.GetCharacterTarget(me)
end

-- ���� dwType ���ͺ� dwID ����Ŀ��
---@param dwType number @Ŀ������
---@param dwID number @Ŀ��ID
---@return boolean @�Ƿ�ɹ�����
function X.SetClientPlayerTarget(dwType, dwID)
	if dwType == TARGET.PLAYER then
		if X.IsInShieldedMap() and not X.IsTeammate(dwID) and X.IsRestricted('X.SET_TARGET') then
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
-- ��ȡ����ǰ��ɫ��ִ�к���
-- @param {function} callback �ص�����
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

--------------------------------------------------------------------------------
-- ��ɫģ������״̬
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

--- ��ȡ NPC ��ʾ״̬
---@return boolean @NPC �Ƿ���ʾ
function X.GetNpcVisibility()
	return CURRENT_NPC_SHOW_ALL
end

--- ���� NPC ��ʾ״̬
---@param bShow boolean @NPC �Ƿ���ʾ
function X.SetNpcVisibility(bShow)
	if bShow then
		rlcmd('show npc')
	else
		rlcmd('hide npc')
	end
end

--- ��ȡ�����ʾ״̬
---@return boolean, boolean @����Ƿ���ʾ @�����Ƿ�ǿ����ʾ
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

--- ���������ʾ״̬
---@param bShowAll boolean @����Ƿ���ʾ
---@param bShowPartyOverride boolean @�����Ƿ�ǿ����ʾ
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

--[[#DEBUG BEGIN]]X.ReportModuleLoading(MODULE_PATH, 'FINISH')--[[#DEBUG END]]