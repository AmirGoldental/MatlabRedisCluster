function join_as_worker()
worker = struct();
worker_id = mrr.redis_cmd('incr matlab_workers_count');
worker.started_on = datetime();
[~, worker_station] = system('whoami');

mrr_dir = fileparts(fileparts(mfilename('fullpath')));
system(sprintf('start "worker_%s_watcher" /D "%s" %s %s %s %d', worker_id, ...
    mrr_dir, 'matlab_worker_watcher.bat', 'mrr_client.conf', worker_id, feature('getpid')));

worker.status = 'active';
worker.computer = worker_station(1:end-1);

worker_str = [];
for field = fieldnames(worker)'
    worker_str = [worker_str ' ' field{1} ' ' str_to_redis_str(worker.(field{1}))];
end
mrr.redis_cmd(['HMSET worker:' worker_id ' ' worker_str])
worker.id = worker_id;

while mrr.redis_cmd(['HEXISTS worker:' worker_id ' computer']) == '1'
    preform_task(worker_id)
end

    function preform_task(worker_id)
        task_key = mrr.redis_cmd('RPOPLPUSH pending_matlab_tasks ongoing_matlab_tasks');
        if isempty(task_key)
            pause(3)
            return
        end
        task = struct();
        task.command = mrr.redis_cmd(['HGET ' task_key ' command']);
        task.created_by = mrr.redis_cmd(['HGET ' task_key ' created_by']);
        task.created_on = mrr.redis_cmd(['HGET ' task_key ' created_on']);
        mrr.redis_cmd(['HMSET task:' task_key ...
            ' started_on ' str_to_redis_str(datetime) ' worker_id ' worker_id]);
        mrr.redis_cmd(['HSET worker:' worker_id ' current_task ' task_key]);
        disp(task)
        try
            eval(task.command)
            mrr.redis_cmd(['LREM ongoing_matlab_tasks 0 ' task_key])
            mrr.redis_cmd(['SADD finished_matlab_tasks ' task_key ]);
            mrr.redis_cmd(['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime)]);
        catch err
            mrr.redis_cmd(['LREM ongoing_matlab_tasks 0 ' task_key])
            mrr.redis_cmd(['SADD failed_matlab_tasks ' task_key ]);
            mrr.redis_cmd(['HSET ' task_key ' failed_on ' str_to_redis_str(datetime)]);
            mrr.redis_cmd(['HSET ' task_key ' err_msg ' str_to_redis_str(jsonencode(err))]);
            disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
        end
        mrr.redis_cmd(['HDEL worker:' worker_id ' current_task ' task_key]);
    end
end

