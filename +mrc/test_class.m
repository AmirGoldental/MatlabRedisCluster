classdef test_class < matlab.unittest.TestCase
    % runtests('MRCTest'); % in src/matlab
    % check in advance that no other redis / cluster is running
    % with the same configurations
    properties
        main_dir
        mrc_dir
        redis_server_dir
    end
        
    methods(Test)        
        function test_get_db_timetag_and_flush_db(testCase) 
            disp('test_get_db_timetag_and_flush_db')
			mrc.redis().set('db_timetag', 'hello');
			tag = get_db_timetag;
			mrc.redis().set('tmp', 'a');
			mrc.flush_db;
			new_tag = get_db_timetag;			
			assert(~strcmpi(new_tag, tag), 'get_db_timetag was not changed after db reset');
			assert(~strcmpi(mrc.redis().get('tmp'), 'a'), 'data stays after db flush');
        end
        
        function test_get_redis_hash(testCase)  
            disp('test_get_redis_hash')
            output = get_redis_hash({});
            assert(isempty(output), 'get_redis_hash empty input did not result in empty output')
            mrc.redis().hmset('test_hash', 'field1', 'value1', 'field2', 'value 2', 'field3_numeric', '0');
            mrc.redis().hmset('test_hash2', 'field1', 'value3', 'field2_numeric', '1');
            output = get_redis_hash('test_hash');
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value 2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');

            output = get_redis_hash({'test_hash'});
            assert(length(output) == 1, 'get_redis_hash wrong result length');
            output = output{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value 2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');

            output_both = get_redis_hash({'test_hash', 'test_hash2'});
            output = output_both{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value 2') && ...
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
                strcmpi(output.field2, 'value 2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');
                
            output_both = get_redis_hash({'test_hash', 'bad_hash'});
            output = output_both{1};
            assert(...
                strcmpi(output.field1, 'value1') && ...
                strcmpi(output.field2, 'value 2') && ...
                strcmpi(output.field3_numeric, '0'), ...
                'get_redis_hash wrong result');
                
            output = get_redis_hash({'bad_hash'});
            output = output{1};
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
            output = get_redis_hash('bad_hash'); 
            assert(isempty(fieldnames(output)), 'get_redis_hash wrong result on empty hash');
            
            assert(strcmpi(get_redis_hash('test_hash', 'field2'), 'value 2'), ...
                'get_redis_hash wrong result of get field');  
            
            values = get_redis_hash({'test_hash', 'test_hash2'}, 'field1');
            assert(strcmpi(values{1}, 'value1'), ...
                'get_redis_hash wrong result of get field');  
            assert(strcmpi(values{2}, 'value3'), ...
                'get_redis_hash wrong result of get field'); 
            mrc.redis().del('test_hash');
            mrc.redis().del('test_hash2');
        end

        function test_set_redis_hash(testCase)  
            disp('test_set_redis_hash')
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
            disp('test_worker_life_cycle')
            workers_count = str2double(mrc.redis().scard('available_workers'));
            mrc.start_worker('wait');
            workers_count_after_start = str2double(mrc.redis().scard('available_workers'));
            testCase.verifyEqual(workers_count_after_start, workers_count+1, 'number of workers is unexpected')
            mrc.set_worker_status('all', 'dead');
            pause(5)
            testCase.verifyEqual(mrc.redis().scard('available_workers'), '0', 'number of workers is not 0 after kill')
        end
        
        function functional_DAG_test_1(testCase)
            disp('functional_DAG_test_1')
            mrc.start_worker;
            mrc.start_worker;
            testCase.verifyTrue(...
                wait_for_condition(@() mrc.redis().scard('available_workers') == '2'),...
                'number of workers is not 2')
            t = mrc.new_task(repmat({'mrc.redis().rpush(''test_list'', ''task0'')'},3,1));
            f = mrc.new_task('fail');
            mrc.new_task('mrc.redis().rpush(''test_list'', ''taskX'')', 'dependencies', f);
            mrc.new_task('mrc.redis().rpush(''test_list'', ''task1'')', 'dependencies', t);
            expected_test_list = {'task0', 'task0', 'task0', 'task1'};
            
            wait_for_condition(@() mrc.redis().llen('test_list') == num2str(numel(expected_test_list)));
            testCase.verifyTrue(all(strcmpi(mrc.redis().lrange('test_list', '0', '-1'), expected_test_list)), 'Something went worng')
            
            mrc.set_task_status(f, 'finished');
            expected_test_list = {'task0', 'task0', 'task0', 'task1', 'taskX'};
            wait_for_condition(@() mrc.redis().llen('test_list') == num2str(numel(expected_test_list)));
            testCase.verifyTrue(all(strcmpi(mrc.redis().lrange('test_list', '0', '-1'), expected_test_list)), 'Something went worng')
        end
        function functional_DAG_test_2(testCase)
            disp('functional_DAG_test_1')
            t1 = mrc.new_task(repmat({'mrc.redis().rpush(''test_list'', ''task0'')'},3,1));
            mrc.new_task('fail');
            expected_test_list = repmat({'task0'},1,3);
            t2 = mrc.new_task(repmat({'mrc.redis().rpush(''test_list'', ''task1'')'},3,1), 'dependencies', t1);
            expected_test_list = [expected_test_list, repmat({'task1'},1,3)];
            mrc.new_task('fail');
            mrc.new_task(repmat({'mrc.redis().rpush(''test_list'', ''task2'')'},3,1), 'dependencies', [t1;t2]);
            expected_test_list = [expected_test_list, repmat({'task2'},1,3)];
            mrc.new_task('fail');            
            mrc.start_worker;
            mrc.start_worker;
            testCase.verifyTrue(...
                wait_for_condition(@() mrc.redis().scard('available_workers') == '2'),...
                'number of workers is not 2')
            
            wait_for_condition(@() mrc.redis().llen('test_list') == num2str(numel(expected_test_list)));
            testCase.verifyTrue(all(strcmpi(mrc.redis().lrange('test_list', '0', '-1'), expected_test_list)), 'Something went worng')
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
                redis('reconnect');
                if strcmpi(mrc.redis().ping, 'PONG')
                    warning('found redis server before initialization')
                    mrc.set_worker_status('all', 'dead')
                    mrc.redis().shutdown('NOSAVE');
                end
            end
            disp('Start redis server')
            mrc.start_redis_server;
            redis('reconnect');
            assert(wait_for_condition(@() strcmpi(mrc.redis().ping, 'pong')), ...
                'could not find redis server after initialization');
            mrc.set_worker_status('all', 'dead')
            mrc.flush_db;
            disp('End setup for tests')
            disp('-------------------')
        end
    end
    
    methods(TestClassTeardown)
        function close_redis(testCase)
            disp('Close redis')
            mrc.redis().shutdown('NOSAVE');
        end        
    end
    
    methods(TestMethodTeardown)
        function restart_cluster(testCase)
            mrc.set_worker_status('all', 'dead')
            pause(2)
            mrc.flush_db;
        end
    end
end