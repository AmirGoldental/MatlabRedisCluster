function gui()
colors = struct();
colors.background = '#d9d9d9';
colors.list_background = '#F1F1F1';
colors.red = '#ff3333';
colors.strong = '#1C4E80';
colors.weak = '#33ccff';

fig = figure('Name', 'Matlab Redis Cluster', 'MenuBar', 'none', 'Color', colors.background);
fig.NumberTitle = 'off';
fig.Units = 'normalized';
fig.Position = [0.02 0.04 0.95 0.85];
data = [];
gui_status.active_filter_button = 'pending';

x0 = 0;
xi = 0.88 / 5;
w = xi;
h = 0.0499;
filter_buttons.pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pending Tasks', 'Units', 'normalized', 'Position', [x0 0.95 w h],...
    'callback', @(~,~) filter_button_callback('pending'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.ongoing = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'Position', [x0+xi 0.95 w h],...
    'callback', @(~,~) filter_button_callback('ongoing'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.finished = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Finished Tasks', 'Units', 'normalized', 'Position', [x0+xi*2 0.95 w h],...
    'callback', @(~,~) filter_button_callback('finished'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.failed = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Failed Tasks', 'Units', 'normalized', 'Position', [x0+xi*3 0.95 w h],...
    'callback', @(~,~) filter_button_callback('failed'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.workers = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'Position', [x0+xi*4 0.95 w h],...
    'callback', @(~,~) filter_button_callback('workers'), 'ForegroundColor', 'w', 'FontName', 'Consolas', 'FontSize', 12);

x0 = 0.89;
y0 = 0.93;
yi = -0.05;
details_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.weak,...
    'String', 'View Details', 'Units', 'normalized', 'Position', [x0 y0 0.1 0.0499],...
    'callback', @(~,~) details, 'ForegroundColor', 'k', 'FontName', 'Consolas', 'FontSize', 12);

refresh_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.weak,...
    'String', 'Refresh', 'Units', 'normalized', 'Position', [x0 y0+yi 0.1 0.0499],...
    'callback', @(~,~) refresh(), 'ForegroundColor', 'k', 'FontName', 'Consolas', 'FontSize', 12);

other_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.red,...
    'String', 'Delete task(s)', 'Units', 'normalized', 'Position', [x0 y0+yi*2 0.1 0.0499],...
    'callback', @(~,~) other_callback(), 'ForegroundColor', 'w', ...
    'FontName', 'Consolas', 'FontSize', 12, 'FontWeight', 'bold');

restart_button = uicontrol(fig, 'Style', 'pushbutton', 'BackgroundColor', colors.red,...
    'String', 'Restart Cluster', 'Units', 'normalized', 'Position', [x0 y0+yi*3 0.1 0.0499],...
    'callback', @(~,~) restart_cluster, 'ForegroundColor', 'w', ...
    'FontName', 'Consolas', 'FontSize', 12, 'FontWeight', 'bold');

command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
    'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
    'Units', 'normalized', 'Position', [0 0.03 0.88 0.92], ...
    'Callback', @(~,~) listbox_callback, 'BackgroundColor', colors.list_background, 'Value', 1);

status_bar = uicontrol(fig, 'Style', 'text','BackgroundColor', colors.list_background, ...
    'String', 'numeric', 'Units', 'normalized', 'Position', [0 0 0.88 0.029], ...
    'FontName', 'Consolas', 'FontSize', 12, 'HorizontalAlignment', 'left');

refresh()

    function filter_button_callback(category)
        [data, numeric_data] = mrc.get_cluster_status(category);
        status_bar.String = sprintf('Pending: %3s\t Ongoing: %3s\t Finished: %3s\t Failed: %3s\t Uptime: %3s\t', ...
            numeric_data.num_pending, numeric_data.num_ongoing, numeric_data.num_finished, ...
            numeric_data.num_failed, numeric_data.uptime);
            
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
            for cell_idx = 1:numel(strcells)
                cell_content = strcells{cell_idx};
                cell_content = join(split(cell_content, ',\n'), [', ' newline '  ']);
                strcells{cell_idx} = cell_content{1};
            end
            Hndl = figure('MenuBar', 'none', 'Name', 'details',...
                'NumberTitle' ,'off', 'Units', 'normalized');
            uicontrol(Hndl, 'Style', 'edit', 'Units', 'normalized', 'max', 2, ...
                'Position', [0.01 0.01 0.98 0.98], 'String', strcells,...
                'Callback', @(~,~) close(Hndl), 'FontSize', 12, ...
                'FontName', 'Consolas', 'HorizontalAlignment', 'left');
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
