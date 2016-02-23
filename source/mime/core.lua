local core = {}

--[[=======================================================================*\
* Don"t want to trust escape character constants
\*=========================================================================]]
local CRLF = "\r\n"
local EQCRLF = "=\r\n"

--[[=======================================================================*\
* Global Lua functions
\*=========================================================================]]
--[[-----------------------------------------------------------------------*\
* Incrementaly breaks a string into lines. The string can have CRLF breaks.
* A, n = wrp(l, B, length)
* A is a copy of B, broken into lines of at most "length" bytes.
* "l" is how many bytes are left for the first line of B.
* "n" is the number of bytes left in the last line of A.
\*-------------------------------------------------------------------------]]
function core.wrp(left, input, length)
	-- end of input black-hole
	if input == nil then
		return left < length and CRLF or nil, length
	end

	length = length or 76
	local buffer = ""
	for i = 1, #input do
		local c = string.sub(input, i, i)
		if c == "\r" then
		elseif c == "\n" then
			buffer = buffer .. CRLF
			left = length
		else
			if left <= 0 then
				left = length
				buffer = buffer .. CRLF
			end

			buffer = buffer .. c
			left = left - 1
		end
	end

	return buffer, left
end

--[[-----------------------------------------------------------------------*\
* Base64 globals
\*-------------------------------------------------------------------------]]
local b64base = {
	[0] = "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
}
local b64unbase = {}

--[[-----------------------------------------------------------------------*\
* Fill base64 decode map.
\*-------------------------------------------------------------------------]]
do
	for i = 0, 255 do
		b64unbase[string.char(i)] = 255
	end

	for i = 0, 63 do
		b64unbase[b64base[i]] = i
	end

	b64unbase["="] = 0
end

--[[-----------------------------------------------------------------------*\
* Acumulates bytes in input buffer until 3 bytes are available.
* Translate the 3 bytes into Base64 form and append to buffer.
* Returns new number of bytes in buffer.
\*-------------------------------------------------------------------------]]
local function b64encode(c, input, size, buffer)
	input[size] = c
	size = size + 1
	if size == 3 then
		local value = string.byte(input[0])
		value = bit.lshift(value, 8)
		value = value + string.byte(input[1])
		value = bit.lshift(value, 8)
		value = value + string.byte(input[2])

		local code = {}
		code[3] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[2] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[1] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[0] = b64base[value]

		buffer = buffer .. table.concat(code, "", 0, 3)
		size = 0
	end

	return size, buffer
end

--[[-----------------------------------------------------------------------*\
* Encodes the Base64 last 1 or 2 bytes and adds padding "="
* Result, if any, is appended to buffer.
* Returns 0.
\*-------------------------------------------------------------------------]]
local function b64pad(input, size, buffer)
	local code = {"=", "=", "=", "="}
	if size == 1 then
		local value = bit.lshift(string.byte(input[0]), 4)
		code[1] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[0] = b64base[value]

		buffer = buffer .. table.concat(code, "", 0, 3)
	elseif size == 2 then
		local value = string.byte(input[0])
		value = bit.lshift(value, 8)
		value = bit.bor(value, string.byte(input[1]))
		value = bit.lshift(value, 2)

		code[2] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[1] = b64base[bit.band(value, 0x3f)]
		value = bit.rshift(value, 6)
		code[0] = b64base[value]

		buffer = buffer .. table.concat(code, "", 0, 3)
	end

	return 0, buffer
end

--[[-----------------------------------------------------------------------*\
* Acumulates bytes in input buffer until 4 bytes are available.
* Translate the 4 bytes from Base64 form and append to buffer.
* Returns new number of bytes in buffer.
\*-------------------------------------------------------------------------]]
local function b64decode(c, input, size, buffer)
	-- ignore invalid characters
	if b64unbase[c] > 64 then
		return size, buffer
	end

	input[size] = c
	size = size + 1
	-- decode atom
	if size == 4 then
		local value =  b64unbase[input[0]]
		value = bit.lshift(value, 6)
		value = bit.bor(value, b64unbase[input[1]])
		value = bit.lshift(value, 6)
		value = bit.bor(value, b64unbase[input[2]])
		value = bit.lshift(value, 6)
		value = bit.bor(value, b64unbase[input[3]])

		local decoded = {}
		decoded[2] = string.char(bit.band(value, 0xff))
		value = bit.rshift(value, 8)
		decoded[1] = string.char(bit.band(value, 0xff))
		value = bit.rshift(value, 8)
		decoded[0] = string.char(value)

		-- take care of paddding
		return 0, buffer .. table.concat(decoded, "", 0, input[2] == "=" and 0 or (input[3] == "=" and 1 or 2))
	end

	-- need more data
	return size, buffer
