function cluster_status = get_redis_data(varargin)
if any(strcmpi(varargin, 'mock'))
    task_id = {7; 8; 5};
    task_name = {'func1'; 'py_func'; 'some_magic'};
    type = {'matlab'; 'python'; 'exec'};
    command = {"func1('C:\path1','C:\path2')"; "py_func('C:\path1','C:\path2')"; 'mkdir path'};
    created_on = {'13_20_56__25_07_2020'; '14_20_56__25_07_2020'; '15_20_56__25_07_2020'};
    created_by = {'user1'; 'user2'; 'user1'};
    waiting_tasks = table(task_id, task_name, type, command, created_on, created_by);
    
    task_id = {1; 2; 4};
    task_name = {'func1'; 'py_func'; 'some_magic'};
    type = {'matlab'; 'python'; 'exec'};
    command = {"func1('C:\path1','C:\path2')"; "py_func('C:\path1','C:\path2')"; 'mkdir path'};
    created_on = {'13_20_56__25_07_2020'; '14_20_56__25_07_2020'; '15_20_56__25_07_2020'};
    started_on = {'13_21_56__25_07_2020'; '14_22_56__25_07_2020'; '15_23_56__25_07_2020'};
    created_by = {'user1'; 'user2'; 'user1'};
    ongoing_tasks = table(task_id, task_name, type, command, created_on, created_by, started_on);
    
    worker_id = [1:4]';
    server_name = {'comp1'; 'comp1'; 'comp2'; 'comp2'};
    type = {'matlab'; 'matlab'; 'python'; 'exec'};
    worker_task = {'None'; jsonencode(ongoing_tasks(1,:)); jsonencode(ongoing_tasks(2,:)); jsonencode(ongoing_tasks(3,:))};
    server_started_on = {'13_21_56__25_07_2019'; '14_22_56__25_07_2019'; '15_23_56__25_07_2019'; '15_23_56__25_07_2019'};
    workers = table(worker_id, type, server_name, server_started_on, worker_task);
    
    cluster_status.workers = workers;
    cluster_status.waiting_tasks = waiting_tasks;
else
    error('Not yet implemented')
end