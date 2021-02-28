function cluster_status = get_cluster_status()
numeric_stats =  mrc.redis_cmd({'LLEN pending_tasks', ...
    'LLEN ongoing_tasks', 'LLEN finished_tasks', 'LLEN failed_tasks', 'GET tasks_count', 'info'});

cluster_status.num_pending = redis_str2double(numeric_stats{1});
cluster_status.num_ongoing = redis_str2double(numeric_stats{2});
cluster_status.num_finished = redis_str2double(numeric_stats{3});
cluster_status.num_failed = redis_str2double(numeric_stats{4});
cluster_status.num_tasks = redis_str2double(numeric_stats{5});
cluster_status.num_workers = redis_str2double(mrc.redis_cmd('GET workers_count')); 

redis_uptime = redis_str2double(numeric_stats{6});
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
end

function output = redis_str2double(input)
    input = strip(input);
    if isempty(input)
        output = 0;
    else
        output = str2double(input);
    end
end
