function output = get_redis_connection(varargin)
persistent redis_connection
if any(strcmpi(varargin, 'no_cache'))
    redis_connection = [];
end
if isempty(redis_connection)
    conf = read_conf_file;
    redis_connection = Redis(conf.redis_hostname, str2double(conf.redis_port), 'password', conf.redis_password, 'db', str2double(conf.redis_db));
end
output = redis_connection;
end

