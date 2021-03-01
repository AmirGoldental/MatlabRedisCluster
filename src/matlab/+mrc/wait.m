function wait(keys)

for key = keys
    task_status = mrc.redis_cmd(['HGET ' key{1} ' status']);
    while any(strcmpi(task_status,{'pending', 'ongoing'}))
        pause(3)
        task_status = mrc.redis_cmd(['HGET ' key{1} ' status']);
    end
end

end