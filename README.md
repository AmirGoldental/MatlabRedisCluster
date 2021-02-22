# MatlabRedisCluster
Lightweight Matlab distributed computing based on Redis  

![image](https://user-images.githubusercontent.com/50057077/106132364-8921fb80-616c-11eb-9013-93a5585bef7d.png)  
![image](https://user-images.githubusercontent.com/50057077/106131961-013bf180-616c-11eb-8a84-a682268a2c0f.png)  

## Quick start  
- On one computer run 
    ```
    ./src/redis_server/redis_server.bat
    ``` 
    to start the redis server.   
  
- On any computer run 
    ```
    ./src/matlab/matlab_worker_wrapper.bat
    ``` 
    to start run a worker on that computer. Can be done several times.  
- On any computer add './src/matlab/' to matlab path and run `mrc.new_cmd("disp('hello world')")`.  
