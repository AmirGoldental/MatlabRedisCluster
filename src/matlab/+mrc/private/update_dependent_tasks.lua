local finished_task_key = KEYS[1];
local num_of_dependent_tasks = tonumber(redis.call('LLEN', finished_task_key .. ':prior_to'));
local dependent_task_key;
for task_idx = 1, num_of_dependent_tasks, 1 do
    dependent_task_key = redis.call('LINDEX', finished_task_key .. ':prior_to', task_idx - 1); 
    redis.call('LREM', dependent_task_key .. ':dependencies', 0, finished_task_key); 
    if redis.call('LLEN', dependent_task_key .. ':dependencies') == 0 then 
        if redis.call('LREM', 'pre_pending_tasks', 0, dependent_task_key) == 1 then 
            redis.call('LPUSH', 'pending_tasks', dependent_task_key); 
            redis.call('HSET', dependent_task_key, 'status', 'pending'); 
        end; 
    end;
end
return 0;