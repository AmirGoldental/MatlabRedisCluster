function redis_str = str_to_redis_str(str)
special = '"';
redis_str = '';
for l = char(str)
    if ~isempty(find(special == l, 1))
        redis_str = [redis_str, '\', l];
    else
        redis_str = [redis_str, l];
    end
end
redis_str = ['"' redis_str '"'];

end