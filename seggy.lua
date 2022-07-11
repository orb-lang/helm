local ModeS = {}

ModeS.__index = ModeS

local create, resume = coroutine.create, coroutine.resume

local function dotask(actor, task, ...)
   local msg_ret = pack(actor, ...)
   local ok, co, msg;
   local task_t = type(task)
   if task_t == 'function' then
      co = create(task)
   elseif task_t == 'string' then
      co = create(assert(actor[task], "missing method"))
   else
      error("bad task of type " .. task_t)
   end
   while true do
      ok, msg = resume(co, unpack(msg_ret))
      if not ok then
         error(msg .. "\nIn co:\n" .. debug.traceback(co))
      elseif status(co) == 'dead' then
         -- End of body function, pass through the return value
         return msg
      end
      msg_ret = actor:delegate(msg)
   end
end

function ModeS.task(modeS)
   local function __idx(_, key)
      return function(_modeS, ...)
         return dotask(_modeS, key, ...)
      end
   end
   return setmetatable({}, {__index = __idx})
end

function ModeS.delegator(modeS, msg)
   if msg.sendto and msg.sendto:find("^agents%.") then
      return modeS.maestro(msg)
   else
      return pack(dispatchmessage(modeS, msg))
   end
end

function ModeS.delegate(modeS, msg)
   --return dotask(modeS, 'delegator', msg)
   return modeS :task() :delegator(msg)
end
