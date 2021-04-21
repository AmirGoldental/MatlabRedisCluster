local status = KEYS[1];
local task_keys = redis.call('LRANGE', status .. '_tasks', 0, -1);
local ret = {};
for idx = 1, #task_keys, 1 do
    ret[idx] = {redis.call('hget', task_keys[idx], 'key'), redis.call('hget', task_keys[idx], 'str')};
end
return cjson.encode(ret)