classdef test < matlab.unittest.TestCase
    % runtests('mrc.test'); % in src/matlab
    % check in advance that no other redis / cluster is running
    % with the same configurations
    properties
        main_dir
        mrc_dir
        redis_server_dir
    end
        
    methods(Test)
		test_example(testCase);
    end
    
    methods(TestClassSetup)
        function start_redis(testCase)
            testCase.main_dir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
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
            output = mrc.test.wait_for_cond(@() mrc.redis_cmd('ping'), @(x) strcmpi(x, 'pong'), 1, 10);
            assert(output, 'could not find redis server after initialization');
            mrc.flush_db;
        end
    end
    
    methods(TestClassTeardown)        
        function close_redis(testCase)
            mrc.test.kill_all_workers;
            disp('close redis')
            [val, msg] = system('taskkill /f /t /fi "windowtitle eq redis_server"');
        end        
    end
    
    methods        
        function new_worker_id = start_worker(testCase)            
            n_workers_before = length(mrc.test.get_list_of_workers);
                
            system(['start "worker" /D "' testCase.mrc_dir '" start_matlab_worker.bat']);
            [output, workers] = mrc.test.wait_for_cond(@() mrc.test.get_list_of_workers, @(x) length(x) == n_workers_before + 1, 1, 30);
            assert(output, 'worker start and join failed');
            worker_ids = str2double(cellfun(@(x) {strrep(x, 'worker:', '')}, workers));
            new_worker_id = ['worker:' num2str(worker_ids(end))]; 
            output = mrc.test.wait_for_cond(@() mrc.redis_cmd(['hget ' new_worker_id ' status']), @(x) strcmpi(x, 'active'), 1, 30);
            assert(output, 'new worker initialization failed');
        end
    end

    methods(Static)        
        function kill_all_workers
            disp('kill all workers')
            workers = mrc.test.get_list_of_workers;
            for ind = 1:length(workers)
                res = mrc.redis_cmd(['hget ' char(workers{ind}) ' status']);
                if strcmpi(res, 'active')
                    mrc.redis_cmd(['hset ' char(workers{ind}) ' status kill']);
                end
            end
            
            for ind = 1:length(workers)
                output = mrc.test.wait_for_cond(@() mrc.redis_cmd(['hget ' char(workers{ind}) ' status']), ...
                            @(x) ~strcmpi(x, 'kill'), 1, 30);
                assert(output, ['could not kill worker ' workers{ind}])
            end
        end
        
        function workers = get_list_of_workers
            workers = mrc.redis_cmd('keys worker:*');
            if isempty(workers)
                workers = {};
            else
                workers = strsplit(workers);
            end            
        end
        
        function [res, func_res] = wait_for_cond(func, cond, pace, interval)
            res = true;
            func_res = [];
            for i = 0:pace:(interval - 1)
                func_res = func();
                if cond(func_res)
                    return
                end
                pause(pace);
            end
            res = false;
            % error(['condition ' char(cond) ' was not met on ' char(func) ' after interval ' num2str(interval)]);
        end
    end
end