function flush_db()
mrc.redis_cmd('FLUSHALL');
%disp(['new DB: ' get_db_timetag()]);
end