end

--[[-----------------------------------------------------------------------*\
* Incrementally applies the Base64 transfer content encoding to a string
* A, B = b64(C, D)
* A is the encoded version of the largest prefix of C .. D that is
* divisible by 3. B has the remaining bytes of C .. D, *without* encoding.
* The easiest thing would be to concatenate the two strings and
* encode the result, but we can"t afford that or Lua would dupplicate
* every chunk we received.
\*-------------------------------------------------------------------------]]
function core.b64(input, input2)
	-- end-of-input blackhole
	if input == nil then
		return
	end

	local asize = 0
	local atom = {}
	local buffer = ""
	-- process first part of the input
	for i = 1, #input do
		asize, buffer = b64encode(string.sub(input, i, i), atom, asize, buffer)
	end

	-- if second part is nil, we are done
	if input2 == nil then
		asize, buffer = b64pad(atom, asize, buffer)
		return #buffer ~= 0 and buffer or nil, nil
	end

	-- otherwise process the second part
	for i = 1, #input2 do
		asize, buffer = b64encode(string.sub(input2, i, i), atom, asize, buffer)
	end

	return buffer, asize ~= 0 and table.concat(atom, "", 0, asize - 1) or ""
end

--[[-----------------------------------------------------------------------*\
* Incrementally removes the Base64 transfer content encoding from a string
* A, B = b64(C, D)
* A is the encoded version of the largest prefix of C .. D that is
* divisible by 4. B has the remaining bytes of C .. D, *without* encoding.
\*-------------------------------------------------------------------------]]
function core.unb64(input, input2)
	-- end-of-input blackhole
	if input == nil then
		return
	end

	local asize = 0
	local atom = {}
	local buffer = ""
	-- process first part of the input
	for i = 1, #input do
		asize, buffer = b64decode(string.sub(input, i, i), atom, asize, buffer)
	end

	-- if second is nil, we are done
	if input2 == nil then
		return #buffer ~= 0 and buffer or nil, nil
	end

	-- otherwise, process the rest of the input
	for i = 1, #input2 do
		asize, buffer = b64decode(string.sub(input2, i, i), atom, asize, buffer)
	end

	return buffer, asize ~= 0 and table.concat(atom, "", 0, asize - 1) or ""
end

--[[-----------------------------------------------------------------------*\
* Quoted-printable encoding scheme
* all (except CRLF in text) can be =XX
* CLRL in not text must be =XX=XX
* 33 through 60 inclusive can be plain
* 62 through 126 inclusive can be plain
* 9 and 32 can be plain, unless in the end of a line, where must be =XX
* encoded lines must be no longer than 76 not counting CRLF
* soft line-break are =CRLF
* To encode one byte, we need to see the next two.
* Worst case is when we see a space, and wonder if a CRLF is comming
\*-------------------------------------------------------------------------]]

--[[-----------------------------------------------------------------------*\
* Quoted-printable globals
\*-------------------------------------------------------------------------]]
local qpclass = {}
local qpbase = {
	[0] = "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"A", "B", "C", "D", "E", "F"
}
local qpunbase = {}
local QP_PLAIN, QP_QUOTED, QP_CR, QP_IF_LAST = 0, 1, 2, 3

--[[-----------------------------------------------------------------------*\
* Split quoted-printable characters into classes
* Precompute reverse map for encoding
\*-------------------------------------------------------------------------]]
do
	for i = 0, 255 do
		qpclass[string.char(i)] = QP_QUOTED
	end

	for i = 33, 60 do
		qpclass[string.char(i)] = QP_PLAIN
	end

	for i = 62, 126 do
		qpclass[string.char(i)] = QP_PLAIN
	end

	qpclass["\t"] = QP_IF_LAST
	qpclass[" "] = QP_IF_LAST
	qpclass["\r"] = QP_CR

	for i = 0, 255 do
		qpunbase[string.char(i)] = 255
	end

	qpunbase["0"] = 0
	qpunbase["1"] = 1
	qpunbase["2"] = 2
	qpunbase["3"] = 3
	qpunbase["4"] = 4
	qpunbase["5"] = 5
	qpunbase["6"] = 6
	qpunbase["7"] = 7
	qpunbase["8"] = 8
	qpunbase["9"] = 9
	qpunbase["A"] = 10
	qpunbase["a"] = 10
	qpunbase["B"] = 11
	qpunbase["b"] = 11
	qpunbase["C"] = 12
	qpunbase["c"] = 12
	qpunbase["D"] = 13
	qpunbase["d"] = 13
	qpunbase["E"] = 14
	qpunbase["e"] = 14
	qpunbase["F"] = 15
	qpunbase["f"] = 15
