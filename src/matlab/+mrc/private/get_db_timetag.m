function db_timetag = get_db_timetag()
% Check that DB was not flushed
db_timetag = mrc.redis_cmd('get db_timetag');
while isempty(db_timetag)
    % DB is empty.
    db_timetag = datestr(datetime, 'YYYY_mm_dd__HH_MM_SS_FFF');
    mrc.redis_cmd(['setnx db_timetag ' db_timetag]);
    db_timetag = mrc.redis_cmd('get db_timetag');
end
end

