function join_as_worker()
worker = struct();
worker_key = ['worker:' mrc.redis_cmd('incr matlab_workers_count')];
worker.started_on = datetime();

mrc_dir = fileparts(fileparts(mfilename('fullpath')));
system(['start "worker_watcher" /D "' mrc_dir ...
    '" matlab_worker_watcher.bat mrc_client.conf ' worker_key ' ' ...
    num2str(feature('getpid'))]);

worker.status = 'active';
worker.computer = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
worker.current_task = 'None';
worker.last_command = 'None';
set_redis_hash(worker_key, worker)

clear functions;
clear global;
restoredefaultpath
fclose all;
close all;

worker_fig = worker_figure(worker_key, -1);

conf = mrc.read_conf_file;
if ~isfolder(conf.log_path)
    mkdir(conf.log_path);
end

get_worker_status = @() mrc.redis_cmd(['HGET ' worker_key ' status']);

while strcmp(get_worker_status(), 'active')
    perform_task(worker_key, conf.log_path)
    worker_fig = worker_figure(worker_key, worker_fig);
end
if ishandle(worker_fig)
    close(worker_fig)
end

end
function worker_fig = worker_figure(worker_key, worker_fig)
if ishandle(worker_fig)
    return
end

worker_fig = figure('MenuBar', 'none', 'Name', worker_key,...
    'NumberTitle' ,'off', 'Units', 'normalized');
uicontrol(worker_fig, 'Style', 'pushbutton', 'Units', 'normalized',...
    'Position', [0.01 0.01 0.98 0.98], 'String', ['Kill ' worker_key],...
    'Callback', @(~,~) mrc.redis_cmd(['HSET ' worker_key ' status kill']),...
    'FontSize', 16, 'FontName', 'Consolas', 'ForegroundColor' ,'r')
drawnow
end

function perform_task(worker_key, log_file)

task_key = mrc.redis_cmd('LPOPRPUSH pending_tasks ongoing_tasks');

if isempty(task_key)
    pause(3)
    return
end

task = get_redis_hash(task_key);

% Update task and worker
mrc.redis_cmd({['HMSET ' task_key ...
    ' started_on ' str_to_redis_str(datetime) ...
    ' worker ' worker_key ' status ongoing'], ...
    ['HMSET ' worker_key  ...
    ' current_task ' task_key ...
    ' last_command ' str_to_redis_str(task.command)]});


% Start logging:
diary(fullfile(log_file, strrep([task_key '_' worker_key '_' datestr(now, 30) '.txt'], ':', '-')));

disp(task)

try
    % Perform the task
    if ~strcmpi(task.path2add, 'None')
        addpath(task.path2add)
    end
    eval(task.command)
    mrc.redis_cmd({'MULTI', ...
        ['LREM ongoing_tasks 0 ' task_key], ...
        ['LPUSH finished_tasks ' task_key ], ...
        ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
        'EXEC'});
    disp(['    finished_on ' str_to_redis_str(datetime) ])
    disp('')
catch err
    json_err = jsonencode(err);
    json_err = join(split(json_err, ','), ',\n');
    
    mrc.redis_cmd({'MULTI', ...
        ['LREM ongoing_tasks 0 ' task_key], ...
        ['LPUSH failed_tasks ' task_key ], ...
        ['HMSET ' task_key ' failed_on ' str_to_redis_str(datetime) ...
        ' err_msg ' str_to_redis_str(json_err) ' status failed'], ...
        'EXEC'});
    disp(['    failed_on ' str_to_redis_str(datetime) ])
    disp('')
    disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
end

mrc.redis_cmd(['HSET ' worker_key ' current_task None']);

diary off

clear functions;
clear global;
restoredefaultpath
fclose all;
close all;
end


