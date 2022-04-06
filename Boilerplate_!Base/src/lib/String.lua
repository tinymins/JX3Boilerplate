--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 字符串处理
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
local AnsiToUTF8 = AnsiToUTF8 or _G.ansi_to_utf8
--------------------------------------------
-- 本地函数和变量
--------------------------------------------

-- 分隔字符串
-- (table) X.SplitString(string szText, table aSpliter, bool bIgnoreEmptyPart)
-- (table) X.SplitString(string szText, string szSpliter, bool bIgnoreEmptyPart)
-- szText           原始字符串
-- szSpliter        分隔符
-- aSpliter         多个分隔符
-- bIgnoreEmptyPart 是否忽略空字符串，即'123;234;'被';'分成{'123','234'}还是{'123','234',''}
-- nMaxPart         最多分成几份，即'1;2;3;4'被';'分隔时，如果最多三份则得到{'1','2','3;4'}
function X.SplitString(szText, aSpliter, bIgnoreEmptyPart, nMaxPart)
	if X.IsString(aSpliter) then
		aSpliter = {aSpliter}
	end
	local nOff, nLen, aResult, nResult, szPart, nEnd, szEnd, nPos = 1, #szText, {}, 0, nil, nil, nil, nil
	while true do
		nEnd, szEnd = nil, nil
		if not nMaxPart or nMaxPart > nResult + 1 then
			for _, szSpliter in ipairs(aSpliter) do
				if szSpliter == '' then
					nPos = #wstring.sub(string.sub(szText, nOff), 1, 1)
					if nPos == 0 then
						nPos = nil
					else
						nPos = nOff + nPos
					end
				else
					nPos = StringFindW(szText, szSpliter, nOff)
				end
				if nPos and (not nEnd or nPos < nEnd) then
					nEnd, szEnd = nPos, szSpliter
				end
			end
		end
		if not nEnd then
			szPart = string.sub(szText, nOff, string.len(szText))
			if not bIgnoreEmptyPart or szPart ~= '' then
				nResult = nResult + 1
				table.insert(aResult, szPart)
			end
			break
		end
		szPart = string.sub(szText, nOff, nEnd - 1)
		if not bIgnoreEmptyPart or szPart ~= '' then
			nResult = nResult + 1
			table.insert(aResult, szPart)
		end
		nOff = nEnd + string.len(szEnd)
		if nOff > nLen then
			break
		end
	end
	return aResult
end

function X.EscapeString(s)
	return (string.gsub(s, '([%(%)%.%%%+%-%*%?%[%^%$%]])', '%%%1'))
end

function X.TrimString(szText)
	if not szText or szText == '' then
		return ''
	end
	return (string.gsub(szText, '^%s*(.-)%s*$', '%1'))
end

function X.EncryptString(szText)
	return (szText:gsub('.', function (c) return string.format('%02X', (string.byte(c) + 13) % 256) end):gsub(' ', '+'))
end

function X.DecryptString(szText)
	local a, n = {}, nil
	for i = 1, #szText, 2 do
		n = tonumber('0x' .. szText:sub(i, i + 1))
		if not n then
			return
		end
		a[(i + 1) / 2] = string.char((n - 13 + 256) % 256)
	end
	return table.concat(a)
end

function X.SimpleEncryptString(szText)
	local a = {}
	for i = 1, #szText do
		a[i] = string.char((szText:byte(i) + 13) % 256)
	end
	return (X.Base64Encode(table.concat(a)):gsub('/', '-'):gsub('+', '_'):gsub('=', '.'))
end

function X.SimpleDecryptString(szCipher)
	local szBin = X.Base64Decode((szCipher:gsub('-', '/'):gsub('_', '+'):gsub('%.', '=')))
	if not szBin then
		return
	end
	local a = {}
	for i = 1, #szBin do
		a[i] = string.char((szBin:byte(i) - 13 + 256) % 256)
	end
	return table.concat(a)
end

function X.SimpleDecodeString(szCipher, bTripSlashes)
	local aPhrase = {'v', 'u', 'S', 'r', 'q', '9', 'O', 'b'}
	local nPhrase = #aPhrase
	for i, v in ipairs(aPhrase) do
		aPhrase[i] = v:byte()
	end

	local aText, ch1, ch2 = {}, nil, nil
	for i = 1, #szCipher, 2 do
		ch1 = szCipher:byte(i) - 65;
		ch2 = szCipher:byte(i + 1) - 65;
		ch1 = X.NumberBitOr(X.NumberBitShl(ch1, 4, 64), ch2)
		aText[(i + 1) / 2] = string.char(X.NumberBitXor(ch1, aPhrase[(((i + 1) / 2) - 1) % nPhrase + 1]))
	end
	return table.concat(aText)
