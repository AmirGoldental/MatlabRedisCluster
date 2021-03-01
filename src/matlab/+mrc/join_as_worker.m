function join_as_worker(worker_id)
db_id = get_db_id();
worker = struct();

if exist('worker_id', 'var')
    worker_key = ['worker:' worker_id];
else
    worker_key = ['worker:' mrc.redis_cmd('incr workers_count')];    
end

worker.started_on = datetime();
mrc_dir = fileparts(fileparts(mfilename('fullpath')));
system(['start "worker_watcher" /D "' mrc_dir ...
    '" matlab_worker_watcher.bat mrc_client.conf ' worker_key ' ' ...
    num2str(feature('getpid'))]);

worker.status = 'active';
worker.computer = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
worker.current_task = 'None';
worker.last_command = 'None';
worker.key = worker_key;
set_redis_hash(worker_key, worker);
disp(worker)

clear functions;
clear global;
restoredefaultpath
fclose all;
close all;

conf = mrc.read_conf_file;
if ~isfolder(conf.log_path)
    mkdir(conf.log_path);
end

if strcmpi(conf.show_close_figure, 'true')
    worker_fig = worker_figure(worker_key, -1);
end

get_worker_status = @() mrc.redis_cmd(['HGET ' worker_key ' status']);

while strcmp(get_worker_status(), 'active')
    perform_task(worker_key, db_id, conf.log_path)    
    if strcmpi(conf.show_close_figure, 'true')
        worker_fig = worker_figure(worker_key, worker_fig);
    end
end
if strcmpi(conf.show_close_figure, 'true') && ishandle(worker_fig)
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

function perform_task(worker_key, db_id, log_file)
if ~strcmp(db_id, get_db_id())
    return
end
lua_script = ['"' ...
    'if redis.call(''LLEN'', ''pending_tasks'') == 0 then return '''' end;' ...
    'local worker_key = KEYS[1];' ...
    'local time_str = KEYS[2];' ...
    'local task_key = redis.call(''LPOP'', ''pending_tasks'');' ...
    'local task_cmd = redis.call(''HGET'', task_key, ''command'');' ...
    'redis.call(''RPUSH'', ''ongoing_tasks'', task_key);' ...
    'redis.call(''HMSET'', task_key, ''status'', ''ongoing'', ' ...
    '''started_on'', time_str, ''worker'', worker_key);' ...
    'redis.call(''HMSET'', worker_key, ''current_task'', task_key, ' ...
    '''last_command'', task_cmd);' ...
    'return task_key;' ...
    '" 2'];
redis_cmd = ['eval ' lua_script ' ' worker_key ' ' str_to_redis_str(datetime)];
task_key = mrc.redis_cmd(redis_cmd);

if isempty(task_key)
    pause(3)
    return
end

task = get_redis_hash(task_key);

% Start logging:
diary(fullfile(log_file, strrep([task_key '_' worker_key '_' datestr(now, 30) '.txt'], ':', '-')));

disp(task)

try
    % Perform the task
    if ~strcmpi(task.path2add, 'None')
        addpath(task.path2add)
    end
    eval(task.command)
    if strcmp(db_id, get_db_id())
        mrc.redis_cmd({'MULTI', ...
            ['LREM ongoing_tasks 0 ' task_key], ...
            ['LPUSH finished_tasks ' task_key ], ...
            ['HMSET ' task_key ' finished_on ' str_to_redis_str(datetime) ' status finished'], ...
            'EXEC'});
    end
    disp(['    finished_on ' str_to_redis_str(datetime) ])
    disp('')
catch err
    json_err = jsonencode(err);
    json_err = join(split(json_err, ','), ',\n');
    
    if strcmp(db_id, get_db_id())
        mrc.redis_cmd({'MULTI', ...
            ['LREM ongoing_tasks 0 ' task_key], ...
            ['LPUSH failed_tasks ' task_key ], ...
            ['HMSET ' task_key ' failed_on ' str_to_redis_str(datetime) ...
            ' err_msg ' str_to_redis_str(json_err) ' status failed'], ...
            'EXEC'});
    end
    disp(['    failed_on ' str_to_redis_str(datetime) ])
    disp('')
    disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
end


if strcmp(db_id, get_db_id())
    mrc.redis_cmd(['HSET ' worker_key ' current_task None']);
end

diary off

clear functions;
clear global;
restoredefaultpath
fclose all;
close all;
end


