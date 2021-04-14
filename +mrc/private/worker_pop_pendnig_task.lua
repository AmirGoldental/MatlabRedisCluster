local worker_key = KEYS[1];
local time_str = KEYS[2];
redis.call('HSET', worker_key, 'last_ping', time_str);
if redis.call('LLEN', 'pending_tasks') == 0 then 
    return ''
end;
local task_key = redis.call('LPOP', 'pending_tasks');
local task_cmd = redis.call('HGET', task_key, 'command');
local worker_str = redis.call('HGET', worker_key, 'computer') .. '/' .. worker_key;
redis.call('RPUSH', 'ongoing_tasks', task_key);
redis.call('HMSET', task_key, 'status', 'ongoing', 'started_on', time_str,  
           'worker', worker_str, 'str', '[' .. time_str .. '] (' .. worker_str .. ') ' ..  task_cmd);
redis.call('HMSET', worker_key, 'current_task', task_key, 'last_command', task_cmd);
return task_key;