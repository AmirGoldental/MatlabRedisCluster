function change_key_status(key, status)
% Examples
% change_key_status('task:X', 'pending'/'finished')
% change_key_status({'task:X','task:Y'}, 'pending'/'finished')
% change_key_status('pending_tasks', 'finished') # to be implemented
% change_key_status('pre_pending_tasks', 'pending') # to be implemented

% change_key_status('worker:X', 'active'/'suspended'/'dead')
% change_key_status('all_workers', 'active'/'suspended'/'dead')

% DOC
% all possible task status: pre_pending, pending, ongoing, finished, failed
% all possible worker status: active, suspended, restart, kill, dead

if iscell(key)
    for cell_idx = 1:numel(key)
        if ~isempty(key{cell_idx})
            mrc.change_key_status(key{cell_idx}, status);
        end
    end
    return
end
key = char(key);
status = char(status);

if strncmp(key, 'task', 4)
    change_task_status(key, status)
elseif strncmp(key, 'worker', 6)
    change_worker_status(key, status)
elseif strcmpi(key, 'all_workers')
    worker_keys = split(strip(mrc.redis_cmd('SMEMBERS available_workers')));
    if strcmpi(status, 'dead')
        mrc.change_key_status(worker_keys, 'kill');
    end
    mrc.change_key_status(worker_keys, status);
else
    error('Unrecognized key')
end
end


function change_task_status(task_key, status)
current_status = char(mrc.redis_cmd(['HGET ' task_key ' status']));

if strcmpi(current_status, 'ongoing')
    worker_key = char(mrc.redis_cmd(['HGET ' task_key ' worker']));
    worker_restart_cmd = ['HSET ' worker_key ' status restart'];
else
    worker_restart_cmd = 'echo 0';
end

switch status
    case 'pending'
        if ~any(strcmpi(current_status, {'pending', 'ongoing'}))
            mrc.redis_cmd({'MULTI', ...
                ['LREM ' current_status '_tasks 0 ' task_key], ...
                ['LPUSH pending_tasks ' task_key ], ...
                ['HMSET ' task_key ' status pending'], ...
                [worker_restart_cmd], ...
                'EXEC'});
        end
    case 'finished'
        if strcmpi(current_status, 'finished')
            return
        end
        mrc.redis_cmd({'MULTI', ...
            ['EVALSHA ' script_SHA('update_dependent_tasks') '1 ' task_key], ...
            ['LREM ' current_status '_tasks 0 ' task_key], ...
            ['LPUSH finished_tasks ' task_key ], ...
            ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
            [worker_restart_cmd], ...
            'EXEC'});
end
end


function change_worker_status(worker_key, status)
current_status = char(mrc.redis_cmd(['HGET ' worker_key ' status']));
switch status
    case 'active'
        if strcmpi(current_status, 'suspended')
            mrc.redis_cmd(['LPUSH ' char(worker_key) ':activate 1']);
        end
    case 'suspended'
        if strcmpi(current_status, 'active')
            mrc.redis_cmd(['HSET ' worker_key ' status suspended']);
        end
    case 'restart'        
        if any(strcmpi(current_status, {'active','suspended'}))
            mrc.redis_cmd({['SREM available_workers ' worker_key], ...
                ['HSET ' worker_key ' status restart']})
        end
    case 'kill'
        if ~any(strcmpi(current_status, {'kill', 'dead'}))
            mrc.redis_cmd({['SREM available_workers ' worker_key], ...
                ['HSET ' worker_key ' status kill']})
        end
    case 'dead'
        if ~strcmpi(current_status, 'kill')
            mrc.change_key_status(worker_key, 'kill')
        end
        wait_for_condition(@() strcmpi(get_redis_hash(worker_key, 'status'), 'dead'));
end
end
