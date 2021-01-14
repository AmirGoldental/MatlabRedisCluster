classdef RedisConnection<handle
    %REDISCONNECTION is a lightweight matlab client for redis
    % r = RedisConnection({...,...})
    % r.cmd('set a 1')
    properties (Access = private)
        config_files
        redis_cmd
    end
    
    methods
        function obj = RedisConnection(mrr_client_conf_path)
            if ~exist('mrr_client_conf_path', 'var')
                mrr_client_conf_path = fullfile(fileparts(mfilename('fullpath')),'\..\mrr_client.conf');
            end
            mrr_client_conf = read_conf_file(mrr_client_conf_path);
            % RedisConnection(conf_files_cell_array)
            main_conf = read_conf_file(fullfile(mrr_client_conf.host_path, 'main.conf'));
            host_conf = read_conf_file(fullfile(mrr_client_conf.host_path, 'redis.host'));
                        
            obj.redis_cmd = [mrr_client_conf.redis_cli_path ' -h ' host_conf.redis_host ' -p '...
                host_conf.redis_port ' -a ' main_conf.redis_password ' -n ' main_conf.redis_db ' '];
            
            obj.config_files.mrr_client_conf = mrr_client_conf;
            obj.config_files.main_conf = main_conf;
            obj.config_files.host_conf = host_conf;
            
        end
        
        function output = cmd(obj,command)
            [exit_flag, output] = system([obj.redis_cmd command]);
            if exit_flag == 1
                disp(output)
            end
            output = output(1:end-1);
        end
        
    end
end

function conf_data = read_conf_file(file_path)

f = fopen(file_path);
if f == -1
    error(['Unable to open ' file_path])
end

conf_data = struct();
temp_line = fgetl(f);
while ischar(temp_line)
    conf_data.(temp_line(1:find(temp_line == '=', 1)-1)) = ...
        temp_line(find(temp_line == '=', 1)+1:end);
    temp_line = fgetl(f);
end

% Remove whitespaces
for key = fieldnames(conf_data)'
    value = conf_data.(key{1});
    value(value==' ') = [];
    conf_data.(key{1}) = value;
end
end