end

function X.KGUIEncrypt(szText)
	if EncodeData then
		szText = EncodeData(X.EncryptString(szText)) or szText
	end
	if KGUIEncrypt then
		szText = KGUIEncrypt(X.EncryptString(szText)) or szText
	end
	return MD5 and MD5(X.EncryptString(szText)) or X.EncryptString(szText)
end

-- 编码 URL 中的参数：方法不会对下列字符编码 [a-zA-Z0-9~!*()']
-- @param {any} data 需要编码的数据
-- @return {typeof data} 编码后的数据
local function EncodeURIComponent(data)
	if type(data) == 'string' then
		return (data:gsub('([^0-9a-zA-Z ])', function (c) return string.format('%%%02X', string.byte(c)) end):gsub(' ', '+'))
	end
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			t[EncodeURIComponent(k)] = EncodeURIComponent(v)
		end
		return t
	end
	return data
end
X.EncodeURIComponent = EncodeURIComponent

-- 解码 URL 中的参数
-- @param {any} data 需要解码的数据
-- @return {typeof data} 解码后的数据
local function DecodeURIComponent(data)
	if type(data) == 'string' then
		return (data:gsub('+', ' '):gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end))
	end
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			t[DecodeURIComponent(k)] = DecodeURIComponent(v)
		end
		return t
	end
	return data
end
X.DecodeURIComponent = DecodeURIComponent

local function EncodeQuerystring(t, prefix, data)
	if type(data) == 'table' then
		local first = true
		for k, v in pairs(data) do
			if first then
				first = false
			else
				table.insert(t, '&')
			end
			k = EncodeURIComponent(tostring(k))
			if prefix == '' then
				EncodeQuerystring(t, k, v)
			else
				EncodeQuerystring(t, prefix .. '[' .. k .. ']', v)
			end
		end
	else
		if prefix ~= '' then
			table.insert(t, prefix)
			table.insert(t, '=')
		end
		table.insert(t, EncodeURIComponent(tostring(data)))
	end
	return t
end

-- 将 POST 数据键值对转换为 application/x-www-form-urlencoded 主体数据字符串
-- @param {table} data POST 数据键值对
-- @return {string} 主体数据字符串
function X.EncodeQuerystring(data)
	return table.concat(EncodeQuerystring({}, '', data))
end

-- 将 application/x-www-form-urlencoded 主体数据字符串转换为 POST 数据键值对
-- @param {string} 主体数据字符串
-- @return {table} data POST 数据键值对
function X.DecodeQuerystring(s)
	local data = {}
	for _, kvp in ipairs(X.SplitString(s, '&', true)) do
		kvp = X.SplitString(kvp, '=')
		local k, v = kvp[1], kvp[2]
		local pos = wstring.find(k, '[')
		if pos then
			local ks = { DecodeURIComponent(string.sub(k, 1, pos - 1)) }
			k = string.sub(k, pos)
			while wstring.sub(k, 1, 1) == '[' do
				pos = wstring.find(k, ']') or (string.len(k) + 1)
				table.insert(ks, DecodeURIComponent(string.sub(k, 2, pos - 1)))
				k = string.sub(k, pos + 1)
			end
			X.Set(data, ks, DecodeURIComponent(v))
		else
			data[DecodeURIComponent(k)] = DecodeURIComponent(v)
		end
	end
	return data
end

