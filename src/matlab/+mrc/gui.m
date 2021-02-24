function gui()
colors = struct();
colors.background = '#eeeeee';
colors.list_background = '#cccccc';
colors.red = '#cf4229';
colors.strong = '#bbbbbb';
colors.weak = '#dddddd';

fig = figure('Name', 'Matlab Redis Cluster', 'MenuBar', 'none', ...
    'NumberTitle', 'off', 'Units', 'normalized', ...
    'Color', colors.background, 'KeyPressFcn', @fig_key_press);
fig.Position = [0.02 0.04 0.95 0.85];
data = [];

actions_menu= uimenu(fig, 'Text', 'Actions');
uimenu(actions_menu, 'Text', 'Refresh (F5)', 'MenuSelectedFcn', @(~,~) refresh());
uimenu(actions_menu, 'Text', 'Clear finished', ...
    'MenuSelectedFcn', @(~,~) mrc.redis_cmd(['DEL finished_tasks']));
uimenu(actions_menu, 'Text', 'Clear failed', ...
    'MenuSelectedFcn', @(~,~) mrc.redis_cmd(['DEL failed_tasks']));
uimenu(actions_menu, 'Text', 'Restart Cluster', ...
    'MenuSelectedFcn', @(~,~) restart_cluster, 'ForegroundColor', [0.7,0,0]);

gui_status.active_filter_button = 'pending';
button_length = 0.13;
button_height = 0.04;
button_y_ofset = 0.95;

filter_buttons.pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pending Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
    'Position', [0.01, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('pending'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.ongoing = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('ongoing'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.finished = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Finished Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 2*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('finished'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.failed = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Failed Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 3*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('failed'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.workers = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 4*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('workers'), 'FontName', 'Consolas', 'FontSize', 12);


command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
    'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
    'Units', 'normalized', 'Position', [0.01, 0.02, 0.98, button_y_ofset-0.02], ...
    'Callback', @(~,~) listbox_callback, 'KeyPressFcn', @fig_key_press, ...
    'BackgroundColor', colors.list_background, 'Value', 1);

refresh()

    function filter_button_callback(category)
        gui_status.active_filter_button = category;
        refresh();        
    end


    function refresh()
        category = gui_status.active_filter_button;
        [data, numeric_data] = mrc.get_cluster_status(category);
        filter_buttons.pending.String = [numeric_data.num_pending ' Pending Tasks'];
        filter_buttons.ongoing.String = [numeric_data.num_ongoing ' Ongoing Tasks'];
        filter_buttons.finished.String = [numeric_data.num_finished ' Finished Tasks'];
        filter_buttons.failed.String = [numeric_data.num_failed ' Failed Tasks'];
        filter_buttons.workers.String = [numeric_data.num_workers ' Workers'];
        
        structfun(@(button) set(button, 'BackgroundColor', colors.weak), filter_buttons)
        %structfun(@(button) set(button, 'ForegroundColor', 'k'), filter_buttons)
        filter_buttons.(category).BackgroundColor = colors.strong;
        %filter_buttons.(category).ForegroundColor = 'w';
        filter_buttons.(category).FontWeight = 'Bold';
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
        fig.Name = ['Matlab Redis Runner, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
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
        answer = questdlg('Are you sure you want to restart the cluster?', ...
            'Restart cluster', ...
            'Yes','No','No');
        % Handle response
        if strcmpi(answer, 'yes')
            mrc.flush_db;
            refresh;
        end
    end
    
    function list_entries_delete()
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
                tasks_to_clear = command_list.Value;
                mrc.redis_cmd(['SREM finished_tasks ' char(join(data.key(tasks_to_clear), ' '))]);
            case 'failed'
                tasks_to_clear = command_list.Value;
                mrc.redis_cmd(['SREM failed_tasks ' char(join(data.key(tasks_to_clear), ' '))]);
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

    function fig_key_press(~, key_data)
        switch key_data.Key
            case 'f5'
                refresh()
            case 'delete'
                list_entries_delete()
        end
    end
end
