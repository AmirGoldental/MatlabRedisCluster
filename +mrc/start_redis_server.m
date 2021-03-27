function start_redis_server()
system(['start "redis_server" /D "' fileparts(fileparts(mfilename('fullpath'))) '" cmd /c start_redis_server.bat']);
end

