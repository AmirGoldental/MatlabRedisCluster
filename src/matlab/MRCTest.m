classdef MRCTest < matlab.unittest.TestCase
    % runtests('MRCTest'); % in src/matlab
    % check in advance that no other redis / cluster is running
    % with the same configurations
    properties
        main_dir
        mrc_dir
        redis_server_dir
    end
    
    methods(TestClassSetup)
        function start_redis(testCase)
            testCase.main_dir = fileparts(fileparts(mfilename('fullpath')));
            testCase.mrc_dir = fullfile(testCase.main_dir, 'matlab');
            testCase.redis_server_dir = fullfile(testCase.main_dir, 'redis_server');
            addpath(testCase.mrc_dir)

            disp('test redis null access')
            try
                mrc.redis_cmd('ping');
                error('found redis server before initialization, check for other processes');
            catch err    
            end
            disp('start redis server')
            system(['start "redis_server" /D "' testCase.redis_server_dir '" start_mrc_server.bat']);
            output = MRCTest.wait_for_cond(@() mrc.redis_cmd('ping'), @(x) strcmpi(x, 'pong'), 1, 10);
            assert(output, 'could not find redis server after initialization');
        end
        function reset_redis(testCase)
            disp('reset redis server')
            mrc.redis_cmd('set tmp 1');
            output = mrc.redis_cmd('get tmp');
            assert(strcmpi(output, '1'), 'could not find simple set tmp val in redis');
            mrc.flush_db;
            output = mrc.redis_cmd('get tmp');
            assert(isempty(output), 'flush_db did not delete simple tmp val in redis');
        end
        function start_pod(testCase)
        end
    end
    
    methods(TestClassTeardown)        
        function close_redis(testCase)
            disp('close redis')
            [val, msg] = system('taskkill /f /t /fi "windowtitle eq redis_server"');
        end
        
        function kill_all_workers(testCase)
            disp('kill all workers')
            workers = mrc.redis_cmd('keys worker*');
            for ind = 1:length(workers)
                res = mrc.redis_cmd(['hget ' char(workers{ind}) ' status']);
                if strcmpi(res{1}, 'active')
                    mrc.redis_cmd(['hset ' char(workers{ind}) ' status kill']);
                end
            end
            
            for ind = 1:length(workers)
                output = MRCTest.wait_for_cond(@() mrc.redis_cmd(['hget ' char(workers{ind}) ' status']), ...
                            @(x) ~strcmpi(x, 'kill'), 1, 30);
                assert(output, ['could not kill worker ' workers{ind}])
            end
        end
    end
    
    
    methods(Test)
        function defaultCurrentPoint(testCase)
        end
    end

    methods(Static)
        function [res, func_res] = wait_for_cond(func, cond, pace, interval)
            res = true;
            func_res = [];
            for i = 0:pace:(interval - 1)
                func_res = func();
                if cond(func_res)
                    return
                end
            end
            res = false;
            % error(['condition ' char(cond) ' was not met on ' char(func) ' after interval ' num2str(interval)]);
        end
    end
end