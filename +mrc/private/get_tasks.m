function tasks = get_tasks(status)
JSON = redis().evalsha(script_SHA('get_tasks'), 1, status);
if strcmp(JSON,'{}')
    tasks = {};
else
    tasks = jsondecode(JSON);
end
end

