function move_task_to_finished(task_key)
task_key = char(task_key);
task = get_redis_hash(task_key);
if strcmpi(task.status, 'finished')
    return
end
mrc.redis_cmd(['EVALSHA ' script_SHA('update_dependent_tasks') '1 ' task_key]);
mrc.redis_cmd({'MULTI', ...
    ['LREM ' char(task.status) '_tasks 0 ' task_key], ...
    ['LPUSH finished_tasks ' task_key ], ...
    ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
    'EXEC'});
end

