function gui()

items_per_load = 10;
colors = struct();
colors.background = '#eeeeee';
colors.list_background = '#cccccc';
colors.red = '#cf4229';
colors.strong = '#bbbbbb';
colors.weak = '#dddddd';

conf = read_conf_file;

fig = figure('Name', 'Matlab Redis Cluster', 'MenuBar', 'none', ...
    'NumberTitle', 'off', 'Units', 'normalized', ...
    'Color', colors.background, 'KeyPressFcn', @fig_key_press);
fig.Position = [0.02 0.04 0.95 0.85];

actions_menu= uimenu(fig, 'Text', 'Actions');
uimenu(actions_menu, 'Text', 'Abort all tasks', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Clear finished', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Clear failed', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Suspend all workers', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Activate\Restart all workers', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Restart Cluster', ...
    'MenuSelectedFcn', @action, 'ForegroundColor', [0.7,0,0]);
    function action(action_menu, ~)
        switch action_menu.Text
            case 'Abort all tasks'
                mrc.set_task_status({'all_pre_pending', 'all_pending', 'all_ongoing'}, 'deleted')
            case 'Clear finished'
                mrc.set_task_status('all_finished', 'deleted');
            case 'Clear failed'
                mrc.set_task_status('all_failed', 'deleted');
            case 'Suspend all workers'
                mrc.set_worker_status('all', 'suspended')
            case 'Activate all workers'
                mrc.set_worker_status('all', 'restart')
            case 'Restart Cluster'
                answer = questdlg('Are you sure you want to restart the cluster?', ...
                    'Restart cluster', ...
                    'Yes','No','No');
                % Handle response
                if strcmpi(answer, 'yes')
                    mrc.flush_db;
                end
        end
        pause(1)
        refresh();
    end
gui_status.active_filter_button = 'pending';
buttons_num = 0;
    function hndl = new_button(button_string, button_callback)
        button_length = 0.13;
        button_height = 0.04;
        button_y_ofset = 0.95;
        hndl = uicontrol(fig, 'Style', 'pushbutton', ...
            'String', button_string, 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
            'Position', [0.01 + buttons_num*button_length, button_y_ofset, button_length, button_height], ...
            'callback', button_callback, ...
            'FontName', 'Consolas', 'FontSize', 12);
        buttons_num = buttons_num + 1;
    end
filter_buttons.pre_pending = new_button('Pre Pending Tasks', @(~,~) filter_button_callback('pre_pending'));
filter_buttons.pending = new_button('Pending Tasks', @(~,~) filter_button_callback('pending'));
filter_buttons.ongoing = new_button('Ongoing Tasks', @(~,~) filter_button_callback('ongoing'));
filter_buttons.finished = new_button('Finished Tasks', @(~,~) filter_button_callback('finished'));
filter_buttons.failed = new_button('Failed Tasks', @(~,~) filter_button_callback('failed'));
filter_buttons.workers = new_button('Workers', @(~,~) filter_button_callback('workers'));
refresh_button = new_button('Refresh', @(~,~) refresh());
load_more_button_position = refresh_button.Position;
load_more_button_position(1) = 0.99 - load_more_button_position(3);
refresh_button.Position = load_more_button_position;

command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
    'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
    'Units', 'normalized', 'Position', [0.01, 0.02, 0.98, 0.93], ...
    'Callback', @(~,~) listbox_callback, 'KeyPressFcn', @fig_key_press, ...
    'BackgroundColor', colors.list_background, 'Value', 1);

context_menus.pre_pending = uicontextmenu(fig);
uimenu(context_menus.pre_pending, 'Text', 'Remove', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('deleted'));
uimenu(context_menus.pre_pending, 'Text', 'Force Start', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('pending'));

context_menus.pending = uicontextmenu(fig);
uimenu(context_menus.pending, 'Text', 'Remove', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('deleted'));
uimenu(context_menus.pending, 'Text', 'Mark as finished', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('finished'));

context_menus.ongoing = uicontextmenu(fig);
uimenu(context_menus.ongoing, 'Text', 'Abort', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('deleted'));

context_menus.failed = uicontextmenu(fig);
uimenu(context_menus.failed, 'Text', 'Clear', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('deleted'));
uimenu(context_menus.failed, 'Text', 'Retry', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('pending'));
uimenu(context_menus.failed, 'Text', 'Mark as finished', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('finished'));