local function ConvertToUTF8(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == 'string' then
				t[ConvertToUTF8(k)] = ConvertToUTF8(v)
			else
				t[k] = ConvertToUTF8(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return AnsiToUTF8(data)
	else
		return data
	end
end
X.ConvertToUTF8 = ConvertToUTF8

local function ConvertToAnsi(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == 'string' then
				t[ConvertToAnsi(k)] = ConvertToAnsi(v)
			else
				t[k] = ConvertToAnsi(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return UTF8ToAnsi(data)
	else
		return data
	end
end
X.ConvertToAnsi = ConvertToAnsi

local m_simpleMatchCache = setmetatable({}, { __mode = 'v' })
function X.StringSimpleMatch(szText, szFind, bDistinctCase, bDistinctEnEm, bIgnoreSpace)
	if not bDistinctCase then
		szFind = StringLowerW(szFind)
		szText = StringLowerW(szText)
	end
	if not bDistinctEnEm then
		szText = StringEnerW(szText)
	end
	if bIgnoreSpace then
		szFind = wstring.gsub(szFind, ' ', '')
		szFind = wstring.gsub(szFind, g_tStrings.STR_ONE_CHINESE_SPACE, '')
		szText = wstring.gsub(szText, ' ', '')
		szText = wstring.gsub(szText, g_tStrings.STR_ONE_CHINESE_SPACE, '')
	end
	local me = GetClientPlayer()
	if me then
		szFind = szFind:gsub('$zj', me.szName)
		local szTongName = ''
		local tong = GetTongClient()
		if tong and me.dwTongID ~= 0 then
			szTongName = tong.ApplyGetTongName(me.dwTongID) or ''
		end
		szFind = szFind:gsub('$bh', szTongName)
		szFind = szFind:gsub('$gh', szTongName)
	end
	local tFind = m_simpleMatchCache[szFind]
	if not tFind then
		tFind = {}
		for _, szKeywordsLine in ipairs(X.SplitString(szFind, ';', true)) do
			local tKeyWordsLine = {}
			for _, szKeywords in ipairs(X.SplitString(szKeywordsLine, ',', true)) do
				local tKeyWords = {}
				for _, szKeyword in ipairs(X.SplitString(szKeywords, '|', true)) do
					local bNegative = szKeyword:sub(1, 1) == '!'
					if bNegative then
						szKeyword = szKeyword:sub(2)
					end
					if not bDistinctEnEm then
						szKeyword = StringEnerW(szKeyword)
					end
					table.insert(tKeyWords, { szKeyword = szKeyword, bNegative = bNegative })
				end
				table.insert(tKeyWordsLine, tKeyWords)
			end
			table.insert(tFind, tKeyWordsLine)
		end
		m_simpleMatchCache[szFind] = tFind
	end
	-- 10|十人,血战天策|XZTC,!小铁被吃了,!开宴黑铁;大战
	local bKeyWordsLine = false
	for _, tKeyWordsLine in ipairs(tFind) do         -- 符合一个即可
		-- 10|十人,血战天策|XZTC,!小铁被吃了,!开宴黑铁
		local bKeyWords = true
		for _, tKeyWords in ipairs(tKeyWordsLine) do -- 必须全部符合
			-- 10|十人
			local bKeyWord = false
			for _, info in ipairs(tKeyWords) do      -- 符合一个即可
				-- szKeyword = X.EscapeString(szKeyword) -- 用了wstring还Escape个捷豹
				if info.bNegative then               -- !小铁被吃了
					if not wstring.find(szText, info.szKeyword) then
						bKeyWord = true
					end
				else                                                    -- 十人   -- 10
					if wstring.find(szText, info.szKeyword) then
						bKeyWord = true
					end
				end
				if bKeyWord then
					break
				end
			end
			bKeyWords = bKeyWords and bKeyWord
			if not bKeyWords then
				break
			end
		end
		bKeyWordsLine = bKeyWordsLine or bKeyWords
		if bKeyWordsLine then
			break
		end
	end
	return bKeyWordsLine
end

function X.IsSensitiveWord(szText)
	if not _G.TextFilterCheck then
		return false
	end
	return not _G.TextFilterCheck(szText)
end

function X.ReplaceSensitiveWord(szText)
	if not _G.TextFilterReplace then
		return szText
	end
	local bResult, szResult = _G.TextFilterReplace(szText)
	if not bResult then
		return szText
	end
	return szResult
end

do
local CACHE = setmetatable({}, { __mode = 'v' })
function X.GetFormatText(...)
	local szKey = X.EncodeLUAData({...})
	if not CACHE[szKey] then
		CACHE[szKey] = {GetFormatText(...)}
	end
	return CACHE[szKey][1]
end
end

do
local CACHE = setmetatable({}, { __mode = 'v' })
function X.GetPureText(szXml, szDriver)
	if not szDriver then
		szDriver = 'AUTO'
	end
	local cache = CACHE[szXml]
	if not cache then
		cache = {}
		CACHE[szXml] = cache
	end
	if X.IsNil(cache.c) and (szDriver == 'CPP' or szDriver == 'AUTO') then
		cache.c = GetPureText
			and GetPureText(szXml)
			or false
	end
	if X.IsNil(cache.l) and (szDriver == 'LUA' or (szDriver == 'AUTO' and not cache.c)) then
		local aXMLNode = X.XMLDecode(szXml)
		cache.l = X.XMLGetPureText(aXMLNode) or false
	end
	if szDriver == 'CPP' then
		return cache.c
	end
	if szDriver == 'LUA' then
		return cache.l
	end
	return cache.c or cache.l
end
end
