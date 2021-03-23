function redis_structs = get_redis_hash(redis_keys)
if isempty(redis_keys)
    redis_structs = [];
    return
end
if ~iscell(redis_keys)
    redis_keys = {redis_keys};
    unpack_single_output = true;
else 
    unpack_single_output = false;
end
if numel(redis_keys) == 1 && isempty(redis_keys{1})
    redis_structs = struct();
    return
end
redis_cmds = cellfun( @(redis_key) ['HGETALL ' char(redis_key)], redis_keys, 'UniformOutput', false);
redis_outputs = mrc.redis_cmd(redis_cmds);
redis_structs = cellfun(@(redis_output) redis_output_to_struct(redis_output), redis_outputs, 'UniformOutput', false);

if unpack_single_output
    redis_structs = redis_structs{1};
end
end

function redis_struct = redis_output_to_struct(redis_output)
obj_cells = split(redis_output, newline);
redis_struct = struct();
for cell_idx = 1:2:(length(obj_cells)-1)
    redis_struct.(obj_cells{cell_idx}) = string(obj_cells{cell_idx+1});
end
end
