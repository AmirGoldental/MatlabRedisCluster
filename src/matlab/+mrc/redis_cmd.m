function [output, redis_cmd_prefix] = redis_cmd(command, varargin)
persistent last_redis_cmd
min_interval_to_use_timeout = 10*60; % seconds
default_timeout = 5;
if isempty(last_redis_cmd)
    last_redis_cmd = 0;
end
if ~any(strcmpi('timeout', varargin)) && (last_redis_cmd - now) > min_interval_to_use_timeout / (60*60*24)
   varargin = [varargin  {'timeout', default_timeout}];
end

strings_in_varargin = cellfun(@(cell) isstring(cell), varargin);
varargin(strings_in_varargin) = cellfun(@(cell) char(cell), varargin(strings_in_varargin), 'UniformOutput', false);

% prepare cmd_prefix
if any(strcmpi('cmd_prefix', varargin))
    redis_cmd_prefix = varargin{find(strcmpi('cmd_prefix', varargin), 1) + 1};
else
    mrc_path = fileparts(fileparts(mfilename('fullpath')));
    killtimeout_path = fullfile(fileparts(mrc_path), 'utils', 'unix_timeout.bat');
    conf = mrc.read_conf_file;
    redis_cli_path = dir(conf.redis_cli_path);
    if isempty(redis_cli_path)
        redis_cli_path = dir(fullfile(mrc_path, conf.redis_cli_path));
    end
    assert(length(redis_cli_path) == 1, 'Could not find redis-cli.exe');
    redis_cli_path = fullfile(redis_cli_path.folder, redis_cli_path.name);
    redis_cmd_prefix = ['"' redis_cli_path '" -h ' conf.redis_hostname ' -p '...
        conf.redis_port ' -a ' conf.redis_password ' -n ' conf.redis_db ' '];
    
    if any(strcmpi('timeout', varargin))
        timeout = varargin{find(strcmpi('timeout', varargin), 1) + 1};
        redis_cmd_prefix = ['"' killtimeout_path '" ' num2str(timeout) ' ' redis_cmd_prefix];
    end
end

if ~iscell(command)
    command = {command};
    unpack_single_output = true;
else 
    unpack_single_output = false;
end

command = command(:);
cmd = '';
output = '';
for command_idx = 1:numel(command)
    this_command = command{command_idx};
    if isempty(cmd)
        cmd = ['echo ' this_command];
    else
        cmd = [cmd ' && echo echo -REDIS-CMD-BREAK- && echo ' this_command ];
    end
    
    if (length(cmd) + length(command{min(command_idx,end)})) > 7900 || command_idx == numel(command)
        [this_exit_flag, this_output] = system(['(' cmd ') | ' redis_cmd_prefix]);
        
        if this_exit_flag
           warning('redis command exited with an error') 
        end
        if strcmp(this_output(1:min(26,end)), 'Could not connect to Redis')
            error('Could not connect to Redis')
        end
        if isempty(output)
            output = [this_output '-REDIS-CMD-BREAK-'];
        else
            output = [output newline this_output '-REDIS-CMD-BREAK-'];
        end
        
        cmd = '';
    end
end
last_redis_cmd = now;
output = split(output, '-REDIS-CMD-BREAK-');
output(end) = [];
output = strip(output);

error_idxs = find(strncmp(output, 'ERR', 3));
error_idxs = sort(union(error_idxs, find(strncmp(output, 'NOSCRIPT', 8))));
if ~isempty(error_idxs)
    error_strings = cellfun(@(cmd, err, idx) ...
        ['error for command #' num2str(idx) ' (' cmd '): ' err], ...
        command(error_idxs(:)), output(error_idxs(:)), num2cell(error_idxs(:)), 'UniformOutput', false);
    error(strjoin(error_strings, newline));
end

if unpack_single_output
    output = output{1};
end

output = strip(output);
end


