function str = str_to_redis_str(str)
if isnumeric(str)
    str = num2str(str);
end
str = char(str);
str(str == char(13)) = ' ';
str(str == newline) = ' ';
% str = ['"' str '"'];

end