context_menus.finished = uicontextmenu(fig);
uimenu(context_menus.finished, 'Text', 'Clear', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('deleted'));
uimenu(context_menus.finished, 'Text', 'Retry', 'MenuSelectedFcn', @(~,~) set_selected_tasks_status('pending'));

context_menus.workers = uicontextmenu(fig);
uimenu(context_menus.workers, 'Text', 'Kill', 'MenuSelectedFcn', @(~,~) set_selected_workers_status('dead'));
uimenu(context_menus.workers, 'Text', 'Suspend', 'MenuSelectedFcn', @(~,~) set_selected_workers_status('suspended'));
uimenu(context_menus.workers, 'Text', 'Activate\Restart', 'MenuSelectedFcn', @(~,~) set_selected_workers_status('restart'));


refresh()

    function refresh()
        fig.Name = ['Matlab Redis Cluster, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
        category = gui_status.active_filter_button;
        command_list.ContextMenu = context_menus.(category);
        structfun(@(button) set(button, 'BackgroundColor', colors.weak), filter_buttons)
        structfun(@(button) set(button, 'FontWeight', 'normal'), filter_buttons)
        filter_buttons.(category).BackgroundColor = colors.strong;
        filter_buttons.(category).FontWeight = 'Bold';
        command_list.Value = [];
        command_list.String = {};
        
        cluster_status = structfun(@num2str, mrc.get_cluster_status(), 'UniformOutput', false);
        filter_buttons.pre_pending.String = [cluster_status.num_pre_pending ' Pre-pending Tasks'];
        filter_buttons.pending.String = [cluster_status.num_pending ' Pending Tasks'];
        filter_buttons.ongoing.String = [cluster_status.num_ongoing ' Ongoing Tasks'];
        filter_buttons.finished.String = [cluster_status.num_finished ' Finished Tasks'];
        filter_buttons.failed.String = [cluster_status.num_failed ' Failed Tasks'];
        filter_buttons.workers.String = [cluster_status.num_workers ' Workers'];
        
        if strcmp(category, 'workers')
            worker_keys = split(strip(mrc.redis_cmd('SMEMBERS available_workers')));
            worker_keys(cellfun(@isempty, worker_keys)) = [];
            if numel(worker_keys) == 0
                command_list.String = '';
                command_list.UserData.keys = [];
                return
            end
            workers = get_redis_hash(worker_keys);
            for cell_idx = 1:numel(workers)
                if strcmpi(workers{cell_idx}.status, 'active')
                    if ~strcmpi(workers{cell_idx}.current_task, 'None')
                        workers{cell_idx}.status = 'working';
                    end
                    if (now - datenum(workers{cell_idx}.last_ping))*24*60 > 5
                        workers{cell_idx}.status = [workers{cell_idx}.status ', not responding for ' num2str(round((now - datenum(workers{cell_idx}.last_ping))*24*60)) ' minutes'];
                    end
                end
            end
            command_list.String = cellfun(@(worker) strcat("[", worker.key, "] (", ...
                worker.computer, "): ", worker.status), workers, 'UniformOutput', false);
            command_list.UserData.keys = cellfun(@(worker) worker.key, workers, 'UniformOutput', false);
            return
        end
        
        task_ids = cellfun(@(task_key) str2double(task_key(6:end)), ...
            split(mrc.redis_cmd(['LRANGE ' category '_tasks 0 500']), newline));
        if isnan(task_ids)
            command_list.String = '';
            command_list.UserData.keys = [];
            return
        end
        
        % not downloaded yet
        tasks2download = task_ids(cellfun(@isempty, ...
            mrc.get_tasks(task_ids, 'validate_status', category, 'cache_only')));
        % download
        tasks2download = tasks2download(1:min(items_per_load, end));
        mrc.get_tasks(tasks2download, 'network_only');
        % get cached after validation
        tasks = mrc.get_tasks(task_ids, 'validate_status', category , 'cache_only');
        tasks = tasks(~cellfun(@isempty, tasks));
        
        switch category
            case 'pre_pending'
                command_list.String = cellfun(@(task) strcat("[", task.created_on, "] (",...
                    task.created_by, "): ", task.command), tasks);
            case 'pending'
                command_list.String = cellfun(@(task) strcat("[", task.created_on, "] (",...
                    task.created_by, "): ", task.command), tasks);
            case 'ongoing'
                command_list.String = cellfun(@(task) strcat("[", task.started_on, "] (",...
                    task.created_by, "->", task.worker, "): ", task.command), tasks);
            case 'finished'
                command_list.String = cellfun(@(task) strcat("[", task.finished_on, "] (",...
                    task.created_by, "->", task.worker, "): ", task.command), tasks);
            case 'failed'
                command_list.String = cellfun(@(datum) strcat("[",datum.failed_on, "] (",...
                    datum.created_by, "->", datum.worker, "): ", datum.command), tasks);
        end
        command_list.UserData.keys = cellfun(@(task) task.key, tasks, 'UniformOutput', false);
    end

    function filter_button_callback(category)
        if ~strcmpi(gui_status.active_filter_button, category)
            gui_status.active_filter_button = category;
        end
        refresh();
    end

    function details()
        keys = command_list.UserData.keys(command_list.Value);
        cellfun(@show_key, keys);
    end

    function show_key(key)
        key_struct = get_redis_hash(key);
        strcells = strcat(fieldnames(key_struct), ' : "', cellstr(struct2cell(key_struct)), '"');
        for cell_idx = 1:numel(strcells)
            cell_content = strcells{cell_idx};
            cell_content = join(split(cell_content, ',\n'), [', ' newline '  ']);
            strcells{cell_idx} = cell_content{1};
        end
        Hndl = figure('MenuBar', 'none', 'Name', 'details',...
            'NumberTitle' ,'off', 'Units', 'normalized');
        Hndl.Position = [0.05 0.05 0.9 0.9];
        edit_widget = uicontrol(Hndl, 'Style', 'edit', 'Units', 'normalized', 'max', 2, ...
            'Position', [0.01 0.07 0.98 0.92], 'String', strcells,...
            'Callback', @(~,~) close(Hndl), 'FontSize', 12, ...
            'FontName', 'Consolas', 'HorizontalAlignment', 'left');
        key_buttons_num = 0;
        function hndl = new_key_button(button_string, button_callback)
            button_length = 0.18;
            button_height = 0.05;
            button_y_ofset = 0.01;
            hndl = uicontrol(Hndl, 'Style', 'pushbutton', ...
                'String', button_string, 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
                'Position', [0.01 + key_buttons_num*(button_length+0.01), button_y_ofset, button_length, button_height], ...
                'callback', button_callback, ...
                'FontName', 'Consolas', 'FontSize', 12);
            key_buttons_num = key_buttons_num + 1;
        end
        if strncmp(key, 'task', 4) % task
            if any(strcmpi(key_struct.status, {'failed', 'finished'}))
                new_key_button('Retry', @(~,~) set_selected_tasks_status('pending', key))
                new_key_button('Retry on this machine', @(~,~) retry_task_on_this_machine(key_struct))
                
                log_file_full_path = fullfile(conf.log_path, strrep(['DB_' get_db_timetag() '_' char(key_struct.key) '_' char(key_struct.worker) '.txt'], ':', '-'));
                if exist(log_file_full_path, 'file')
                    new_key_button('Show Log', @(~,~) set(edit_widget, 'String', textread(log_file_full_path, '%[^\n]')))
                end
                if strcmpi(key_struct.status, 'failed')
                    new_key_button('Mark as finishd',  @(~,~) set_selected_tasks_status('finished', key))
                end
            elseif strcmpi(key_struct.status, 'pre_pending')
                new_key_button('Force Start',  @(~,~) set_selected_tasks_status('pending', key))
            end
        end
        drawnow
    end

    function listbox_callback()
        if strcmp(get(gcf,'selectiontype'),'open')
            details()
        end
    end

    function set_selected_tasks_status(status, keys)
        if exist('keys', 'var')
            close;
        else
            keys = command_list.UserData.keys(command_list.Value);
        end
        mrc.set_task_status(keys, status, 'force')
        refresh;
    end

    function set_selected_workers_status(status)
        keys = command_list.UserData.keys(command_list.Value);
        mrc.set_worker_status(keys, status)
        refresh;
    end

    function fig_key_press(~, key_data)
        switch key_data.Key
            case 'f5'
                refresh()
        end
    end

    function retry_task_on_this_machine(task)
        path2add = char(task.path2add);
        if ~strcmpi(path2add, 'None')
            disp(['>> addpath(''' path2add ''')']);
            evalin('base', ['addpath(''' path2add ''')'])
        end
        disp(['>> ' char(task.command)])
        evalin('base', task.command)
    end

end
