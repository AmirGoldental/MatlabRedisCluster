function change_key_status(key, status, varargin)
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

force_flag = any(strcmpi(cellfun(@char, varargin, 'UniformOutput', false), 'force'));
if force_flag
    force_flag = 'force';
else
    force_flag = 'dont_force';
end

if iscell(key)
    for cell_idx = 1:numel(key)
        if ~isempty(key{cell_idx})
            mrc.change_key_status(key{cell_idx}, status, force_flag);
        end
    end
    return
end
key = char(key);
status = char(status);

if strncmp(key, 'task', 4)
    change_task_status(key, status, force_flag)
elseif strcmpi(key, 'all_tasks')
    error('not implemented yet')
elseif strncmp(key, 'worker', 6)
    change_worker_status(key, status, force_flag)
elseif strcmpi(key, 'all_workers')
    worker_keys = split(strip(mrc.redis_cmd('SMEMBERS available_workers')));
    if strcmpi(status, 'dead')
        mrc.change_key_status(worker_keys, 'kill', force_flag);
    end
    mrc.change_key_status(worker_keys, status, force_flag);
else
    error('Unrecognized key')
end
end


function change_task_status(task_key, status, force_flag)
task = get_redis_hash(task_key);
task = structfun(@char, task, 'UniformOutput', false);
switch status
    case 'pending'
        if any(strcmpi(task.status, {'pending', 'ongoing'}))
            return
        end
        cmds = {'MULTI', ...
            ['LREM ' task.status '_tasks 0 ' task_key], ...
            ['LPUSH pending_tasks ' task_key ], ...
            ['HMSET ' task_key ' status pending'], ...
            'EXEC'};
        if strcmpi(task.status, 'ongoing') && strcmpi(force_flag, 'force')
            cmds = [cmds(1:end-1), ...
                {['SREM available_workers ' task.worker], ...
                ['HSET ' task.worker ' status restart']}, ...
                cmds{end}];
        end
        mrc.redis_cmd(cmds)
    case 'finished'
        if strcmpi(task.status, 'finished')
            return
        end
        cmds = {'MULTI', ...
            ['EVALSHA ' script_SHA('update_dependent_tasks') '1 ' task_key], ...
            ['LREM ' task.status '_tasks 0 ' task_key], ...
            ['LPUSH finished_tasks ' task_key ], ...
            ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
            'EXEC'};
        if strcmpi(task.status, 'ongoing') && strcmpi(force_flag, 'force')
            cmds = [cmds(1:end-1), ...
                {['SREM available_workers ' task.worker], ...
                ['HSET ' task.worker ' status restart']}, ...
                cmds{end}];
        end
        mrc.redis_cmd(cmds);
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
                ['HSET ' worker_key ' status restart']});
        end
    case 'kill'
        if ~any(strcmpi(current_status, {'kill', 'dead'}))
            mrc.redis_cmd({['SREM available_workers ' worker_key], ...
                ['HSET ' worker_key ' status kill']});
        end
    case 'dead'
        if ~strcmpi(current_status, 'kill')
            mrc.change_key_status(worker_key, 'kill')
        end
        wait_for_condition(@() strcmpi(get_redis_hash(worker_key, 'status'), 'dead'));
end
end
