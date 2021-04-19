function output = redis(varargin)
persistent connection
if any(strcmpi(varargin, 'reconnect'))
    connection = [];
end
if isempty(connection)
    conf = read_conf_file;
    connection = Redis(conf.redis_hostname, str2double(conf.redis_port), 'password', conf.redis_password, 'db', str2double(conf.redis_db));
end
output = connection;
end

