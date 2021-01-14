function gui()
cluster_status = mrr.get_cluster_status();
fig = figure('Name', 'Matlab Redis Runner', 'MenuBar', 'none', 'Color' ,'#CFD8DC');
fig.NumberTitle = 'off'; 
fig.Units = 'normalized';
fig.Position = [0.02 0.04 0.95 0.85];

gui_status.active_filter_button = 'ongoing';

filter_buttons.ongoing = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'Position', [0.01 0.92 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('ongoing'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pending Tasks', 'Units', 'normalized', 'Position', [0.01 0.87 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('pending'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.finished = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Finished Tasks', 'Units', 'normalized', 'Position', [0.01 0.82 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('finished'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);  
filter_buttons.failed = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Failed Tasks', 'Units', 'normalized', 'Position', [0.01 0.77 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('failed'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);  
filter_buttons.workers = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'Position', [0.01 0.72 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('workers'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);

delete_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', '#DD2C00',...
    'String', 'Delete task(s)', 'Units', 'normalized', 'Position', [0.01 0.12 0.1 0.0499],...
    'callback', @(~,~) delete_tasks(), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);

view_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', '#303F9F',...
    'String', 'View details', 'Units', 'normalized', 'Position', [0.01 0.07 0.1 0.0499],...
    'callback', @(~,~) view_task, 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);

refresh_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', '#009688',...
    'String', 'Refresh', 'Units', 'normalized', 'Position', [0.01 0.02 0.1 0.0499],...
    'callback', @(~,~) refresh(), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);

command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
     'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
     'Units', 'normalized', 'Position', [0.12 0.02 0.87 0.95], 'BackgroundColor', '#90A4AE', 'Value', 1);

refresh()

    function filter_button_callback(category)
        gui_status.active_filter_button = category;
        structfun(@(button) set(button, 'BackgroundColor', '#9FA8DA'), filter_buttons)
        filter_buttons.(category).BackgroundColor = '#3949AB';
        if strcmp(category, 'workers')
            warning('Not yet implemented');
        else
            command_list.Value = 1;
            if ~isempty(cluster_status.([category '_matlab_tasks']))
                command_list.String = cluster_status.([category '_matlab_tasks']).command;
            else
                command_list.String = {};
            end
        end
        
        if strcmp(category, 'pending')
            delete_button.Visible = 'on';
        else
            delete_button.Visible = 'off';
        end
    end
    
    function refresh()
        cluster_status = mrr.get_cluster_status();
        filter_button_callback(gui_status.active_filter_button)
        fig.Name = ['Matlab Redis Runner, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
    end

    function delete_tasks()
        warning('Not yet implemented')
    end

    function view_task()
        warning('Not yet implemented')
    end
end
