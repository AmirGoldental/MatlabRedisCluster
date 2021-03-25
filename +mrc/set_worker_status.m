function set_worker_status(worker_key, status, varargin)
% set_worker_status('worker:X', 'active'/'suspended'/'dead')
% set_worker_status({'worker:X','worker:y'}, 'active'/'suspended'/'dead')
% set_worker_status('all_workers', 'active'/'suspended'/'dead')

% DOC
% all possible worker status: active, suspended, restart, dead

if any(strcmpi(varargin, 'wait'))
    wait_flag = true; % used to wait for worker to die
else
    wait_flag = false;
end

if iscell(worker_key)
    for cell_idx = 1:numel(worker_key)
        if ~isempty(worker_key{cell_idx})
            if wait_flag
                mrc.set_worker_status(worker_key{cell_idx}, status, 'wait');
            else
                mrc.set_worker_status(worker_key{cell_idx}, status);
            end
        end
    end
    return
end

worker_key = char(worker_key);
status = char(status);

if strcmpi(worker_key, 'all')
    worker_keys = split(strip(mrc.redis_cmd('SMEMBERS available_workers')));
    worker_keys(cellfun(@isempty, worker_keys)) = [];
    if numel(worker_keys) == 0
        disp('All workers are dead');
        return
    end
    mrc.set_worker_status(worker_keys, status);
    if strcmpi(status, 'dead') && wait_flag
        if wait_for_condition(@() strcmpi(mrc.redis_cmd('SCARD available_workers'), '0'))
            disp('All workers are dead');
        end
    end
    return
end

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
    case 'dead'
        if ~any(strcmpi(current_status, {'kill', 'dead'}))
            mrc.redis_cmd({['SREM available_workers ' worker_key], ...
                ['HSET ' worker_key ' status kill']}); % to do: switch to dead
        end
        if wait_flag
            if wait_for_condition(@() strcmpi(get_redis_hash(worker_key, 'status'), 'dead'))
                disp([worker_key ' is dead']);
            end
        end
    otherwise
        error([status ' status is not supported for workers']);
end
end
