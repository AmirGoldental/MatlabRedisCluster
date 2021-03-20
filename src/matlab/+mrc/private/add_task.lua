local task_id = redis.call('INCR','tasks_count'); 
local task_key = 'task:' .. task_id;
local task_status; 
for idx=1,#ARGV,1 do 
    if redis.call('HGET', ARGV[idx], 'status') == 'pending' or redis.call('HGET', ARGV[idx], 'status') == 'pre_pending' or redis.call('HGET', ARGV[idx], 'status') == 'ongoing' then 
        redis.call('LPUSH', task_key .. ':dependencies', ARGV[idx]); redis.call('LPUSH', ARGV[idx] .. ':prior_to', task_key);
    end; 
end; 
if #ARGV == 0 then 
    redis.call('RPUSH', 'pending_tasks', task_key);
    task_status = 'pending';
elseif redis.call('LLEN', task_key .. ':dependencies') == 0 then 
    redis.call('LPUSH', 'pending_tasks', task_key); task_status = 'pending'; 
else redis.call('RPUSH', 'pre_pending_tasks', task_key); task_status = 'pre_pending'; 
end;
redis.call('HMSET', task_key, 'key', task_key, 'id', tostring(task_id),
    'command', KEYS[1], 'created_by', KEYS[2], 'created_on', KEYS[3],
    'path2add', KEYS[4], 'status', task_status, 'fail_policy', KEYS[5]); 
return task_key
