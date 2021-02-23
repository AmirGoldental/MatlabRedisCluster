function gui()
colors = struct();
colors.background = '#9ba5ab';
colors.list_background = '#F1F1F1';
colors.red = '#cf4229';
colors.strong = '#1C4E80';
colors.weak = '#A5D8DD';

fig = figure('Name', 'Matlab Redis Runner', 'MenuBar', 'none', 'Color', colors.background);
fig.NumberTitle = 'off';
fig.Units = 'normalized';
fig.Position = [0.02 0.04 0.95 0.85];
data = [];
gui_status.active_filter_button = 'pending';

filter_buttons.pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pending Tasks', 'Units', 'normalized', 'Position', [0.01 0.92 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('pending'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.ongoing = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'Position', [0.01 0.87 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('ongoing'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.finished = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Finished Tasks', 'Units', 'normalized', 'Position', [0.01 0.82 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('finished'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.failed = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Failed Tasks', 'Units', 'normalized', 'Position', [0.01 0.77 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('failed'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.workers = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'Position', [0.01 0.72 0.1 0.0499],...
    'callback', @(~,~) filter_button_callback('workers'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);


details_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.weak,...
    'String', 'View details', 'Units', 'normalized', 'Position', [0.01 0.17 0.1 0.0499],...
    'callback', @(~,~) details, 'ForegroundColor', 'k', 'FontName', 'Consolas', 'FontSize', 12);

refresh_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.weak,...
    'String', 'Refresh', 'Units', 'normalized', 'Position', [0.01 0.12 0.1 0.0499],...
    'callback', @(~,~) refresh(), 'ForegroundColor', 'k', 'FontName', 'Consolas', 'FontSize', 12);


other_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.red,...
    'String', 'Delete task(s)', 'Units', 'normalized', 'Position', [0.01 0.07 0.1 0.0499],...
    'callback', @(~,~) other_callback(), 'ForegroundColor', 'w', ...
    'FontName', 'Consolas', 'FontSize', 12, 'FontWeight', 'bold');

restart_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.red,...
    'String', 'Restart Cluster', 'Units', 'normalized', 'Position', [0.01 0.02 0.1 0.0499],...
    'callback', @(~,~) restart_cluster, 'ForegroundColor', 'w', ...
    'FontName', 'Consolas', 'FontSize', 12, 'FontWeight', 'bold');

command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
    'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
    'Units', 'normalized', 'Position', [0.12 0.02 0.87 0.95], ...
    'Callback', @(~,~) listbox_callback, 'BackgroundColor', colors.list_background, 'Value', 1);

numeric_stats_box = uicontrol(fig, 'Style', 'text','BackgroundColor', colors.list_background, ...
    'String', 'numeric', 'Units', 'normalized', 'Position', [0.01 0.24 0.1 0.1299], ...
    'FontName', 'Consolas', 'FontSize', 12, 'HorizontalAlignment', 'left');

refresh()

    function filter_button_callback(category)
        [data, numeric_data] = mrc.get_cluster_status(category);
        numeric_stats_box.String = [...
            'Pending: ' numeric_data.num_pending char(10) ...
            'Ongoing: ' numeric_data.num_ongoing char(10) ...
            'Finished: ' numeric_data.num_finished char(10) ...
            'Failed: ' numeric_data.num_failed char(10) ...
            'Uptime: ' numeric_data.uptime];
            
        gui_status.active_filter_button = category;
        structfun(@(button) set(button, 'BackgroundColor', colors.weak), filter_buttons)
        structfun(@(button) set(button, 'ForegroundColor', 'k'), filter_buttons)
        filter_buttons.(category).BackgroundColor = colors.strong;
        filter_buttons.(category).ForegroundColor = 'w';
        command_list.Value = 1;
        command_list.String = {};
        switch category
            case 'pending'
                other_button.String = 'Delete Task(s)';
                if ~isempty(data)
                    command_list.String = strcat("[", data.created_on, "] (",...
                        data.created_by, "): ", data.command);
                end
            case 'ongoing'
                other_button.String = 'Stop Task(s)';
                if ~isempty(data)
                    command_list.String = strcat("[", data.started_on, "] (",...
                        data.created_by, "->", data.worker, "): ", data.command);
                end
            case 'finished'
                other_button.String = 'Clear';
                if ~isempty(data)
                    command_list.String = strcat("[", data.finished_on, "] (",...
                        data.created_by, "->", data.worker, "): ", data.command);
                end
            case 'failed'
                other_button.String = 'Clear';
                if ~isempty(data)
                    command_list.String = strcat("[",data.failed_on, "] (",...
                        data.created_by, "->", data.worker, "): ", data.command);
                end
            case 'workers'
                other_button.String = 'Kill Worker(s)';
                if ~isempty(data)
                    command_list.String = strcat("[", data.key, "] (", ...
                        data.computer, "): ",data.status);
                end
        end
        
    end


    function refresh()
        filter_button_callback(gui_status.active_filter_button)
        fig.Name = ['Matlab Redis Runner, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
    end

    function other_callback()
        switch gui_status.active_filter_button
            case 'pending'
                tasks_to_stop = command_list.Value;
                for task_key = data.key(tasks_to_stop)'
                    mrc.redis_cmd(['LREM pending_tasks 0 "' char(task_key) '"'])
                end
            case 'ongoing'
                tasks_to_stop = command_list.Value;
                for task_key = data.key(tasks_to_stop)'
                    worker_key = mrc.redis_cmd(['HGET ' char(task_key) ' worker']);
                    mrc.redis_cmd(['HSET ' char(worker_key) ' status restart'])
                end
            case 'finished'
                mrc.redis_cmd(['DEL finished_tasks'])
            case 'failed'
                mrc.redis_cmd(['DEL failed_tasks'])
            case 'workers'
                workers_to_kill = command_list.Value;
                for worker_key = data.key(workers_to_kill)'
                    if strcmpi(mrc.redis_cmd(['HGET ' char(worker_key) ' status']), 'active')
                        mrc.redis_cmd(['HSET ' char(worker_key) ' status kill'])
                    end
                end
        end
        refresh()
    end



    function details()
        entries = command_list.Value;
        if isempty(data)
            return
        end
        for entry = entries(:)'
            strcells = strcat(fieldnames(table2struct(data(entry,:))), ' : "', cellstr(table2cell(data(entry,:))'), '"');
            Hndl = figure('MenuBar', 'none', 'Name', 'details',...
                'NumberTitle' ,'off', 'Units', 'normalized');
            uicontrol(Hndl, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.01 0.01 0.98 0.9], 'String', strcells,...
                'Callback', @(~,~) close(Hndl), 'FontSize', 16, 'FontName', 'Consolas')
            drawnow
        end
    end

    function listbox_callback()
        if strcmp(get(gcf,'selectiontype'),'open')
            details()
        end
    end

    function restart_cluster()
        mrc.flush_db;
        refresh;
    end
end
