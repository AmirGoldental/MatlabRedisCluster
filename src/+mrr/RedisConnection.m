classdef RedisConnection<handle
    %REDISCONNECTION is a lightweight matlab client for redis
    % r = RedisConnection({...,...})
    % r.cmd('set a 1')
    properties (Access = private)
        redis_config_files
        redis_cmd
    end
    
    methods
        function obj = RedisConnection(config_folder_path)
            % RedisConnection(conf_files_cell_array)
            redis_config_files = fullfile(config_folder_path, {'main.conf', 'redis.host'});
            % Read conf files
            for file_path = redis_config_files
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
            obj.redis_cmd = [conf_data.redis_cli_path ' -h ' conf_data.redis_host ' -p '...
                conf_data.redis_port ' -a ' conf_data.redis_password ' -n ' conf_data.redis_db ' '];
            obj.redis_config_files = redis_config_files;
            
        end
        
        function output = cmd(obj,commend)
            disp([obj.redis_cmd ' ' commend])
            [exit_flag, output] = system([obj.redis_cmd commend]);
            output = output(1:end-1);
        end
        
    end
end

