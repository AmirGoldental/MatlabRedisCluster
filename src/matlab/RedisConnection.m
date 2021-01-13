classdef RedisConnection
    %REDISCONNECTION is a lightweight matlab client for redis
    
    properties
        redis_cmd
    end
    
    methods
        function obj = RedisConnection(varargin)
            % RedisConnection(conf_file_path, redishost_file_path)
            % RedisConnection(redis_cli_path, redis_host, redis_port, redis_password, redis_db)
            %   all inputs are strings
            if numel(varargin) == 2
                % Read conf files
                for file_path = varargin
                    f = fopen(file_path{1});
                    if f == -1
                        error(['Unable to open ' file_path{1}])
                    end
                    temp_line = fgetl(f);
                    while ischar(temp_line)
                        conf_data.(temp_line(1:find(temp_line == '=', 1)-1)) = ...
                            temp_line(find(temp_line == '=', 1)+1:end);
                        temp_line = fgetl(f);
                    end
                end
                
                % Remove whitespaces
                for key = fieldnames(conf_data)'
                    value = conf_data.(key{1});
                    value(value==' ') = [];
                    conf_data.(key{1}) = value;
                end
                obj = RedisConnection(conf_data.redis_cli_path, conf_data.redis_host, conf_data.redis_port, ...
                    conf_data.redis_password, conf_data.redis_port, conf_data.redis_db);
            else
                redis_cli_path = varargin{1};
                redis_host = varargin{2};
                redis_port = varargin{3};
                redis_password = varargin{4};
                redis_db = varargin{5};
                obj.redis_cmd = [redis_cli_path ' -h ' redis_host ' -p ' redis_port ' -a ' redis_password ' -n ' redis_db ' '];
            end
        end
        
        function outputArg = cmd(obj,commend)
            disp([obj.redis_cmd ' ' commend])
            [exit_flag, outputArg] = system([obj.redis_cmd ' ' commend]);
        end
    end
end

