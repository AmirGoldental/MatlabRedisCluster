# MatlabRedisCluster
Lightweight Matlab distributed computing based on Redis  
![image](https://user-images.githubusercontent.com/50057077/112982622-59d83c80-9165-11eb-97e1-ed2957179e03.png)
   
## Quickstart  
- On any computer start the `start_mrc_server.bat` file to start the Redis server. Note the hostname, it will be displayed on the cmd window.  
- Update the hostname in the `worker.conf` file.  
- Start a worker on any computer that is on the same network as the host using the `start_worker.bat`.
- On any computer that is on the same network add the repository folder to the Matlab path and run `mrc.new_cmd("disp('hello world')")`.  
