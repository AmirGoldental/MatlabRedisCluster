
% preconditions
% start redis server
main_dir = fileparts(mfilename('fullpath'));
mrr_dir = fullfile(main_dir, 'matlab');
redis_server_dir = fullfile(main_dir, 'redis_server');
addpath(mrr_dir)

%% Test 1: test redis command failed
try
    mrr.redis_cmd('ping');
    error('found redis server before initialization, check for other processes');
catch err    
end

%% Test 2: test redis server init
system(['start "redis_server" /D "' redis_server_dir '" redis-server.bat']);
for i = 1:10
    output = 'wrong';
    try
        output = mrr.redis_cmd('ping');
        break
    catch
    end
    pause(1);
end
assert(strcmpi(output, 'pong'), 'could not find redis server after initialization');

%% Test 3: flushdb
mrr.redis_cmd('set tmp 1');
output = mrr.redis_cmd('get tmp');
assert(strcmpi(output, '1'), 'could not find simple set tmp val in redis');
mrr.flush_db;
output = mrr.redis_cmd('get tmp');
assert(isempty(output), 'flush_db did not delete simple tmp val in redis');

%% Test 4: worker simple tests
system(['start "worker" /D "' mrr_dir '" matlab_worker.bat']);
for i = 1:10
    worker = mrr.redis_cmd('keys worker:*');
    if ~isempty(worker)
        break
    end
    pause(1);    
end
assert(~isempty(worker), 'worker start and join failed');

% worker restart
last_worker = worker;
mrr.redis_cmd(['hset ' worker ' status restart']);
for i = 1:10
    workers = sort(strsplit(mrr.redis_cmd('keys worker:*')));
    if length(workers) == 2
        worker = workers{end};
        break
    end
    pause(1);    
end
output = mrr.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'worker restart failed');
output = mrr.redis_cmd(['hget ' worker ' status']);
assert(strcmpi(output, 'active'), 'worker restart failed');

% simple task
task = mrr.new_task('disp hey');
for i = 1:10
    output = mrr.redis_cmd(['hget ' task.key ' status']);
    if strcmpi(output, 'finished')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'finished'), 'simple task failed');

% simple failed task
task = mrr.new_task('error failed');
for i = 1:10
    output = mrr.redis_cmd(['hget ' task.key ' status']);
    if strcmpi(output, 'failed')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'failed'), 'simple failed task failed');

% simple failed task restart
task = mrr.new_task('exit');
last_worker = worker;
for i = 1:10
    workers = sort(strsplit(mrr.redis_cmd('keys worker:*')));
    if length(workers) == 3
        worker = workers{end};
        break
    end
    pause(1);    
end
output = mrr.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'simple failed task restart failed');
output = mrr.redis_cmd(['hget ' worker ' status']);
assert(strcmpi(output, 'active'), 'simple failed task restart failed');
output = mrr.redis_cmd(['hget ' task.key ' status']);
assert(strcmpi(output, 'failed'), 'simple failed task restart failed');

% worker kill
mrr.redis_cmd(['hset ' worker ' status kill']);
for i = 1:10
    output = mrr.redis_cmd(['hget ' worker ' status']);
    if strcmpi(output, 'dead')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'dead'), 'worker kill failed');

% kill redis server at the end
[val, msg] = system('taskkill /f /t /fi "windowtitle eq redis_server"');