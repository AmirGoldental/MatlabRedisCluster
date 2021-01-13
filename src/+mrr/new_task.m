function task_id = new_task(command, task_type)
if ~exist('type', 'var')
    task_type = 'matlab';
end
task = struct();
command = char(command);
if ~isempty(find(command == '(', 1))
    task.task_name = command(1:find(command == '(',1)-1);
elseif ~isempty(find(command == ' ', 1))
    task.task_name = command(1:find(command == ' ',1)-1);
else
    task.task_name = command(1:10);
end
task.command = command;
[~, user_name] = system('whoami');
task.created_by = user_name(1:end-1);
task.created_on = datetime();
redis_connection = mrr.RedisConnection(fullfile(fileparts(mfilename('fullpath')),'..'));
task_id = redis_connection.cmd('incr tasks_count');
task.task_id = task_id;
response = redis_connection.cmd(['lpush pending_' task_type '_tasks ' struct_to_redis_json(task) ]);

end

