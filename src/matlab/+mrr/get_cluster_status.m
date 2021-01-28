function status = get_cluster_status(list_name)

switch list_name
    case 'workers'
        [keys, redis_cmd_prefix] = mrr.redis_cmd('keys worker:*'); 
    case 'pending'
        [keys, redis_cmd_prefix] = mrr.redis_cmd('lrange pending_tasks 0 -1');
    case 'ongoing'
        [keys, redis_cmd_prefix] = mrr.redis_cmd('lrange ongoing_tasks 0 -1');   
    case 'finished'
        [keys, redis_cmd_prefix] = mrr.redis_cmd('SMEMBERS finished_tasks');   
    case 'failed'
        [keys, redis_cmd_prefix] = mrr.redis_cmd('SMEMBERS failed_tasks'); 
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
    
    if strcmp(list_name, 'finished') || strcmp(list_name, 'failed')
        redis_output = mrr.redis_cmd(['HGETALL ' key{1}], 'cache_first',...
            'cmd_prefix', redis_cmd_prefix);
    else
        redis_output = mrr.redis_cmd(['HGETALL ' key{1}], ...
            'cmd_prefix', redis_cmd_prefix);
    end
    
    obj_cells = split(redis_output, newline);
    for cell_idx = 1:2:(length(obj_cells)-1)
        output.(obj_cells{cell_idx})(itter,1) = string(obj_cells{cell_idx+1});
    end
end
status = struct2table(output);

switch list_name
    case 'workers'
        [~, sort_order] = sort(status.key);
    case 'pending'
        [~, sort_order] = sort(datetime(status.created_on));
    case 'ongoing'
        [~, sort_order] = sort(datetime(status.started_on));
    case 'finished'
        [~, sort_order] = sort(datetime(status.finished_on), 'descend');
    case 'failed'
        [~, sort_order] = sort(datetime(status.failed_on), 'descend');
    otherwise
        error('Unknown list_name')
end
status = status(sort_order,:);
end
