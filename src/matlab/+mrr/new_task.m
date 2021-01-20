function tasks = new_task(commands, varargin)
varargin = cellfun(@(x) char(x), varargin, 'UniformOutput', false);
if any(strcmpi('batch', varargin))
    task_type = 'batch';
else
    task_type = 'matlab';
end

tasks = cell(0);
if ~iscell(commands)
    commands = {commands};
end
itter = 0;
for command_cell = commands(:)'
    itter = itter + 1;
    command = char(command_cell{1});
    task.command = command;
    task.created_by = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
    task.created_on = datetime();
    task.type = task_type;
    task.status = 'pending';
    task_id = mrr.redis_cmd('incr tasks_count');
    task_key = ['task:' task_id];
    
    task_str = [];
    for field = fieldnames(task)'
        task_str = [task_str ' ' field{1} ' ' str_to_redis_str(task.(field{1}))];
    end
    mrr.redis_cmd(['HMSET ' task_key ' ' task_str]);
    
    task.key = task_key;
    mrr.redis_cmd(['lpush pending_' task_type '_tasks ' task_key]);
    tasks{itter} = task;
end


if any(strcmpi('wait', varargin))
    for task = tasks
        task_status = mrr.redis_cmd(['HGET ' task{1}.key ' status']);
        while any(strcmpi(task_status,{'pending', 'ongoing'}))
            pause(3)
            task_status = mrr.redis_cmd(['HGET ' task{1}.key ' status']);
        end
    end
end
    
if itter==1
    tasks = tasks{1};
end

end

