function [output, redis_cmd_prefix] = redis_multi_cmd(commands, redis_cmd_prefix)
if ~exist('redis_cmd_prefix', 'var')
    conf_path = fullfile(fileparts(fileparts(mfilename('fullpath'))),'mrr_client.conf');
    conf = read_conf_file(conf_path);
    
    redis_cmd_prefix = [conf.redis_cli_path ' -h ' conf.redis_hostname ' -p '...
        conf.redis_port ' -a ' conf.redis_password ' -n ' conf.redis_db ' '];
end

cmds = cellfun(@(x) {['echo ' x]}, commands);
cmd = char(strjoin(cmds, ' && '));
[exit_flag, output] = system(['(' cmd ') | ' redis_cmd_prefix]);

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

conf_arrs = textscan(f, '%[^=]=%[^\n]');
conf_arrs{2} = cellfun(@strip, conf_arrs{2}, 'UniformOutput', false);
fclose(f);

conf_data = cell2struct(conf_arrs{2}, conf_arrs{1});
end