function [status, cluster_status] = get_cluster_status(list_name)
pending_elements2fetch = num2str(70);
[numeric_stats, redis_cmd_prefix] =  mrc.redis_cmd({'LLEN pending_tasks', ...
    'LLEN ongoing_tasks', 'SCARD finished_tasks', 'SCARD failed_tasks'});
cluster_status.num_pending = numeric_stats(1);
cluster_status.num_ongoing = numeric_stats(2);
cluster_status.num_finished = numeric_stats(3);
cluster_status.num_failed = numeric_stats(4);


switch list_name
    case 'workers'
        [keys, redis_cmd_prefix] = mrc.redis_cmd('keys worker:*'); 
    case 'pending'
        [keys, redis_cmd_prefix] = mrc.redis_cmd(['lrange pending_tasks 0 ' pending_elements2fetch]);
    case 'ongoing'
        [keys, redis_cmd_prefix] = mrc.redis_cmd('lrange ongoing_tasks 0 -1');   
    case 'finished'
        [keys, redis_cmd_prefix] = mrc.redis_cmd('SMEMBERS finished_tasks');   
    case 'failed'
        [keys, redis_cmd_prefix] = mrc.redis_cmd('SMEMBERS failed_tasks'); 
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

redis_outputs = mrc.redis_cmd(cellfun(@(x) {['HGETALL ' x]}, keys), 'cmd_prefix', redis_cmd_prefix);

for key = keys'
    itter = itter + 1;
    output.key(itter,1) = string(key{1});
    redis_output = redis_outputs{itter};
%     if strcmp(list_name, 'finished') || strcmp(list_name, 'failed')
%         redis_output = mrc.redis_cmd(['HGETALL ' key{1}], 'cache_first',...
%             'cmd_prefix', redis_cmd_prefix);
%     else
%         redis_output = mrc.redis_cmd(['HGETALL ' key{1}], ...
%             'cmd_prefix', redis_cmd_prefix);
%     end
    
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
