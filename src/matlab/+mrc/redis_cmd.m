function [output, redis_cmd_prefix] = redis_cmd(command, varargin)
persistent cache

strings_in_varargin = cellfun(@(cell) isstring(cell), varargin);
varargin(strings_in_varargin) = cellfun(@(cell) char(cell), varargin(strings_in_varargin), 'UniformOutput', false);

%% prepare cmd_prefix
if any(strcmpi('cmd_prefix', varargin))    
    redis_cmd_prefix = varargin{find(strcmpi('cmd_prefix', varargin), 1) + 1};
else
    mrc_path = fileparts(fileparts(mfilename('fullpath')));
    conf_path = fullfile(mrc_path,'mrc_client.conf');
    conf = read_conf_file(conf_path);
    redis_cli_path = dir(conf.redis_cli_path);
    if isempty(redis_cli_path)
        redis_cli_path = dir(fullfile(mrc_path, conf.redis_cli_path));
    end
    assert(length(redis_cli_path) == 1, 'Could not find redis-cli.exe');
    redis_cli_path = fullfile(redis_cli_path.folder, redis_cli_path.name);
    redis_cmd_prefix = [redis_cli_path ' -h ' conf.redis_hostname ' -p '...
        conf.redis_port ' -a ' conf.redis_password ' -n ' conf.redis_db ' '];
end

if iscell(command)
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
            
            if strcmp(this_output(1:min(26,end)), 'Could not connect to Redis')
                error('Could not connect to Redis')
            end
            output = [output this_output newline '-REDIS-CMD-BREAK-' newline];
            cmd = '';
        end
    end
    output = split(output, '-REDIS-CMD-BREAK-');
    if any(strncmp(output, 'ERR', 3))
        % Todo: better pinpoint error
        error(strjoin(output, newline));
    end
else
    redis_cmd = [redis_cmd_prefix char(command)];

    if any(strcmpi('cache_first', varargin))
        [exit_flag, output] = system_cache_first(redis_cmd);
    else
        [exit_flag, output] = system_then_cache(redis_cmd);
    end    
    if exit_flag == 1
        disp(output)
    end
    if strcmp(output(1:min(26,end)), 'Could not connect to Redis')
        error('Could not connect to Redis')
    end
    if strncmp(output, 'ERR', 3)
        error(output);
    end

end

output = strip(output);

    function [exit_flag, output] = system_cache_first(redis_cmd)
        % Check that DB was not flushed
        dbhash = mrc.redis_cmd('get dbhash');
        while isempty(mrc.redis_cmd('get dbhash'))
            % DB is empty.
            randomstr = char(randi([uint8('A') uint8('Z')], 1, 32));
            mrc.redis_cmd(['setnx dbhash ' randomstr]);
            dbhash = mrc.redis_cmd('get dbhash');
        end
        if isempty(cache) || ~cache.isKey('dbhash') || ~strcmp(dbhash, cache('dbhash'))
            % DB was flushed, clean cache.
            cache = containers.Map;
            cache('dbhash') = dbhash;
        end
        
        if cache.isKey(redis_cmd)
            % Get from cache
            cached_values = cache(redis_cmd);
            exit_flag = cached_values.exit_flag;
            output = cached_values.output;
        else
            % Get from system and cache
            [exit_flag, output] = system(redis_cmd);
            cached_values.exit_flag = exit_flag;
            cached_values.output = output;
            cache(redis_cmd) = cached_values;
        end
        
    end

    function [exit_flag, output] = system_then_cache(redis_cmd)
        
        if isempty(cache)
            % Cache is clean.
            cache = containers.Map;
        end
        
        % Get from system and cache
        [exit_flag, output] = system(redis_cmd);
        cached_values.exit_flag = exit_flag;
        cached_values.output = output;
        cache(redis_cmd) = cached_values;
        
    end
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
