function move_task_to_finished(task_key)
task = get_redis_hash(task_key);
if strcmpi(task.status, 'finished')
    return
end
dependent_tasks = split(mrc.redis_cmd(['LRANGE ' task_key ':prior_to 0 -1']), newline);
if numel(dependent_tasks) == 1
    if isempty(dependent_tasks{1})
        dependent_tasks = [];
    end
end
for idx = 1:numel(dependent_tasks)
    dependent_task_key = dependent_tasks{idx};
    mrc.redis_cmd(['EVALSHA ' script_SHA('update_dependent_task') '2 ' dependent_task_key ' ' task_key]);
end
mrc.redis_cmd({'MULTI', ...
    ['LREM ' char(task.status) '_tasks 0 ' task_key], ...
    ['LPUSH finished_tasks ' task_key ], ...
    ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
    'EXEC'});
end

