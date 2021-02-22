function tasks = new_task(commands, varargin)
commands = reshape(commands,1,[]);
varargin = cellfun(@(x) char(x), varargin, 'UniformOutput', false);

tasks = cell(0);
if ~iscell(commands)
    commands = {commands};
end

task_max_id = mrc.redis_cmd(['incrby tasks_count ' num2str(length(commands))]);
task_max_id = str2double(task_max_id);
task_ids = task_max_id-length(commands)+1:task_max_id;
task_strs = cell(size(commands));
task_keys = arrayfun(@(x) {['task:' num2str(x)]}, task_ids);
for i = 1:length(commands)
    command = char(commands{i});
    task = struct();
    task.command = command;
    task.created_by = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
    task.created_on = datetime();
    task.status = 'pending';
    
    task_str = [];
    for field = fieldnames(task)'
        task_str = [task_str ' ' field{1} ' ' str_to_redis_str(task.(field{1}))];
    end
    task_strs{i} = task_str;
    
    task.key = task_keys{i};
    tasks{i} = task;
end

cmds = cell(1,2*numel(task_keys));
cmds(1:2:end) = cellfun(@(task_key, task_str) {['HMSET ' task_key ' ' task_str]}, task_keys, task_strs);
cmds(2:2:end) = cellfun(@(task_key, task_str) {['lpush pending_tasks ' task_key]}, task_keys, task_strs);
mrc.redis_cmd(cmds);

if any(strcmpi('wait', varargin))
    for task = tasks
        task_status = mrc.redis_cmd(['HGET ' task{1}.key ' status']);
        while any(strcmpi(task_status,{'pending', 'ongoing'}))
            pause(3)
            task_status = mrc.redis_cmd(['HGET ' task{1}.key ' status']);
        end
    end
end
    
if length(tasks)==1
    tasks = tasks{1};
end

end

