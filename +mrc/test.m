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
        function test_get_db_timetag_and_flush_db(testCase)    
			mrc.redis_cmd('set db_timetag hello');
			tag = get_db_timetag;
			mrc.redis_cmd('set tmp a');
			mrc.flush_db;
			new_tag = get_db_timetag;			
			assert(~strcmpi(new_tag, tag), 'get_db_timetag was not changed after db reset');
			assert(~strcmpi(mrc.redis_cmd('get tmp'), 'a'), 'data stays after db flush');
        end
        
        function test_get_redis_hash(testCase)  
            output = get_redis_hash({});
            assert(isempty(output), 'get_redis_hash empty input did not result in empty output')
            mrc.redis_cmd('hmset test_hash field1 value1 field2 value2 field3_numeric 0');
            mrc.redis_cmd('hmset test_hash2 field1 value3 field2_numeric 1');
            output = get_redis_hash('test_hash');
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');

            output = get_redis_hash({'test_hash'});
            assert(length(output) == 1, 'get_redis_hash wrong result length');
            output = output{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');

            output_both = get_redis_hash({'test_hash', 'test_hash2'});
            output = output_both{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');
            output = output_both{2};
            assert(...
                strcmpi(output.field1, 'value3') && ...
                strcmpi(output.field2_numeric, '1'), ...
                'get_redis_hash wrong result');
            
            output_both = get_redis_hash({'bad_hash', 'test_hash'});
            output = output_both{2};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');
                
            output_both = get_redis_hash({'test_hash', 'bad_hash'});
            output = output_both{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');
                
            output = get_redis_hash({'bad_hash'});
            output = output{1};
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
            output = get_redis_hash('bad_hash'); 
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
            
            assert(strcmpi(get_redis_hash('test_hash', 'field2'), 'value2'), ...
                'get_redis_hash wrong result of get field');  
            
            values = get_redis_hash({'test_hash', 'test_hash2'}, 'field1');
            assert(strcmpi(values{1}, 'value1'), ...
                'get_redis_hash wrong result of get field');  
            assert(strcmpi(values{2}, 'value3'), ...
                'get_redis_hash wrong result of get field'); 
            mrc.redis_cmd({'DEL test_hash', 'DEL test_hash2'});
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
        
        function test_worker_life_cycle(testCase)
            workers_count = mrc.redis_cmd('get workers_count');
            mrc.start_worker('wait');
            assert(~strcmp(workers_count,mrc.redis_cmd('get workers_count')), 'error in start_worker');
            mrc.set_worker_status('all', 'dead');
            pause(5)
        end
        
    end
    
    methods(TestClassSetup)
        function start_redis(testCase)
            disp('Start setup for tests')
            testCase.main_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.mrc_dir = fullfile(testCase.main_dir, 'matlab');
            testCase.redis_server_dir = fullfile(testCase.main_dir, 'redis_server');
            addpath(testCase.mrc_dir)
            try
                if strcmpi(mrc.redis_cmd('ping'), 'PONG')
                    warning('found redis server before initialization')
                    mrc.set_worker_status('all', 'dead')
                    pause(5)
                    mrc.redis_cmd('SHUTDOWN NOSAVE');
                end
            end
            disp('Start redis server')
            mrc.start_redis_server;
            assert(wait_for_condition(@() strcmpi(mrc.redis_cmd('ping'), 'pong')), ...
                'could not find redis server after initialization');
            mrc.set_worker_status('all', 'dead')
            pause(5)
            mrc.flush_db;
            disp('End setup for tests')
            disp('-------------------')
        end
    end
    
    methods(TestClassTeardown)
        function close_redis(testCase)
            disp('Start teardown of tests')
            disp('Kill all workers')
            mrc.set_worker_status('all', 'dead')
            pause(5)
            disp('Close redis')
            mrc.redis_cmd('SHUTDOWN NOSAVE');
        end        
    end
    
end