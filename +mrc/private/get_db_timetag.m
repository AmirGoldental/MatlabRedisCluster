function db_timetag = get_db_timetag()
% Check that DB was not flushed
db_timetag = mrc.redis().get('db_timetag');
while isempty(db_timetag)
    % DB is empty.
      db_timetag = datestr(datetime, 'YYYY_mm_dd__HH_MM_SS');
    mrc.redis().setnx('db_timetag', db_timetag);
    db_timetag = mrc.redis().get('db_timetag');
end
end

