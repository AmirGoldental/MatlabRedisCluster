
% preconditions
% start redis server
main_dir = fileparts(fileparts(mfilename('fullpath')));
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
output = test.wait_for_cond(@() mrc.redis_cmd('ping'), @(x) strcmpi(x, 'pong'), 1, 10);
assert(output, 'could not find redis server after initialization');

%% Test 3: flushdb
mrc.redis_cmd('set tmp 1');
output = mrc.redis_cmd('get tmp');
assert(strcmpi(output, '1'), 'could not find simple set tmp val in redis');
mrc.flush_db;
output = mrc.redis_cmd('get tmp');
assert(isempty(output), 'flush_db did not delete simple tmp val in redis');

%% Test 4: worker simple tests
system(['start "worker" /D "' mrc_dir '" start_matlab_worker.bat']);
[output, workers] = test.wait_for_cond(@() mrc.redis_cmd('keys worker:*'), @(x) ~isempty(x), 1, 30);
assert(output, 'worker start and join failed');

% worker restart
last_worker = workers{1};
mrc.redis_cmd(['hset ' last_worker ' status restart']);
[output, workers] = test.wait_for_cond(@() mrc.redis_cmd('keys worker:*'), @(x) length(x) == 2, 1, 30);
assert(output, 'worker restart failed');
workers = workers(cellfun(@(x) ~strcmpi(x, last_worker), workers));
current_worker = workers{1};
output = mrc.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'worker restart failed');
output = mrc.redis_cmd(['hget ' current_worker ' status']);
assert(strcmpi(output, 'active'), 'worker restart failed');

% simple task
task = mrc.new_task('disp hey');
output = test.wait_for_cond(@() mrc.redis_cmd(['hget ' task.key ' status']), @(x) strcmpi(x, 'finished'), 1, 30);
assert(output, 'simple task failed');

% simple failed task
task = mrc.new_task('error failed');
output = test.wait_for_cond(@() mrc.redis_cmd(['hget ' task.key ' status']), @(x) strcmpi(x, 'failed'), 1, 30);
assert(output, 'simple failed task failed');

% simple failed task restart
last_worker = current_worker;
task = mrc.new_task('exit');
[output, workers] = test.wait_for_cond(@() sort(strsplit(mrc.redis_cmd('keys worker:*'))), @(x) length(x) == 3, 1, 30);
assert(output, 'simple failed task restart failed');
current_worker = workers{end};
output = mrc.redis_cmd(['hget ' last_worker ' status']);
assert(strcmpi(output, 'dead'), 'simple failed task restart failed');
output = mrc.redis_cmd(['hget ' current_worker ' status']);
assert(strcmpi(output, 'active'), 'simple failed task restart failed');
output = mrc.redis_cmd(['hget ' task.key ' status']);
assert(strcmpi(output, 'failed'), 'simple failed task restart failed');

% worker kill
mrc.redis_cmd(['hset ' worker ' status kill']);
output = test.wait_for_cond(@() mrc.redis_cmd(['hget ' worker ' status']), @(x) strcmpi(x, 'dead'), 1, 30);
assert(output, 'worker kill failed');

% kill redis server at the end
[val, msg] = system('taskkill /f /t /fi "windowtitle eq redis_server"');