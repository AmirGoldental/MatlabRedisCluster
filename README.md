# MatlabRedisCluster
### Lightweight Matlab distributed computing based on Redis.  
![image](https://user-images.githubusercontent.com/50057077/112987188-1b458080-916b-11eb-97d9-6fe7942718b4.png)
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
  
![image](https://user-images.githubusercontent.com/50057077/112982622-59d83c80-9165-11eb-97e1-ed2957179e03.png)
   
