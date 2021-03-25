function bool = wait_for_condition(condition_func, time_out)
if ~exist('time_out', 'var')
    time_out = 30; %sec
end
retry_delay = 0.5;

tic
while toc < time_out
    if condition_func()
        bool = true;
        return
    end
    pause(retry_delay)
    retry_delay = retry_delay*2;
end
end

