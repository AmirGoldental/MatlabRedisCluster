function db_timetag = get_db_timetag()
% Check that DB was not flushed
r = get_redis_connection;
db_timetag = r.get('db_timetag');
while isempty(db_timetag)
    % DB is empty.
    db_timetag = datestr(datetime, 'YYYY_mm_dd__HH_MM_SS_FFF');
    r.setnx('db_timetag', db_timetag);
    db_timetag = r.get('db_timetag');
end
end

