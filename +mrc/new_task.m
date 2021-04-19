function [task_keys, tasks] = new_task(commands, varargin)
commands = reshape(commands,1,[]);
char_varargin = cellfun(@(x) char(x), varargin, 'UniformOutput', false);

tasks = cell(0);
if ~iscell(commands)
    commands = {commands};
end

if any(strcmpi('addpath', char_varargin))
    path2add = char_varargin{find(strcmpi('addpath', char_varargin), 1) + 1};
else
    path2add = 'None';
end

if any(strcmpi('fail_policy', char_varargin))
    fail_policy = char_varargin{find(strcmpi('fail_policy', char_varargin), 1) + 1};
else
    fail_policy = 'halt';
end

for i = 1:length(commands)
    command = char(commands{i});
    task = struct();
    task.command = command;
    task.created_by = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
    task.created_on = datetime();
    task.path2add = path2add;
    task.fail_policy = fail_policy;
    tasks{i} = task;
end


if any(strcmpi('dependencies', char_varargin))
    dependencies = varargin{find(strcmpi('dependencies', char_varargin), 1) + 1};
    if ~iscell(dependencies)
        dependencies = {dependencies};
    end
%     dependencies = char(join(dependencies(:)', ' '));
else
    dependencies = {};
end
redis('reconnect');
add_task_script_SHA = script_SHA('add_task');
redis().multi;
for ind = 1:numel(tasks)
	redis().evalsha(add_task_script_SHA, '5', str_to_redis_str(task.command), ...
        str_to_redis_str(task.created_by), str_to_redis_str(task.created_on), ...
    	str_to_redis_str(task.path2add), str_to_redis_str(task.fail_policy), dependencies{:});
end
task_keys = redis().exec;

for task_idx = 1:numel(tasks)
    tasks{task_idx}.key = task_keys{task_idx};
end

if any(strcmpi('wait', varargin))
    mrc.wait(task_keys);
end
    
if length(tasks)==1
    tasks = tasks{1};
end

end


