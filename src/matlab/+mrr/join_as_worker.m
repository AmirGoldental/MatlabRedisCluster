function join_as_worker()
worker = struct();
worker_id = mrr.redis_cmd('incr matlab_workers_count');
worker.started_on = datetime();
[~, worker_station] = system('whoami');
worker.computer = worker_station(1:end-1);

worker_str = [];
for field = fieldnames(worker)'
    worker_str = [worker_str ' ' field{1} ' ' str_to_redis_str(worker.(field{1}))];
end
mrr.redis_cmd(['HMSET worker:' num2str(worker_id) ' ' worker_str])
worker.id = worker_id;

while mrr.redis_cmd(['HEXISTS worker:' worker_id ' computer']) == '1'
    preform_task(worker_id)
end

    function preform_task(worker_id)
        task_id = mrr.redis_cmd('RPOPLPUSH pending_matlab_tasks ongoing_matlab_tasks');
        if isempty(task_id)
            pause(3)
            return
        end
        task = struct();
        task.command = mrr.redis_cmd(['HGET task:' task_id ' command']);
        task.created_by = mrr.redis_cmd(['HGET task:' task_id ' created_by']);
        task.created_on = mrr.redis_cmd(['HGET task:' task_id ' created_on']);
        mrr.redis_cmd(['HMSET task:' task_id ...
            ' started_on ' str_to_redis_str(datetime) ' worker_id ' worker_id]);
        disp(task)
        try
            eval(task.command)
            mrr.redis_cmd(['LREM ongoing_matlab_tasks 0 ' task_id])
            mrr.redis_cmd(['SADD finished_matlab_tasks ' task_id ]);

            mrr.redis_cmd(['HMSET task:' task_id ' finished_on ' str_to_redis_str(datetime)]);
        catch err
            mrr.redis_cmd(['LREM ongoing_matlab_tasks 0 ' task_id])
            mrr.redis_cmd(['SADD failed_matlab_tasks ' task_id ]);
            mrr.redis_cmd(['HSET task:' task_id ' failed_on ' str_to_redis_str(datetime)]);
            mrr.redis_cmd(['HSET task:' task_id ' err_msg ' str_to_redis_str(jsonencode(err))]);
            disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
        end
    end
end

