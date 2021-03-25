function start_redis_server()
system(['start "redis_server" /D "' fileparts(fileparts(mfilename('fullpath'))) '" start_redis_server.bat']);
end

