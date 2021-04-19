function cluster_status = get_cluster_status()
r = get_redis_connection('no_cache');
r.multi;
r.llen('pending_tasks');
r.llen('ongoing_tasks');
r.llen('finished_tasks');
r.llen('failed_tasks');
r.llen('pre_pending_tasks');
r.get('tasks_count');
r.scard('available_workers');
numeric_stats = r.exec;
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
    if isempty(input)
        output = 0;
        return
    end
    input = strip(input);
    if isempty(input)
        output = 0;
    else
        output = str2double(input);
    end
end
