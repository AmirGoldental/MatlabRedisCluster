function join_as_worker()
worker = struct();
worker_key = ['worker:' mrr.redis_cmd('incr matlab_workers_count')];
worker.started_on = datetime();

mrr_dir = fileparts(fileparts(mfilename('fullpath')));
system(['start "worker_watcher" /D "' mrr_dir ...
    '" matlab_worker_watcher.bat mrr_client.conf ' worker_key ' ' ...
    num2str(feature('getpid'))]);

worker.status = 'active';
worker.computer = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
worker.current_task = 'None';
worker.last_command = 'None';
worker_str = [];
for field = fieldnames(worker)'
    worker_str = [worker_str ' ' field{1} ' ' str_to_redis_str(worker.(field{1}))];
end
mrr.redis_cmd(['HMSET ' worker_key ' ' worker_str]);

Hndl = worker_figure(worker_key);

get_worker_status = @() mrr.redis_cmd(['HGET ' worker_key ' status']);

while strcmp(get_worker_status(), 'active')
    task_key = mrr.redis_cmd('RPOPLPUSH pending_matlab_tasks ongoing_matlab_tasks');
    
    if isempty(task_key)
        pause(3)
    else
        clear functions
        clear global
        
        preform_task(worker_key, task_key)
        
        fclose all;
        close all
        
        Hndl = worker_figure(worker_key);
       
    end
end
if ishandle(Hndl)
    close(Hndl)
end
end

function Hndl = worker_figure(worker_key)
Hndl = figure('MenuBar', 'none', 'Name', worker_key,...
    'NumberTitle' ,'off', 'Units', 'normalized');
uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized',...
    'Position', [0.01 0.01 0.98 0.98], 'String', ['Kill ' worker_key],...
    'Callback', @(~,~) mrr.redis_cmd(['HSET ' worker_key ' status kill']),...
    'FontSize', 16, 'FontName', 'Consolas', 'ForegroundColor' ,'r')
drawnow
end

function preform_task(worker_key, task_key)

task = struct();
task.command = mrr.redis_cmd(['HGET ' task_key ' command']);
task.created_by = mrr.redis_cmd(['HGET ' task_key ' created_by']);
task.created_on = mrr.redis_cmd(['HGET ' task_key ' created_on']);
disp(task)

% Update task
mrr.redis_cmd(['HMSET ' task_key ' started_on ' str_to_redis_str(datetime) ...
    ' worker ' worker_key ' status ongoing']);

% Update worker
mrr.redis_cmd(['HMSET ' worker_key ' current_task ' task_key ' last_command ' str_to_redis_str(task.command)]);

try
    eval(task.command)
    mrr.redis_cmd(['LREM ongoing_tasks 0 ' task_key]);
    mrr.redis_cmd(['SADD finished_tasks ' task_key ]);
    mrr.redis_cmd(['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ...
        ' status finished']);
catch err
    mrr.redis_cmd(['LREM ongoing_tasks 0 ' task_key]);
    mrr.redis_cmd(['SADD failed_tasks ' task_key ]);
    mrr.redis_cmd(['HMSET ' task_key ' failed_on ' str_to_redis_str(datetime) ...
        ' err_msg ' str_to_redis_str(jsonencode(err)) ...
        ' status failed']);
    disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
end

mrr.redis_cmd(['HSET ' worker_key ' current_task None']);

end
