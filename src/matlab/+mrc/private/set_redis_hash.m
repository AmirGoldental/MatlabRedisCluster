function set_redis_hash(redis_keys, matlab_structs)
if ~iscell(matlab_structs)
    matlab_structs = {matlab_structs};
end
if ~iscell(redis_keys)
    redis_keys = {redis_keys};
end
if numel(redis_keys) ~= numel(matlab_structs)
    error('numel(redis_keys) ~= numel(matlab_structs)')
end

empty_structs = cellfun(@(x) isempty(fieldnames(x)), matlab_structs);
matlab_structs(empty_structs) = [];
redis_keys(empty_structs) = [];
if isempty(matlab_structs)
   return 
end

redis_cmds = cellfun(@(redis_key, matlab_struct) ...
    matlab_struct_to_redis_cmd(redis_key, matlab_struct), redis_keys, matlab_structs, ...
    'UniformOutput', false);
mrc.redis_cmd(redis_cmds);
end


function redis_cmd = matlab_struct_to_redis_cmd(redis_key, matlab_struct)
hash_str = [];
for field = fieldnames(matlab_struct)'
    hash_str = [hash_str ' ' field{1} ' ' str_to_redis_str(matlab_struct.(field{1}))];
end
redis_cmd = ['HMSET ' redis_key ' ' hash_str];
end
