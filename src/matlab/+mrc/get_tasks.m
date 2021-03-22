function tasks_cells = get_tasks(varargin)
persistent tasks
persistent db_id

% db sync
if ~strcmp(db_id, get_db_id())
    db_id = get_db_id();
    tasks = cell(0);
end

if any(strcmpi(varargin, 'download'))
    tasks2download = varargin{find(strcmpi(varargin, 'download'), 1) + 1};
    if ~isempty(tasks2download)
        keys = cellfun(@(task_id) ['task:' num2str(task_id)], num2cell(tasks2download(:)), 'UniformOutput', false);
        tasks(tasks2download(:)) = get_redis_hash(keys);
    end
end

if any(strcmpi(varargin, 'get_by_id'))
    tasks2get = varargin{find(strcmpi(varargin, 'get_by_id'), 1) + 1};
    tasks2download = intersect(tasks2get, find(cellfun(@isempty,tasks)));
    if ~isempty(tasks2download)
        keys = cellfun(@(task_id) ['task:' num2str(task_id)], num2cell(tasks2download(:)), 'UniformOutput', false);    
        tasks(tasks2download(:)) = get_redis_hash(keys);
    end
    tasks_cells = tasks(tasks2get);
else
    tasks_cells = tasks;
end
end