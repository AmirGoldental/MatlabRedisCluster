local dependent_task_key = KEYS[1];
local finished_task_key = KEYS[2];
redis.call('LREM', dependent_task_key .. ':dependencies', 0, finished_task_key); 
if redis.call('LLEN', dependent_task_key .. ':dependencies') == 0 then 
    if redis.call('LREM', 'pre_pending_tasks', 0, dependent_task_key) == 0 then 
        return -1 
    end; 
    redis.call('LPUSH', 'pending_tasks', dependent_task_key); 
    redis.call('HSET', dependent_task_key, 'status', 'pending'); 
end;
return 0;