function status = get_cluster_status(list_name, clear_flag)
persistent cache 
if isempty(cache)
    cache = containers.Map;
end
if exist('clear_flag', 'var') && clear_flag
    cache = [];
    return;
end

switch list_name
    case 'workers'
        [keys, redis_cmd_prefix] = mrr.redis_cmd(['keys worker:*']); 
    case 'pending'
        [keys, redis_cmd_prefix] = mrr.redis_cmd(['lrange pending_matlab_tasks 0 -1']);
    case 'ongoing'
        [keys, redis_cmd_prefix] = mrr.redis_cmd(['lrange ongoing_matlab_tasks 0 -1']);   
    case 'finished'
        [keys, redis_cmd_prefix] = mrr.redis_cmd(['SMEMBERS finished_matlab_tasks']);   
    case 'failed'
        [keys, redis_cmd_prefix] = mrr.redis_cmd(['SMEMBERS failed_matlab_tasks']); 
    otherwise
        error('Unknown list_name')
end
keys = split(keys, newline);
output = struct();
itter = 0;
if isempty(keys{1})
    status = table();
    return
end

for key = keys'
    itter = itter + 1;
    output.key(itter,1) = string(key{1});
    
    if cache.isKey(key{1})
        obj_cells = cache(key{1});
    else
        obj_cells = split(mrr.redis_cmd(['HGETALL ' key{1}], redis_cmd_prefix), newline); 
        if strcmp(list_name, 'finished') || strcmp(list_name, 'failed')
            cache(key{1}) = obj_cells;
        end
    end
    
    for cell_idx = 1:2:(length(obj_cells)-1)
        output.(obj_cells{cell_idx})(itter,1) = string(obj_cells{cell_idx+1});
    end
end
status = struct2table(output);
end
