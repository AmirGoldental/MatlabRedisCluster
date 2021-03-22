function db_id = get_db_id()
% Check that DB was not flushed
db_id = mrc.redis_cmd('get db_id');
while isempty(db_id)
    % DB is empty.
    db_id = datestr(datetime, 'YYYY_mm_dd__HH_MM_SS_FFF');
    mrc.redis_cmd(['setnx db_id ' db_id]);
    db_id = mrc.redis_cmd('get db_id');
end
end

