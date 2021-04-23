function output = lua_script(script_name, keys_num, varargin)
persistent script_store
persistent db_timetag

% db sync
if ~strcmp(db_timetag, get_db_timetag())
    db_timetag = get_db_timetag();
    script_store = containers.Map;
end

% get from cache
if script_store.isKey(script_name)
    lua_script = script_store(script_name);
else
    lua_path = fullfile(fileparts(mfilename('fullpath')), [char(script_name) '.lua']);
    if ~exist(lua_path, 'file')
        error('Unrecognized lua script')
    end
    fid = fopen(lua_path);
    lua_script = char(fread(fid)');
    fclose(fid);
end
output = mrc.redis().eval(lua_script, keys_num, varargin);
end