end

--[[-----------------------------------------------------------------------*\
* Output one character in form =XX
\*-------------------------------------------------------------------------]]
local function qpquote(c, buffer)
	c = string.byte(c)
	return buffer .. "=" .. qpbase[bit.rshift(c, 4)] .. qpbase[bit.band(c, 0x0F)]
end

--[[-----------------------------------------------------------------------*\
* Accumulate characters until we are sure about how to deal with them.
* Once we are sure, output to the buffer, in the correct form.
\*-------------------------------------------------------------------------]]
local function qpencode(c, input, size, marker, buffer)
	input[size] = c
	size = size + 1
	-- deal with all characters we can have
	while size > 0 do
		-- might be the CR of a CRLF sequence
		if qpclass[input[0]] == QP_CR then
			if size < 2 then
				return size, buffer
			end

			if input[1] == "\n" then
				return 0, buffer .. marker
			else
				buffer = qpquote(input[0], buffer)
			end
		-- might be a space and that has to be quoted if last in line
		elseif qpclass[input[0]] == QP_IF_LAST then
			if size < 3 then
				return size, buffer
			end

			-- if it is the last, quote it and we are done
			if input[1] == "\r" and input[2] == "\n" then
				return 0, qpquote(input[0], buffer) .. marker
			else
				buffer = buffer .. input[0]
			end
		-- might have to be quoted always
		elseif qpclass[input[0]] == QP_QUOTED then
			buffer = qpquote(input[0], buffer)
		-- might never have to be quoted
		else
			buffer = buffer .. input[0]
		end

		input[0] = input[1]
		input[1] = input[2]
		size = size - 1
	end

	return 0, buffer
end

--[[-----------------------------------------------------------------------*\
* Deal with the final characters
\*-------------------------------------------------------------------------]]
local function qppad(input, size, buffer)
	for i = 0, size - 1 do
		if qpclass[input[i]] == QP_PLAIN then
			buffer = buffer .. input[i]
		else
			buffer = qpquote(input[i], buffer)
		end
	end

	return 0, size > 0 and (buffer .. EQCRLF) or buffer
end

--[[-----------------------------------------------------------------------*\
* Incrementally converts a string to quoted-printable
* A, B = qp(C, D, marker)
* Marker is the text to be used to replace CRLF sequences found in A.
* A is the encoded version of the largest prefix of C .. D that
* can be encoded without doubts.
* B has the remaining bytes of C .. D, *without* encoding.
\*-------------------------------------------------------------------------]]
function core.qp(input, input2, marker)
	-- end-of-input blackhole
	if input == nil then
		return
	end

	marker = marker or CRLF
	local asize = 0
	local atom = {}
	local buffer = ""
	-- process first part of input
	for i = 1, #input do
		asize, buffer = qpencode(string.sub(input, i, i), atom, asize, marker, buffer)
	end

	-- if second part is nil, we are done
	if input2 == nil then
		asize, buffer = qppad(atom, asize, buffer)
		return #buffer ~= 0 and buffer or nil
	end

	-- otherwise process rest of input
	for i = 1, #input2 do
		asize, buffer = qpencode(string.sub(input2, i, i), atom, asize, marker, buffer)
	end

	return buffer, asize ~= 0 and table.concat(atom, "", 0, asize - 1) or ""
end

--[[-----------------------------------------------------------------------*\
* Accumulate characters until we are sure about how to deal with them.
* Once we are sure, output the to the buffer, in the correct form.
\*-------------------------------------------------------------------------]]
local function qpdecode(c, input, size, buffer)
	input[size] = c
	size = size + 1
	-- deal with all characters we can deal
	-- if we have an escape character
	if input[0] == "=" then
		if size < 3 then
			return size, buffer
		end

		-- eliminate soft line break
		if input[1] == "\r" and input[2] == "\n" then
			return 0, buffer
		end

		-- decode quoted representation
		c = qpunbase[input[1]]
		local d = qpunbase[input[2]]

		-- if it is an invalid, do not decode
		return 0, (c > 15 or d > 15) and (buffer .. table.concat(input, "", 0, 2)) or (buffer .. string.char(bit.lshift(c, 4) + d))
	elseif input[0] == "\r" then
		if size < 2 then
			return size, buffer
		end

		return 0, input[1] == "\n" and (buffer .. table.concat(input, "", 0, 1)) or buffer
	end

	return 0, (input[0] == "\t" or (input[0] >= " " and input[0] <= "~")) and (buffer .. input[0]) or buffer
