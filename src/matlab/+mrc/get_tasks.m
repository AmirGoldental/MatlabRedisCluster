function tasks = get_tasks(tasks, task_ids, items_per_load)
% task_ids are sorted by priority
tasks2download = setdiff(task_ids, find(~cellfun(@isempty, tasks)), 'stable');
tasks2download = tasks2download(1:min(items_per_load, end));
keys = arrayfun(@(task_id) ['task:' num2str(task_id)], tasks2download(:), 'UniformOutput', false);
if isempty(keys)
    return
elseif numel(keys) == 1
    tasks(tasks2download) = {get_redis_hash(keys)};
else
    tasks(tasks2download) = get_redis_hash(keys);
end

end