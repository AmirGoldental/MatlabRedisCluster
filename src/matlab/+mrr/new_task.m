function task = new_task(command, task_type)
if ~exist('type', 'var')
    task_type = 'matlab';
end
task = struct();
command = char(command);
task.command = command;
[~, user_name] = system('whoami');
task.created_by = user_name(1:end-1);
task.created_on = datetime();
task.type = task_type;
task_id = mrr.redis_cmd('incr tasks_count');

task_str = [];
for field = fieldnames(task)'
    task_str = [task_str ' ' field{1} ' ' str_to_redis_str(task.(field{1}))];
end
mrr.redis_cmd(['HMSET task:' num2str(task_id) ' ' task_str])

task.id = task_id;
mrr.redis_cmd(['lpush pending_' task_type '_tasks ' num2str(task_id)]);
end

