function cluster_status = get_cluster_status()
numeric_stats = mrc.redis_cmd({'LLEN pending_tasks', ...
    'LLEN ongoing_tasks', 'LLEN finished_tasks', 'LLEN failed_tasks', ...
    'LLEN pre_pending_tasks', 'GET tasks_count', 'SCARD available_workers'});
numeric_stats = cellfun(@redis_str2double, numeric_stats);
cluster_status.num_pending = numeric_stats(1);
cluster_status.num_ongoing = numeric_stats(2);
cluster_status.num_finished = numeric_stats(3);
cluster_status.num_failed = numeric_stats(4);
cluster_status.num_pre_pending = numeric_stats(5);
cluster_status.num_tasks = numeric_stats(6);
cluster_status.num_workers = numeric_stats(7); 

redis_uptime = (now - datenum(get_db_timetag(), 'YYYY_mm_dd__HH_MM_SS_FFF'))*24*60;
if redis_uptime > 60*24
    redis_uptime = [num2str(redis_uptime/(60*24), 3) ' d'];
elseif redis_uptime > 60
    redis_uptime = [num2str(redis_uptime/60, 3) ' h'];
else
    redis_uptime = [num2str(redis_uptime, 3) ' m'];
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
