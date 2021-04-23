function tasks = get_tasks(status)
JSON = lua_script('get_tasks', 1, status);
if strcmp(JSON,'{}')
    tasks = {};
else
    tasks = jsondecode(JSON);
end
end

