function output = get_tasks(task_ids, varargin)
% returns a cell array

persistent tasks
persistent db_timetag

% db sync
if ~strcmp(db_timetag, get_db_timetag())
    db_timetag = get_db_timetag();
    tasks = cell(0);
end
if numel(tasks) < max(task_ids)
    tasks{max(task_ids)} = {};
end
varargin = cellfun(@char,varargin, 'UniformOutput', false);
if any(strcmpi(varargin, 'network_only'))
    % download all tasks
     download_tasks(task_ids);
elseif any(strcmpi(varargin, 'cache_first'))
    % download only non_cached
    cached_tasks = find(cellfun(@isempty,tasks));
    download_tasks(intersect(task_ids, cached_tasks));
elseif any(strcmpi(varargin, 'cache_only'))
    % default
end

if any(strcmpi(varargin, 'validate_status'))
    expected_status = varargin{find(strcmpi(varargin, 'validate_status'), 1) + 1};
    cached_tasks = find(~cellfun(@isempty,tasks));
    different_status_tasks = cached_tasks(...
        cellfun(@(task) ~strcmpi(task.status, expected_status), tasks(cached_tasks)));
    tasks_to_clear = intersect(task_ids, different_status_tasks);
    if ~isempty(tasks_to_clear)
        tasks(tasks_to_clear) = cell(size(tasks_to_clear));
    end
end

output = tasks(task_ids);

    function download_tasks(task_ids)
        if isempty(task_ids)
            return
        end
        keys = arrayfun(@(task_id) ['task:' num2str(task_id)], task_ids, 'UniformOutput', false);
        tasks(task_ids(:)) = get_redis_hash(keys);
    end
end