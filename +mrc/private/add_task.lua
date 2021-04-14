local task_id = redis.call('INCR','tasks_count'); 
local task_key = 'task:' .. task_id;
local command = KEYS[1];
local created_by = KEYS[2];
local created_on = KEYS[3];
local path2add = KEYS[4];
local fail_policy = KEYS[5];
local task_status; 
for idx=1,#ARGV,1 do 
    if redis.call('HGET', ARGV[idx], 'status') ~= 'finished' then 
        redis.call('LPUSH', task_key .. ':dependencies', ARGV[idx]); 
        redis.call('LPUSH', ARGV[idx] .. ':prior_to', task_key);
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
    'command', command, 'created_by', created_by, 'created_on', created_on,
    'path2add', path2add, 'status', task_status, 'fail_policy', fail_policy,
    'worker', 'None', 'str', '[' .. created_on .. '] ' .. command); 
return task_key
