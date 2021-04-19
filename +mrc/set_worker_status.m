function set_worker_status(worker_key, status)
% set_worker_status('worker:X', 'active'/'suspended'/'dead')
% set_worker_status({'worker:X','worker:y'}, 'active'/'suspended'/'dead')
% set_worker_status('all_workers', 'active'/'suspended'/'dead')

% DOC
% all possible worker status: active, suspended, restart, dead

if iscell(worker_key)
    for cell_idx = 1:numel(worker_key)
        if ~isempty(worker_key{cell_idx})
            mrc.set_worker_status(worker_key{cell_idx}, status);
        end
    end
    return
end

worker_key = char(worker_key);
status = char(status);
r = get_redis_connection;
if strcmpi(worker_key, 'all')
    worker_keys = r.smembers('available_workers');
    worker_keys(cellfun(@isempty, worker_keys)) = [];
    if numel(worker_keys) == 0
        disp('No available workers');
        return
    end
    mrc.set_worker_status(worker_keys, status);
    return
end

current_status = r.hget(worker_key, 'status');
switch status
    case 'active'
        if strcmpi(current_status, 'suspended')
            r.srem('available_workers', worker_key);
            r.lpush([worker_key ':watcher_cmds'], 'wakeup');
        end
    case 'suspended'
        if strcmpi(current_status, 'active')
            r.lpush([worker_key ':watcher_cmds'], 'suspend');
        end
    case 'restart'        
        if any(strcmpi(current_status, {'active','suspended'}))
            r.srem('available_workers', worker_key);
            r.lpush([worker_key ':watcher_cmds'], 'restart');
        end
    case 'dead'
        if ~strcmpi(current_status, 'dead')
            r.srem('available_workers', worker_key);
            r.lpush([worker_key ':watcher_cmds'],  'kill');
        end
    otherwise
        error([status ' status is not supported for workers']);
end
end
