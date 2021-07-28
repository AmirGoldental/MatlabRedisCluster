function join_as_worker(worker_key)
db_timetag = get_db_timetag();
mrc.redis('reconnect');

worker = struct();
if ~exist('worker_key', 'var')
    worker_key = ['worker:' mrc.redis().incr('workers_count')];    
end

worker.started_on = datetime();
worker.status = 'active';
worker.computer = [getenv('COMPUTERNAME'), '/', getenv('USERNAME')];
worker.server_key = ['server:' lower(getenv('COMPUTERNAME'))];
worker.current_task = 'None';
worker.last_command = 'None';
worker.pid = feature('getpid');
worker.last_ping = datetime();

worker.key = worker_key;
set_redis_hash(worker_key, worker);
mrc.redis().sadd('available_workers', worker_key);
mrc.redis().sadd([worker.server_key ':workers'], worker_key);
disp(worker)

clear functions;
clear global;
restoredefaultpath
mrc_path = fileparts(fileparts(mfilename('fullpath')));
addpath(mrc_path);
fclose all;
close all;

conf = read_conf_file;
if ~isfolder(conf.log_path)
    mkdir(conf.log_path);
end

if strcmpi(conf.show_close_figure, 'true')
    worker_fig = worker_figure(worker_key, -1);
end

mrc.redis('reconnect');
worker_status = mrc.redis().hget(worker_key, 'status');
while any(strcmp(worker_status, {'active'}))
    mrc.redis('reconnect');
    perform_task(worker_key, db_timetag, conf.log_path)    
    if strcmpi(conf.show_close_figure, 'true')
        worker_fig = worker_figure(worker_key, worker_fig);
    end
    worker_status = mrc.redis().hget(worker_key, 'status');
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
    'Callback', @(~,~) mrc.set_worker_status(worker_key, 'kill'),...
    'FontSize', 16, 'FontName', 'Consolas', 'ForegroundColor' ,'r')
drawnow
end

function perform_task(worker_key, db_timetag, log_path)
if ~strcmp(db_timetag, get_db_timetag())
    exit;
end
task_key = lua_script('worker_pop_pendnig_task', 2, worker_key, str_to_redis_str(datetime));

if isempty(task_key)
    pause(3)
    return
end

task = get_redis_hash(task_key);

% Start logging:
mrc_path = fileparts(fileparts(mfilename('fullpath')));
diary(fullfile(mrc_path, log_path, strrep(['DB_' db_timetag '_' task_key '_' worker_key '.txt'], ':', '-')));

disp(' --- ')
disp(task)

try
    % Perform the task
    if ~strcmpi(task.path2add, 'None')
        addpath(task.path2add)
        disp(['>> addpath(''' char(task.path2add) ''')']);
    end
    disp(['>> ' char(task.command)]);
    eval(task.command)
    if strcmp(db_timetag, get_db_timetag())
        mrc.set_task_status(task_key, 'finished');
    end
    disp([newline '   finished_on: ' str_to_redis_str(datetime) ])
catch err
    json_err = jsonencode(err);
    json_err = join(split(json_err, ','), ',\n');
    set_redis_hash(task_key, 'err_msg', json_err)
    if strcmp(db_timetag, get_db_timetag())
        mrc.set_task_status(task_key, 'failed');
    end
    disp([newline '   failed_on: ' str_to_redis_str(datetime) ])
    disp(['[ERROR] ' datestr(now, 'yyyy-mm-dd HH:MM:SS') ' : ' jsonencode(err)])
end


if strcmp(db_timetag, get_db_timetag())
    mrc.redis().hset(worker_key, 'current_task',  'None');
end

diary off

clear functions;
clear global;
restoredefaultpath
mrc_path = fileparts(fileparts(mfilename('fullpath')));
addpath(mrc_path);
fclose all;
close all;
end


