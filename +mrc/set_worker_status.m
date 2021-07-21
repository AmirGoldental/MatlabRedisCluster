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
if strcmpi(worker_key, 'all')
    worker_keys = mrc.redis().smembers('available_workers');
    worker_keys(cellfun(@isempty, worker_keys)) = [];
    if numel(worker_keys) == 0
        disp('No available workers');
        return
    end
    mrc.set_worker_status(worker_keys, status);
    return
end

current_status = mrc.redis().hget(worker_key, 'status');
switch status
    case 'restart'        
        if any(strcmpi(current_status, {'active'}))
            mrc.redis().srem('available_workers', worker_key);
            server_key = mrc.redis().hget(worker_key, 'server_key');
            mrc.redis().lpush([server_key ':cmd'], ['restart ' worker_key]);
        end
    case 'dead'
        if ~strcmpi(current_status, 'dead')
            mrc.redis().srem('available_workers', worker_key);
            server_key = mrc.redis().hget(worker_key, 'server_key');
            mrc.redis().lpush([server_key ':cmd'], ['kill ' worker_key]);
        end
    otherwise
        error([status ' status is not supported for workers']);
end
end
