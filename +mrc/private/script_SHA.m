function SHA = script_SHA(script_name)
persistent SHA_script_store
persistent db_timetag

% db sync
if ~strcmp(db_timetag, get_db_timetag())
    db_timetag = get_db_timetag();
    SHA_script_store = [];
end

if isempty(SHA_script_store)
    SHA_script_store = containers.Map;
end

% get from cache
if SHA_script_store.isKey(script_name)
    SHA = SHA_script_store(script_name);
    return
end

% get from redis
SHA = redis().get(['SHA_script_store:' script_name]);
if ~isempty(SHA) && strcmp(redis().script('exists', SHA), '1')
    SHA_script_store(script_name) = SHA;
    return
end

% upload to cache and redis
lua_path = fullfile(fileparts(mfilename('fullpath')), [char(script_name) '.lua']);
if ~exist(lua_path, 'file')
    error('Unrecognized lua script')
end
fid = fopen(lua_path);
lua_script = fread(fid);
fclose(fid);
SHA = redis().script('LOAD', str_to_redis_str(char(lua_script')));
SHA_script_store(script_name) = SHA;
redis().set(['SHA_script_store:' script_name], SHA);
end

