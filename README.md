# MatlabRedisCluster
### Lightweight Matlab distributed computing based on Redis.  
![image](https://user-images.githubusercontent.com/50057077/117539282-9c1d5500-b012-11eb-8eb6-46e1788164a4.png)
#### Deploy a cluster of Matlab workers in minutes, without writing a single line of code.  

## Features
- Work in parallel with your co-workers on the same cluster.
- Execute processes that are co-dependent in a DAG-like structure (similar to airflow).
- "Run on this machine" when a task fails for quick debugging.
- One GUI to rule them all.

## Quickstart  
- On any computer start the `start_redis_server.bat` file to start the Redis server. Note the hostname, it will be displayed on the cmd window.  
- Update the hostname in the `worker.conf` file.  
- Start a worker on any computer that is on the same network as the host using the `start_worker.bat`.
- On any computer that is on the same network add the repository folder to the Matlab path and run 
   ```
   mrc.new_cmd("disp('hello world')")
   ```

## Our terminology
- Task - A Matlab command. A task jas the following attributes:  
   - `command`: A Matlab command in string or char format.  
   - `id`: An integer value that is assigned when the task is sent to the cluster for execution.  
   - `key`: A string in the form "task:X" where X is the task ID. The task key is returned when sending the task to the cluster.  
   - `status`: one of "pre-pending"/"pending"/"finished"/"failed".  
   - `path2add`: (optional) a folder path to add the Matlab environment when executing a task.  
   - `requirements`: (optional) a cell array of task keys, the task will not be executed until all requirements are finished.    
      A task with non-finished requirements will be assigned a status of "pre-pending".   
   - `fail_policy`: "halt" (default) or "continue". If the fail policy is "continue" the dependent tasks will see this task as finished.     
   -  Additional attributes: `created_by` ("computer/user"), `created_on` (datetime), `worker` (worker key or "None").    
- Worker - An instance of Matlab that executes tasks. A worker has the following attributes:  
   - `key`: Assigned automatically, in the form of "worker:X" where X is an integer.  
   - `computer`: The host of the worker.  
   - `user`: The user that started this worker.  
   - `status`: on of "active"/"suspended"/"dead".   
   - Additional attributes: `started_on` (datetime), `current_task` (task key or "None"), last_command (string), `last_ping` (datetime).    
## API
* new_task(command, varargin): command is char or cell array of commands. returns the task keys. varargin include:
   * 'addpath', path2folder (char)
   * 'fail_policy', 'halt'(default)/'continue'
   * 'dependencies', task_keys (char/cell array)
* flush_db(): stop all tasks, clear all history, and restart workers.            
* get_cluster_status()  
* join_as_worker()      
* redis_cmd(command): run redis command on redis server. command can also be cell array. 
* start_redis_server()
* start_worker()
* wait(): stops matlab execution while there are pending tasks.
* GUI:
![image](https://user-images.githubusercontent.com/50057077/112982622-59d83c80-9165-11eb-97e1-ed2957179e03.png)
   
## How it works?
The interaction with Redis is executed through Redis-CLI (in Batch files) and MatlabRedis client (in Matlab).    
### Some examples from the code base.  
When a worker joins the worker pool it takes and ID:   
```redis
INCR workers_count
```
In order to set the worker details we used `HMSET`, e.g.
```redis
HMSET worker:1 status active current_task None
```
In the actual codebase we wrote an abstucion layer that transforms Matlab's structs to redis hashes (and vise versa).  
We keep track on all active workers using a set, so when a worker joins it runs the command:
```redis
SADD available_workers <worker_key>
```
  
When a new task is sent to the server the following lua script runs:  
```redis
EVALSHA script_sha_here 5 <task_matlab_cmd> <created_by> <created_on> <path2add> <fail_policy>
```
```lua
local task_id = redis.call('INCR','tasks_count'); 
local task_key = 'task:' .. task_id;
local command = KEYS[1];
local created_by = KEYS[2];
local created_on = KEYS[3];
local path2add = KEYS[4];
local fail_policy = KEYS[5];
local task_status; 
for idx=1,#ARGV,1 do 
    if redis.call('HGET', ARGV[idx], 'status') ~= 'finished' then 
        redis.call('LPUSH', task_key .. ':dependencies', ARGV[idx]); 
        redis.call('LPUSH', ARGV[idx] .. ':prior_to', task_key);
    end; 
end; 
if #ARGV == 0 then 
    redis.call('RPUSH', 'pending_tasks', task_key);
    task_status = 'pending';
elseif redis.call('LLEN', task_key .. ':dependencies') == 0 then 
    redis.call('LPUSH', 'pending_tasks', task_key); task_status = 'pending'; 
else redis.call('RPUSH', 'pre_pending_tasks', task_key); task_status = 'pre_pending'; 
end;
redis.call('HMSET', task_key, 'key', task_key, 'id', tostring(task_id),
    'command', command, 'created_by', created_by, 'created_on', created_on,
    'path2add', path2add, 'status', task_status, 'fail_policy', fail_policy,
    'worker', 'None', 'str', '[' .. created_on .. '] ' .. command); 
return task_key
```

After a task is finished, the folowing redis commands are sent by the worker:  
```redis
MULTI
LREM active_tasks 0 <task_key>
LPUSH finished_tasks <task_key>
HMSET <task_key> finished_on <datetime> status finished str <task_str>
EXEC
```

There are hundreds of uses of Redis across the project and several abstruction layers.
