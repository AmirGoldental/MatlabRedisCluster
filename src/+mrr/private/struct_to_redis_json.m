function str_cleaned = struct_to_redis_json(struct)

    str = jsonencode(struct);
    
    special = '"';
    str_cleaned = '';
    for l = str
        if ~isempty(find(special == l, 1))
            str_cleaned = [str_cleaned, '\', l];
        else
            str_cleaned = [str_cleaned, l];
        end
    end
    str_cleaned = ['"' str_cleaned '"'];
end

