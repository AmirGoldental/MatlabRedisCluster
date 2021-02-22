
% preconditions
% start redis server
main_dir = fileparts(mfilename('fullpath'));
mrc_dir = fullfile(main_dir, 'matlab');
redis_server_dir = fullfile(main_dir, 'redis_server');
addpath(mrc_dir)

%% Test 1: test redis command failed
try
    mrc.redis_cmd('ping');
    error('found redis server before initialization, check for other processes');
catch err    
end

%% Test 2: test redis server init
system(['start "redis_server" /D "' redis_server_dir '" start_mrc_server.bat']);
for i = 1:10
    output = 'wrong';
    try
        output = mrc.redis_cmd('ping');
        break
    catch
    end
    pause(1);
end
assert(strcmpi(output, 'pong'), 'could not find redis server after initialization');

%% Test 3: flushdb
mrc.redis_cmd('set tmp 1');
output = mrc.redis_cmd('get tmp');
assert(strcmpi(output, '1'), 'could not find simple set tmp val in redis');
mrc.flush_db;
output = mrc.redis_cmd('get tmp');
assert(isempty(output), 'flush_db did not delete simple tmp val in redis');

%% Test 4: worker simple tests
system(['start "worker" /D "' mrc_dir '" start_matlab_worker.bat']);
for i = 1:10
    worker = mrc.redis_cmd('keys worker:*');
    if ~isempty(worker)
        break
    end
    pause(1);    
end
assert(~isempty(worker), 'worker start and join failed');

% worker restart
last_worker = worker;
mrc.redis_cmd(['hset ' worker ' status restart']);
for i = 1:10
    workers = sort(strsplit(mrc.redis_cmd('keys worker:*')));
    if length(workers) == 2
        worker = workers{end};
        break
    end
    pause(1);    
end
output = mrc.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'worker restart failed');
output = mrc.redis_cmd(['hget ' worker ' status']);
assert(strcmpi(output, 'active'), 'worker restart failed');

% simple task
task = mrc.new_task('disp hey');
for i = 1:10
    output = mrc.redis_cmd(['hget ' task.key ' status']);
    if strcmpi(output, 'finished')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'finished'), 'simple task failed');

% simple failed task
task = mrc.new_task('error failed');
for i = 1:10
    output = mrc.redis_cmd(['hget ' task.key ' status']);
    if strcmpi(output, 'failed')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'failed'), 'simple failed task failed');

% simple failed task restart
task = mrc.new_task('exit');
last_worker = worker;
for i = 1:10
    workers = sort(strsplit(mrc.redis_cmd('keys worker:*')));
    if length(workers) == 3
        worker = workers{end};
        break
    end
    pause(1);    
end
output = mrc.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'simple failed task restart failed');
output = mrc.redis_cmd(['hget ' worker ' status']);
assert(strcmpi(output, 'active'), 'simple failed task restart failed');
output = mrc.redis_cmd(['hget ' task.key ' status']);
assert(strcmpi(output, 'failed'), 'simple failed task restart failed');

% worker kill
mrc.redis_cmd(['hset ' worker ' status kill']);
for i = 1:10
    output = mrc.redis_cmd(['hget ' worker ' status']);
    if strcmpi(output, 'dead')
        break
    end
    pause(1);    
end
assert(strcmpi(output, 'dead'), 'worker kill failed');

% kill redis server at the end
[val, msg] = system('taskkill /f /t /fi "windowtitle eq redis_server"');