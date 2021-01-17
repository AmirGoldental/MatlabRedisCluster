function tasks = new_task(commands, task_type, varargin)
if ~exist('type', 'var')
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
    [~, user_name] = system('whoami');
    task.created_by = user_name(1:end-1);
    task.created_on = datetime();
    task.type = task_type;
    task_id = mrr.redis_cmd('incr tasks_count');
    task_key = ['task:' task_id];
    
    task_str = [];
    for field = fieldnames(task)'
        task_str = [task_str ' ' field{1} ' ' str_to_redis_str(task.(field{1}))];
    end
    mrr.redis_cmd(['HMSET ' task_key ' ' task_str])
    
    task.key = task_key;
    mrr.redis_cmd(['lpush pending_' task_type '_tasks ' task_key]);
    tasks{itter} = task;
end

if itter==1
    tasks = tasks{1};
end
end

