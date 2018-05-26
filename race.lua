 uv = require('luv')

 step = 10

 hare_id = uv.new_thread(function(step,...)
    ffi = require'ffi'
    uv = require('luv')
    local argv = {...}
    local sleep
    if ffi.os=='Windows' then
        ffi.cdef "void Sleep(int ms);"
        sleep = ffi.C.Sleep
    else
        ffi.cdef "unsigned int usleep(unsigned int milliseconds);"
        sleep = ffi.C.usleep
    end
    while (step>0) do
        step = step - 1
        sleep(math.random(100000))
        print("Hare ran another step", unpack(argv))
    end
    print("Hare done running!")
end, step,true,'abcd','false')

tortoise_id = uv.new_thread(function(step,...)
     uv = require('luv')
    while (step>0) do
        step = step - 1
        uv.sleep(math.random(100))
        print("Tortoise ran another step")
    end
    print("Tortoise done running!")
end,step,'abcd','false')

print(hare_id==hare_id,uv.thread_equal(hare_id,hare_id))
print(tortoise_id==hare_id,uv.thread_equal(tortoise_id,hare_id))

--uv.thread_join(hare_id)
--uv.thread_join(tortoise_id)