end

--[[-----------------------------------------------------------------------*\
* Incrementally decodes a string in quoted-printable
* A, B = qp(C, D)
* A is the decoded version of the largest prefix of C .. D that
* can be decoded without doubts.
* B has the remaining bytes of C .. D, *without* decoding.
\*-------------------------------------------------------------------------]]
function core.unqp(input, input2)
	-- end-of-input blackhole
	if input == nil then
		return
	end

	local asize = 0
	local atom = {}
	local buffer = ""
	-- process first part of input
	for i = 1, #input do
		asize, buffer = qpdecode(string.sub(input, i, i), atom, asize, buffer)
	end

	-- if second part is nil, we are done
	if input2 == nil then
		return #buffer ~= 0 and buffer or nil
	end

	-- otherwise process rest of input
	for i = 1, #input2 do
		asize, buffer = qpdecode(string.sub(input2, i, i), atom, asize, buffer)
	end

	return buffer, asize ~= 0 and table.concat(atom, "", 0, asize - 1) or ""
end

--[[-----------------------------------------------------------------------*\
* Incrementally breaks a quoted-printed string into lines
* A, n = qpwrp(l, B, length)
* A is a copy of B, broken into lines of at most "length" bytes.
* "l" is how many bytes are left for the first line of B.
* "n" is the number of bytes left in the last line of A.
* There are two complications: lines can't be broken in the middle
* of an encoded =XX, and there might be line breaks already
\*-------------------------------------------------------------------------]]
function core.qpwrp(left, input, length)
	-- end-of-input blackhole
	if input == nil then
		return left < length and EQCRLF or nil, length
	end

	length = length or 76
	local buffer = ""
	-- process all input
	for i = 1, #input do
		local c = string.sub(input, i, i)
		if c == "\r" then
		elseif c == "\n" then
			left = length
			buffer = buffer .. CRLF
		elseif c == "=" then
			if left <= 3 then
				left = length
				buffer = buffer .. EQCRLF
			end

			buffer = buffer .. c
			left = left - 1
		else
			if left <= 1 then
				left = length
				buffer = buffer .. EQCRLF
			end

			buffer = buffer .. c
			left = left - 1
		end
	end

	return buffer, left
end

--[[-----------------------------------------------------------------------*\
* Here is what we do: \n, and \r are considered candidates for line
* break. We issue *one* new line marker if any of them is seen alone, or
* followed by a different one. That is, \n\n and \r\r will issue two
* end of line markers each, but \r\n, \n\r etc will only issue *one*
* marker.  This covers Mac OS, Mac OS X, VMS, Unix and DOS, as well as
* probably other more obscure conventions.
*
* c is the current character being processed
* last is the previous character
\*-------------------------------------------------------------------------]]
local function eolprocess(c, last, marker, buffer)
	if c == "\r" or c == "\n" then
		if last == "\r" or last == "\n" then
			return 0, c == last and (buffer .. marker) or buffer
		else
			return c, buffer .. marker
		end
	else
		return 0, buffer .. c
	end
end

--[[-----------------------------------------------------------------------*\
* Converts a string to uniform EOL convention.
* A, n = eol(o, B, marker)
* A is the converted version of the largest prefix of B that can be
* converted unambiguously. "o" is the context returned by the previous
* call. "n" is the new context.
\*-------------------------------------------------------------------------]]
function core.eol(ctx, input, marker)
	-- end of input blackhole
	if input == nil then
		return nil, 0
	end

	marker = marker or CRLF
	local buffer = ""
	-- process all input
	for i = 1, #input do
		ctx, buffer = eolprocess(string.sub(input, i, i), ctx, marker, buffer)
	end

	return buffer, ctx
end

--[[-----------------------------------------------------------------------*\
* Takes one byte and stuff it if needed.
\*-------------------------------------------------------------------------]]
local function dot(c, state, buffer)
	buffer = buffer .. c
	if c == "\r" then
		return 1, buffer
	elseif c == "\n" then
		return state == 1 and 2 or 0, buffer
	elseif c == "." then
		if state == 2 then
			buffer = buffer .. "."
		end
	end

	return 0, buffer
end

--[[-----------------------------------------------------------------------*\
* Incrementally applies smtp stuffing to a string
* A, n = dot(l, D)
\*-------------------------------------------------------------------------]]
function core.dot(state, input)
	-- end-of-input blackhole
	if input == nil then
		return nil, 2
	end

	local buffer = ""
	-- process all input
	for i = 1, #input do
		state, buffer = dot(string.sub(input, i, i), state, buffer)
	end

	return buffer, state
end

return core
