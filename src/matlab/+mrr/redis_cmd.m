function [output, redis_cmd_prefix] = redis_cmd(command, redis_cmd_prefix)
if ~exist('redis_cmd_prefix', 'var')
    conf_path = fullfile(fileparts(mfilename('fullpath')),'\..\mrr_client.conf');
    conf = read_conf_file(conf_path);
    
    redis_cmd_prefix = [conf.redis_cli_path ' -h ' conf.redis_hostname ' -p '...
        conf.redis_port ' -a ' conf.redis_password ' -n ' conf.redis_db ' '];
end
[exit_flag, output] = system([redis_cmd_prefix char(command)]);

if exit_flag == 1
    disp(output)
end

if strcmp(output(1:min(26,end)), 'Could not connect to Redis')
    error('Could not connect to Redis')
end

if strcmp(output(1:min(3,end)), 'ERR')
    error(output(1:end-2));
end

output = output(1:end-1);
end


function conf_data = read_conf_file(file_path)
f = fopen(file_path);
if f == -1
    error(['Unable to open ' file_path])
end

conf_data = struct();
temp_line = fgetl(f);
while ischar(temp_line) && ~isempty(temp_line)
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