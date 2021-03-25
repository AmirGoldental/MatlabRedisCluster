function script_SHA = script_SHA(script_name)
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
    script_SHA = SHA_script_store(script_name);
    return
end

% get from redis
SHA = mrc.redis_cmd(['GET SHA_script_store:' script_name]);
if ~isempty(SHA)
    script_SHA = [SHA ' '];
    SHA_script_store(script_name) = script_SHA;
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
SHA = mrc.redis_cmd(['SCRIPT LOAD ' str_to_redis_str(char(lua_script'))]);
script_SHA = [SHA ' '];
SHA_script_store(script_name) = script_SHA;
mrc.redis_cmd(['SET SHA_script_store:' script_name ' ' SHA]);
end

