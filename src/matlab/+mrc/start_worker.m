function start_worker(varargin)
workers_count = mrc.redis_cmd('get workers_count');
if isempty(workers_count)
    workers_count = 0;
else
    workers_count = str2double(workers_count);
end
new_worker = ['worker:' num2str(workers_count+1)];
system(['start "' new_worker '" /D "' fileparts(fileparts(mfilename('fullpath'))) '" start_matlab_worker.bat']);

if any(strcmpi(varargin, 'wait'))
    tic
    while toc < 30
        if strcmpi(get_redis_hash(new_worker, 'status'), 'active')
            disp([new_worker ' is active!']);
            return
        end
        pause(2);
    end
end
end

