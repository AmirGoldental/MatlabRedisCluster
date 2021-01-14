function flush_db()
redis_connection = mrr.RedisConnection(fullfile(fileparts(mfilename('fullpath')),'..'));
redis_connection.cmd('FLUSHALL');
end

