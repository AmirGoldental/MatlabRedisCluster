function flush_db()
redis_connection = mrr.RedisConnection();
redis_connection.cmd('FLUSHALL');
end

