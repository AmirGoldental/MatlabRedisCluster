function status = get_cluster_status(list_name)
persistent cache 
cache = check_init_cache(cache);

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

function cache = check_init_cache(cache)
dbhash = mrr.redis_cmd(['get dbhash']); 
while isempty(dbhash)
    randomstr = char(randi([uint8('A') uint8('Z')], 1, 32));
    mrr.redis_cmd(['setnx dbhash ' randomstr]); 
    dbhash = mrr.redis_cmd(['get dbhash']);
end

if isempty(cache) || ~cache.isKey('dbhash') || ~strcmp(dbhash, cache('dbhash'))
    cache = containers.Map;
    cache('dbhash') = dbhash;    
end
end
