function [output, redis_cmd_prefix] = redis_cmd(varargin)
redis_connection = get_redis_connection();
if iscell(command)
    output = cellfun(@mrc.redis_cmd, command, 'UniformOutput', false);
    return
end

% command string to cells:
cells = split(char(command), ' ');
cells(cellfun(@isempty, cells)) = [];
cell_idx = 1;
cmd_cells = {};
while cell_idx <= numel(cells)
    cell_length = 1;
    if cells{cell_idx}(1) == '"'
        cells{cell_idx}(1) = [];
        while cells{cell_idx+cell_length-1}(end) ~= '"'
            cell_length = cell_length + 1;
        end
        cells{cell_idx+cell_length-1}(end) = [];
    end
    cmd_cells = [cmd_cells, {strjoin(cells(cell_idx:(cell_idx+cell_length-1)))}];
    cell_idx = cell_idx + cell_length;
end
try
    output = redis_connection.cmd(cmd_cells);
catch err
    if strcmp(err.identifier, 'MATLAB:networklib:tcpclient:writeFailed')
        warning('connection to redis failed, reconecting')
        try
            redis_connection = get_redis_connection('no_cache');
            output = redis_connection.cmd(cmd_cells);
        catch err
            error(err)
        end
    end
end
if iscell(output)
    output = strjoin(output, newline);
end
if strncmp(output, 'NOAUTH', 6)
    warning('connection to redis failed (NOAUTH), reconecting')
    try
        redis_connection = get_redis_connection('no_cache');
        output = redis_connection.cmd(cmd_cells);
        if iscell(output)
            output = strjoin(output, newline);
        end
    catch err
        error(err)
    end
end
return