function set_redis_hash(redis_keys, varargin)
% set_redis_hash(redis_key, matlab_struct)
% set_redis_hash(redis_keys [cell array], matlab_structs [cell array])
% set_redis_hash(redis_key, field_name, value [char])
if numel(varargin) == 1
    matlab_structs = varargin{1};
else
    matlab_structs = struct(varargin{1}, varargin{2});
end
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

redis = get_redis_connection;
redis.multi;
for ind = 1:length(redis_keys)
    redis_set_matlab_struct(redis, redis_keys{ind}, matlab_structs{ind});
end
redis.exec;
end


function redis_set_matlab_struct(redis, redis_key, matlab_struct)
args = {};
for field = fieldnames(matlab_struct)'
    args = [args, field, {str_to_redis_str(matlab_struct.(field{1}))}];
end
redis.hmset(redis_key, args{:});
end
