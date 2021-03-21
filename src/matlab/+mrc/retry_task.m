function retry_task(task_key)
if iscell(task_key)
    for task_cell = task_key(:)'
        mrc.retry_failed_task(task_cell{1})
    end
end
task_key = char(task_key);
task = get_redis_hash(task_key);
if strcmpi(task.status, 'finished')
    mrc.redis_cmd({'MULTI', ...
        ['LREM finished_tasks 0 ' task_key], ...
        ['LPUSH pending_tasks ' task_key ], ...
        ['HMSET ' task_key ' status pending'], ...
        'EXEC'});
elseif strcmpi(task.status, 'failed')
    mrc.redis_cmd({'MULTI', ...
        ['LREM failed_tasks 0 ' task_key], ...
        ['LPUSH pending_tasks ' task_key ], ...
        ['HMSET ' task_key ' status pending'], ...
        'EXEC'});
end
end
