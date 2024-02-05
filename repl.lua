local fennel = require("fennel")
local compiler = require("fennel.compiler")
local luvi = require("luvi")
local uv = require("uv")
local stdin = process.stdin.handle
local stdout = process.stdout.handle

fennel.install()

-- starts reading input
local cr = coroutine.running()
local prompt = ">> "

stdout:write(prompt)
stdin:read_start(function (err, data)
   assert(not err, err)
   if data then
      if data:match("^,complete%s+;.*") or not data:match("%S") then
	 coroutine.resume(cr, "(print)\n")
      else
	 coroutine.resume(cr, data .. "\n")
      end

      stdout:write(prompt)
   else
      stdin:close()
   end
end)

-- debug.traceback = fennel.traceback
-- it makes the bot crash for some reason

-- initializes the repl
local req, mod = require("require")(luvi.path.join(uv.cwd(), "repl"))
local prev_G = _G

local env = {}
env.require = req
env.module = mod
env._G = env
setmetatable(env, {
   __index = function(_, k)
      return k == "thread" and coroutine.running() or prev_G[k]
   end
})

for _, name in ipairs({
   'buffer', 'childprocess', 'codec', 'core',
   'dgram', 'dns', 'fs', 'helpful', 'hooks', 'http-codec', 'http',
   'https', 'json', 'los', 'net', 'pretty-print',
   'querystring', 'readline', 'timer', 'url', 'utils',
   'stream', 'tls', 'path', 'uv', 'luvi'
}) do
   env[name] = req(name)
end

fennel.repl {
   readChunk = function()
      cr = coroutine.running()
      return coroutine.yield()
   end,
   onValues = function(values)
      stdout:write(table.concat(values, "\t"))
      stdout:write("\n")
   end,
   onError = function(errtype, err, source)
      if errtype == "Lua Compile" then
	 stdout:write("Bad code generated - likely a bug with the compiler\
--- Generated Lua Start ---\n" .. source .. " --- Generated Lua End ---\n")
      elseif errtype == "Runtime" then
	 stdout:write(compiler.traceback(tostring(err), 4) .. "\n")
      else
	 stdout:write(errtype .. " error: " .. err .. "\n")
      end
   end,
   env = env,
   allowedGlobals = (function()
      local allowed = {"thread"}
      for k in pairs(env) do
	 table.insert(allowed, k)
      end
      for k in pairs(prev_G) do
	 table.insert(allowed, k)
      end
      return allowed
   end)()
}
