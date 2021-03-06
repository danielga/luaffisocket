if jit ~= nil then
	local type, error, pcall, select = type, error, pcall, select

	local function status_handler(status, ...)
		if status then
			return ...
		end

		local err = (...)
		if type(err) ~= "table" then
			error(err)
		end

		return nil, err[1]
	end

	function protect(func)
		return function(...)
			return status_handler(pcall(func, ...))
		end
	end

	function newtry(finalizer)
		return function(...)
			local status = (...)
			if not status then
				pcall(finalizer, select(2, ...))
				error({select(2, ...)}, 0)
			end

			return ...
		end
	end
end

-------------------------------------------------------------------------------
-- Coroutine safe xpcall and pcall versions
--
-- Encapsulates the protected calls with a coroutine based loop, so errors can
-- be dealed without the usual Lua 5.x pcall/xpcall issues with coroutines
-- yielding inside the call to pcall or xpcall.
--
-- Authors: Roberto Ierusalimschy and Andre Carregal
-- Contributors: Thomas Harning Jr., Ignacio Burgueño, Fabio Mascarenhas
--
-- Copyright 2005 - Kepler Project (www.keplerproject.org)
--
-- $Id: coxpcall.lua,v 1.13 2008/05/19 19:20:02 mascarenhas Exp $
-------------------------------------------------------------------------------

-- Lua 5.2 makes this module a no-op
if _VERSION ~= "Lua 5.1" then
	copcall = pcall
	coxpcall = xpcall
	return {pcall = pcall, xpcall = xpcall, running = coroutine.running}
end

-------------------------------------------------------------------------------
-- Implements xpcall with coroutines
-------------------------------------------------------------------------------
local performResume, handleReturnValue
local oldpcall = pcall
local pack = table.pack or function(...) return {n = select("#", ...), ...} end
local unpack = table.unpack or unpack
local running = coroutine.running
local coromap = setmetatable({}, { __mode = "k" })

function handleReturnValue(err, co, status, ...)
	if not status then
		return false, err(debug.traceback(co, (...)), ...)
	end

	if coroutine.status(co) == 'suspended' then
		return performResume(err, co, coroutine.yield(...))
	else
		return true, ...
	end
end

function performResume(err, co, ...)
	return handleReturnValue(err, co, coroutine.resume(co, ...))
end

function coxpcall(f, err, ...)
	local res, co = oldpcall(coroutine.create, f)
	if not res then
		local params = pack(...)
		local newf = function() return f(unpack(params, 1, params.n)) end
		co = coroutine.create(newf)
	end

	coromap[co] = (running() or "mainthread")
	return performResume(err, co, ...)
end

local function corunning(coro)
	if coro ~= nil then
		assert(type(coro) == "thread", "Bad argument; expected thread, got: " .. type(coro))
	else
		coro = running()
	end

	while coromap[coro] do
		coro = coromap[coro]
	end

	return coro ~= "mainthread" and coro or nil
end

-------------------------------------------------------------------------------
-- Implements pcall with coroutines
-------------------------------------------------------------------------------

local function id(trace, ...)
	return ...
end

function copcall(f, ...)
	return coxpcall(f, id, ...)
end

return {pcall = copcall, xpcall = coxpcall, running = corunning}
