function join_as_worker()

redis_connection = mrr.RedisConnection(fullfile(fileparts(mfilename('fullpath')),'..'));
worker_id = redis_connection.cmd('incr matlab_workers_count');
redis_connection.cmd(['sadd workers ' worker_id]);

while redis_connection.cmd(['sismember workers ' worker_id]) == '1'
    preform_task()
    pause(3)
end

    function preform_task()
        response = redis_connection.cmd('rpop pending_matlab_tasks');
        if isempty(response)
            return
        end
        try
            task = jsondecode(response);
        catch err
            disp(['Unable to decode ' response])
            return
        end
        task.started_on = datetime();
        [~, user_name] = system('whoami');
        task.worker_station = user_name(1:end-1);
        task.worker_id = worker_id;
        redis_connection.cmd(['SADD ongoing_matlab_tasks ' struct_to_redis_json(task) ]);
        disp(task)
        try
            eval(task.command)
            redis_connection.cmd(['SPOP ongoing_matlab_tasks ' struct_to_redis_json(task) ]);
            task.finished_on = datetime();
            redis_connection.cmd(['SADD finished__matlab_tasks ' struct_to_redis_json(task) ]);
        catch err
            redis_connection.cmd(['SPOP ongoing_matlab_tasks ' struct_to_redis_json(task) ]);
            task.failed_on = datetime();
            task.error_json = struct_to_redis_json(err);
            redis_connection.cmd(['SADD failed_matlab_tasks ' struct_to_redis_json(task) ]);
            disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
        end
 end
end

