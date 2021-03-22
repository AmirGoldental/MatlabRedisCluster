function suspend_workers(worker_keys)
if ~exist('worker_keys', 'var')
    worker_ids = 1:redis_str2double(mrc.redis_cmd('GET workers_count'));
    worker_keys = arrayfun(@(worker_id) ['worker:' num2str(worker_id)], worker_ids, 'UniformOutput', false);
end
if ~iscell(worker_keys)
    worker_keys = {worker_keys};
end
for worker_key = worker_keys(:)'
    if strcmpi(mrc.redis_cmd(['HGET ' char(worker_key{1}) ' status']), 'active')
        mrc.redis_cmd(['HSET ' char(worker_key{1}) ' status suspended']);
    end
end
end

function output = redis_str2double(input)
    input = strip(input);
    if isempty(input)
        output = 0;
    else
        output = str2double(input);
    end
end