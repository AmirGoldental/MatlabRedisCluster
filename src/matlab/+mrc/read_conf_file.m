function conf_data = read_conf_file(file_path)
if ~exist('file_path', 'var')
    mrc_path = fileparts(fileparts(mfilename('fullpath')));
    file_path = fullfile(mrc_path, 'mrc_client.conf');    
end

f = fopen(file_path);
if f == -1
    error(['Unable to open ' file_path])
end

conf_arrs = textscan(f, '%[^=]=%[^\n]');
conf_arrs{2} = cellfun(@strip, conf_arrs{2}, 'UniformOutput', false);
fclose(f);

conf_data = cell2struct(conf_arrs{2}, conf_arrs{1});
end