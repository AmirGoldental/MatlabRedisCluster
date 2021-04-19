function redis_structs = get_redis_hash(redis_keys, field_name)
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

if ~exist('field_name', 'var')
    redis().multi;
    for ind = 1:length(redis_keys)
       redis().hgetall(redis_keys{ind}); 
    end
    redis_outputs = redis().exec;
    redis_structs = cellfun(@(redis_output) redis_output_to_struct(redis_output), redis_outputs, 'UniformOutput', false);
else
    redis().multi;
    for ind = 1:length(redis_keys)
       redis().hget(redis_keys{ind}, field_name); 
    end
    redis_structs = redis().exec;
end

if unpack_single_output
    redis_structs = redis_structs{1};
end
end

function redis_struct = redis_output_to_struct(redis_output)
obj_cells = split(redis_output, newline);
redis_struct = struct();
for cell_idx = 1:2:(length(obj_cells)-1)
    redis_struct.(obj_cells{cell_idx}) = char(obj_cells{cell_idx+1});
end
end
