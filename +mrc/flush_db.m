function flush_db()
redis('reconnect').flushall;
disp(['new DB: ' get_db_timetag()]);
end

