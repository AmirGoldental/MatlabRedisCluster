function [output, redis_cmd_prefix] = redis_cmd(command, varargin)
persistent cache

strings_in_varargin = cellfun(@(cell) isstring(cell), varargin);
varargin(strings_in_varargin) = cellfun(@(cell) char(cell), varargin(strings_in_varargin), 'UniformOutput', false);

%% prepare cmd_prefix
if any(strcmpi('cmd_prefix', varargin))
    redis_cmd_prefix = varargin{find(strcmpi('cmd_prefix', varargin), 1) + 1};
else
    mrc_path = fileparts(fileparts(mfilename('fullpath')));
    conf = mrc.read_conf_file;
    redis_cli_path = dir(conf.redis_cli_path);
    if isempty(redis_cli_path)
        redis_cli_path = dir(fullfile(mrc_path, conf.redis_cli_path));
    end
    assert(length(redis_cli_path) == 1, 'Could not find redis-cli.exe');
    redis_cli_path = fullfile(redis_cli_path.folder, redis_cli_path.name);
    redis_cmd_prefix = ['"' redis_cli_path '" -h ' conf.redis_hostname ' -p '...
        conf.redis_port ' -a ' conf.redis_password ' -n ' conf.redis_db ' '];
end

if ~iscell(command)
    command = {command};
    unpack_single_output = true;
else 
    unpack_single_output = false;
end

if iscell(command)
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
        db_id = get_db_id();
        if isempty(cache) || ~cache.isKey('db_id') || ~strcmp(db_id, cache('db_id'))
            % DB was flushed, clean cache.
            cache = containers.Map;
            cache('db_id') = db_id;
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


