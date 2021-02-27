function [status, cluster_status] = get_cluster_status(list_name, idxs_to_load)
if ~exist('idxs_to_load', 'var')
    idxs_to_load = [0 -1];
end

[numeric_stats, redis_cmd_prefix] =  mrc.redis_cmd({'LLEN pending_tasks', ...
    'SCARD ongoing_tasks', 'LLEN finished_tasks', 'LLEN failed_tasks', 'info'});

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

switch list_name
    case {'pending', 'finished', 'failed'}
        keys = mrc.redis_cmd(['lrange ' list_name '_tasks ' num2str(idxs_to_load)]);
        keys = split(keys, newline);
    case 'ongoing'
        keys = mrc.redis_cmd('SMEMBERS ongoing_tasks');
    case 'workers'
        keys = arrayfun(@(worker_id) {['worker:' num2str(worker_id)]}, 1:str2double(cluster_status.num_workers));
    otherwise
        keys = [];        
end
status = struct2table(get_redis_hash(keys));
if ~isempty(status)
    status.key = keys;
end
end
