function flush_db()
get_redis_connection('no_cache').flushall;
disp(['new DB: ' get_db_timetag()]);
end

