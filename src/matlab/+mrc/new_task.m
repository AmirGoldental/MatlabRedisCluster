function tasks = new_task(commands, varargin)
commands = reshape(commands,1,[]);
varargin = cellfun(@(x) char(x), varargin, 'UniformOutput', false);

tasks = cell(0);
if ~iscell(commands)
    commands = {commands};
end
for i = 1:length(commands)
    command = char(commands{i});
    task = struct();
    task.command = command;
    task.created_by = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
    task.created_on = datetime();
    tasks{i} = task;
end

if any(strcmpi('path', varargin))
    path2add = varargin{find(strcmpi('path', varargin), 1) + 1};
else
    path2add = 'None';
end

lua_add_task = ['"'...
    'local task_key = ''task:'' .. redis.call(''incr'',''tasks_count'');'...
    'redis.call(''RPUSH'', ''pending_tasks'', task_key);'...
    'redis.call(''HMSET'', task_key, ' ...
    '''command'', KEYS[1], ' ...
    '''created_by'', KEYS[2], ' ...
    '''created_on'', KEYS[3], ' ...
    '''path2add'', KEYS[4], ' ...
    '''status'', ''pending'');'...
    'return task_key'...
    '" 4'];
redis_add_task = @(task) ['eval ' lua_add_task ...
    ' ' str_to_redis_str(task.command) ...
    ' ' str_to_redis_str(task.created_by) ...
    ' ' str_to_redis_str(task.created_on) ...
    ' ' str_to_redis_str(path2add) ];
cmds = cellfun(redis_add_task, tasks, 'UniformOutput', false);
keys = mrc.redis_cmd(cmds);

if any(strcmpi('wait', varargin))
    for key = keys
        task_status = mrc.redis_cmd(['HGET ' key{1} ' status']);
        while any(strcmpi(task_status,{'pending', 'ongoing'}))
            pause(3)
            task_status = mrc.redis_cmd(['HGET ' key{1} ' status']);
        end
    end
end
    
if length(tasks)==1
    tasks = tasks{1};
end

end

