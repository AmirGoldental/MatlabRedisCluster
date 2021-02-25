function redis_str = str_to_redis_str(str)
if isstring(str)
    str = char(str);
end
if isnumeric(str)
    str = num2str(str);
end
special = '"\';
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
