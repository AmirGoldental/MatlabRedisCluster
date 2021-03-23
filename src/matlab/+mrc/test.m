classdef test < matlab.unittest.TestCase
    % runtests('MRCTest'); % in src/matlab
    % check in advance that no other redis / cluster is running
    % with the same configurations
    properties
        main_dir
        mrc_dir
        redis_server_dir
    end
        
    methods
        function obj = test(obj)
            persistent runing
            if isempty(runing)
                runing = true;
                runtests('mrc.test')
            end
            runing = [];
        end
    end
    methods(Test)
        function test_start_worker(testCase)    
            worker_id = testCase.start_worker;
            mrc.test.kill_all_workers;
        end
        
        function test_get_db_timetag_and_flush_db(testCase)    
			mrc.redis_cmd('set db_timetag hello');
			tag = get_db_timetag;
			assert(strcmpi(tag, 'hello'), 'get_db_timetag did not returned current timetag');
			mrc.redis_cmd('set tmp 0');
			mrc.flush_db;
			new_tag = get_db_timetag;			
			assert(~strcmpi(new_tag, tag), 'get_db_timetag was not changed after db reset');
			assert(~strcmpi(mrc.redis_cmd('get tmp'), '0'), 'data stays after db flush');
        end
        
        function test_get_redis_hash(testCase)  
            mrc.redis_cmd('hmset test this that they are it 0');
            mrc.redis_cmd('hmset another they are here 0');
            output = get_redis_hash({});
            assert(isempty(output), 'get_redis_hash empty input did not result in empty output')
            output = get_redis_hash('test');
            assert(strcmpi(output.this, 'that') && strcmpi(output.they, 'are') && strcmpi(output.it, '0'), ...
                    'get_redis_hash wrong result');

            output = get_redis_hash({'test'});
            assert(length(output) == 1, 'get_redis_hash wrong result length');
            output = output{1};
            assert(strcmpi(output.this, 'that') && strcmpi(output.they, 'are') && strcmpi(output.it, '0'), ...
                    'get_redis_hash wrong result');

            output_both = get_redis_hash({'test', 'another'});
            output = output_both{1};
            assert(strcmpi(output.this, 'that') && strcmpi(output.they, 'are') && strcmpi(output.it, '0'), ...
                    'get_redis_hash wrong result');
            output = output_both{2};
            assert(strcmpi(output.they, 'are') && strcmpi(output.here, '0'), 'get_redis_hash wrong result');
            
            output_both = get_redis_hash({'bad', 'test'});
            output = output_both{2};
            assert(strcmpi(output.this, 'that') && strcmpi(output.they, 'are') && strcmpi(output.it, '0'), ...
                    'get_redis_hash wrong result');
                
            output_both = get_redis_hash({'test', 'bad'});
            output = output_both{1};
            assert(strcmpi(output.this, 'that') && strcmpi(output.they, 'are') && strcmpi(output.it, '0'), ...
                    'get_redis_hash wrong result');
                
            output = get_redis_hash({'bad'});
            output = output{1};
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
            output = get_redis_hash('bad'); 
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
        end

        function test_set_redis_hash(testCase)  
            mrc.flush_db;
            simple_struct = struct('a', 'hello\there', 'b', 'b', 'dont', 'mess', 'with_the', 'zohan');
            another_struct = struct('b', '1', 'a', '2');
            set_redis_hash('empty', struct());   
            assert_equal_hash(struct, 'empty');
            set_redis_hash('simple', simple_struct);       
            assert_equal_hash(simple_struct, 'simple');
            set_redis_hash('another', another_struct);            
            assert_equal_hash(another_struct, 'another');
            mrc.flush_db;
            set_redis_hash({'simple', 'another'}, {simple_struct, another_struct});       
            assert_equal_hash(simple_struct, 'simple');
            assert_equal_hash(another_struct, 'another');
            set_redis_hash({'empty', 'another'}, {struct(), another_struct});
            assert_equal_hash(another_struct, 'another');
            function assert_equal_hash(s, name)
                output = get_redis_hash(name);
                output_keys = fieldnames(output);
                output_vals = cellfun(@(x) {char(x)}, struct2cell(output));
                assert(all(strcmp(output_keys, fieldnames(s))), ['set_redis_hash bad values on ' name])
                assert(all(strcmp(output_vals, struct2cell(s))), ['set_redis_hash bad keys on ' name])
            end
        end
    end
    
    methods(TestClassSetup)
        function start_redis(testCase)
            disp('Start setup for tests')
            testCase.main_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
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
            disp('Start teardown of tests')
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