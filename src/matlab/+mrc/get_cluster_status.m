function [status, cluster_status] = get_cluster_status(list_name, idxs_to_load)
if ~exist('idxs_to_load', 'var')
    idxs_to_load = [0 -1];
end

[numeric_stats, redis_cmd_prefix] =  mrc.redis_cmd({'LLEN pending_tasks', ...
    'LLEN ongoing_tasks', 'LLEN finished_tasks', 'LLEN failed_tasks', 'info'});

cluster_status.num_pending = strip(numeric_stats{1});
cluster_status.num_ongoing = strip(numeric_stats{2});
cluster_status.num_finished = strip(numeric_stats{3});
cluster_status.num_failed = strip(numeric_stats{4});
cluster_status.num_workers = mrc.redis_cmd('GET workers_count');  % Note => this line may be slow for many keys

redis_uptime = strip(numeric_stats{5});
redis_uptime(1: (strfind(redis_uptime, 'uptime_in_seconds') + length('uptime_in_seconds'))) = [];
redis_uptime((find(redis_uptime == newline, 1)-1):end) = [];
redis_uptime = str2double(redis_uptime);
if redis_uptime > 3600*24
    redis_uptime = [num2str(redis_uptime/(3600*24), 3) 'd'];
elseif redis_uptime > 3600
    redis_uptime = [num2str(redis_uptime/3600, 3) 'h'];
else
    redis_uptime = [num2str(redis_uptime/60, 3) 'm'];
end    
cluster_status.uptime = redis_uptime;

if strcmpi(list_name, 'workers')
    keys = arrayfun(@(worker_id) {['worker:' num2str(worker_id)]}, 1:cluster_status.num_workers);
else
    redis_list_name = [list_name '_tasks'];
    [keys, redis_cmd_prefix] = mrc.redis_cmd(['lrange ' redis_list_name ' ' num2str(idxs_to_load)]);
    keys = split(keys, newline);
end

output = struct();
if isempty(keys{1})
    status = table();
    return
end

redis_outputs = mrc.redis_cmd(cellfun(@(x) {['HGETALL ' x]}, keys), 'cmd_prefix', redis_cmd_prefix);

itter = 0;
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
end
