function flush_db()
mrc.redis('reconnect').flushall;
disp(['new DB: ' get_db_timetag()]);
end

