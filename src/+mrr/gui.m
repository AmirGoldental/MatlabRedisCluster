function status_gui()
close all
cluster_status = get_redis_data('mock');
fig = figure('Name', 'Matlab Redis Runner', 'MenuBar', 'none', 'Color' ,'#212121');
fig.Units = 'normalized';
fig.Position = [0.02 0.04 0.95 0.85];
ongoing_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'Position', [0.05 0.9 0.099 0.05],...
    'BackgroundColor', '#243B53', 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
waiting_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Waiting Tasks', 'Units', 'normalized', 'Position', [0.15 0.9 0.099 0.05],...
    'BackgroundColor', '#243B53', 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
done_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Done Tasks', 'Units', 'normalized', 'Position', [0.25 0.9 0.099 0.05],...
    'BackgroundColor', '#243B53', 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);  
workers_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'Position', [0.35 0.9 0.099 0.05],...
    'BackgroundColor', '#243B53', 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);


table_hndl = uicontrol(fig, 'Style', 'listbox', 'String', cluster_status.waiting_tasks.command, ...
     'FontName', 'Consolas', 'FontSize', 12, 'ForegroundColor', 'w',...
     'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.8], 'BackgroundColor', '#424242')
end