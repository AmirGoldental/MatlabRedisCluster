function wait(keys)

for key = keys
    task = get_redis_hash(key{1});
    if strcmpi(task.fail_policy, 'continue')
        status_to_continue = {'finished', 'failed'};
    else
        status_to_continue = {'finished'};
    end
    task_status = task.status;
    while ~any(strcmpi(task_status, status_to_continue))
        pause(3)
        task_status = mrc.redis_cmd(['HGET ' key{1} ' status']);
    end
end

end