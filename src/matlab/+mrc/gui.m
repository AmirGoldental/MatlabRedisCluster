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
uimenu(actions_menu, 'Text', 'Activate all workers', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Restart Cluster', ...
    'MenuSelectedFcn', @action, 'ForegroundColor', [0.7,0,0]);
    function action(action_menu, ~)
        switch action_menu.Text
            case 'Abort all tasks'
                mrc.redis_cmd('DEL pending_tasks');
                ongoing_tasks = split(mrc.redis_cmd('LRANGE ongoing_tasks 0 -1'), newline);
                if isempty(ongoing_tasks{1})
                    return
                end
                mrc.redis_cmd(cellfun(@(task) ['HSET ' char(task.worker) ' status restart'],...
                    get_redis_hash(ongoing_tasks), 'UniformOutput', false));
            case 'Clear finished'
                mrc.redis_cmd('DEL finished_tasks')
            case 'Clear failed'
                mrc.redis_cmd('DEL failed_tasks')
            case 'Suspend all workers'
                mrc.change_key_status('all_workers', 'suspended')
            case 'Activate all workers'
                mrc.change_key_status('all_workers', 'active')
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
button_length = 0.13;
button_height = 0.04;
button_y_ofset = 0.95;

filter_buttons.pre_pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pre Pending Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
    'Position', [0.01, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('pre_pending'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.pending = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Pending Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
    'Position', [0.01 + button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('pending'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.ongoing = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Ongoing Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 2*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('ongoing'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.finished = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Finished Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 3*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('finished'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.failed = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Failed Tasks', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 4*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('failed'), 'FontName', 'Consolas', 'FontSize', 12);
filter_buttons.workers = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Workers', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press,...
    'Position', [0.01 + 5*button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) filter_button_callback('workers'), 'FontName', 'Consolas', 'FontSize', 12);


command_list = uicontrol(fig, 'Style', 'listbox', 'String', {}, ...
    'FontName', 'Consolas', 'FontSize', 16, 'Max', 2,...
    'Units', 'normalized', 'Position', [0.01, 0.02, 0.98, button_y_ofset-0.02], ...
    'Callback', @(~,~) listbox_callback, 'KeyPressFcn', @fig_key_press, ...
    'BackgroundColor', colors.list_background, 'Value', 1);

context_menus.pre_pending = uicontextmenu(fig);
uimenu(context_menus.pre_pending, 'Text', 'Remove', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);
uimenu(context_menus.pre_pending, 'Text', 'Force Start', 'MenuSelectedFcn', @(~,~) move_selected_tasks_to_pending);

context_menus.pending = uicontextmenu(fig);
uimenu(context_menus.pending, 'Text', 'Remove', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);
uimenu(context_menus.pending, 'Text', 'Mark as finished', 'MenuSelectedFcn', @(~,~) mark_selceted_tasks_as_finished);

context_menus.ongoing = uicontextmenu(fig);
uimenu(context_menus.ongoing, 'Text', 'Abort', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);

context_menus.failed = uicontextmenu(fig);
uimenu(context_menus.failed, 'Text', 'Clear', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);
uimenu(context_menus.failed, 'Text', 'Retry', 'MenuSelectedFcn', @(~,~) move_selected_tasks_to_pending);
uimenu(context_menus.failed, 'Text', 'Mark as finished', 'MenuSelectedFcn', @(~,~) mark_selceted_tasks_as_finished);

context_menus.finished = uicontextmenu(fig);
uimenu(context_menus.finished, 'Text', 'Clear', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);
uimenu(context_menus.finished, 'Text', 'Retry', 'MenuSelectedFcn', @(~,~) move_selected_tasks_to_pending);

context_menus.workers = uicontextmenu(fig);
uimenu(context_menus.workers, 'Text', 'Kill', 'MenuSelectedFcn', @(~,~) kill_selceted_workers);
uimenu(context_menus.workers, 'Text', 'Suspend', 'MenuSelectedFcn', @(~,~) suspend_selceted_workers);
uimenu(context_menus.workers, 'Text', 'Activate', 'MenuSelectedFcn', @(~,~) activate_selceted_workers);

load_more_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Load More', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
    'Position', [0.99-button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) refresh(), 'FontName', 'Consolas', 'FontSize', 12);

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
        
        cluster_status = mrc.get_cluster_status();
        filter_buttons.pre_pending.String = [num2str(cluster_status.num_pre_pending) ' Pre-pending Tasks'];
        filter_buttons.pending.String = [num2str(cluster_status.num_pending) ' Pending Tasks'];
        filter_buttons.ongoing.String = [num2str(cluster_status.num_ongoing) ' Ongoing Tasks'];
        filter_buttons.finished.String = [num2str(cluster_status.num_finished) ' Finished Tasks'];
        filter_buttons.failed.String = [num2str(cluster_status.num_failed) ' Failed Tasks'];
        filter_buttons.workers.String = [num2str(cluster_status.num_workers) ' Workers'];
        
        if strcmp(category, 'workers')
            keys = arrayfun(@(worker_id) {['worker:' num2str(worker_id)]}, (1:cluster_status.num_workers)');
            load_more_button.Enable = 'off';
            if numel(keys) == 0
                command_list.String = '';
                command_list.UserData.keys = [];  
                return              
            end
            
            workers = get_redis_hash(keys);                
            workers = workers(cellfun(@(worker) ~any(strcmpi(worker.status, {'kill','dead'})), workers));
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
                worker.computer, "): ", worker.status), workers);
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
        tasks2download = setdiff(task_ids, find(~cellfun(@isempty, mrc.get_tasks())), 'stable');
        tasks2download = tasks2download(1:min(items_per_load, end));
        tasks = mrc.get_tasks('download', tasks2download);
        
        % fix inconsistent status
        tasks2update = tasks(task_ids(task_ids<=numel(tasks)));
        tasks2update = tasks2update(~cellfun(@isempty,tasks2update));
        tasks2update = tasks2update(cellfun(@(task) ~strcmpi(task.status, category), tasks2update));
        tasks2update = cellfun(@(task) str2double(task.id), tasks2update);
        tasks = mrc.get_tasks('download', tasks2update);
        
        % remove not downloaded yet or other status
        tasks = tasks(task_ids(task_ids<=numel(tasks)));
        tasks = tasks(~cellfun(@isempty, tasks));
        tasks = tasks(cellfun(@(task) strcmpi(task.status, category), tasks));
        
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

        if size(command_list.String,1) < cluster_status.(['num_' category])
            load_more_button.Enable = 'on';
        else
            load_more_button.Enable = 'off';
        end
        
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
        
        if strncmp(key, 'task', 4) % task
            if any(strcmpi(key_struct.status, {'failed', 'finished'}))
                uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                    'Position', [0.01 0.01 0.18 0.05], 'FontSize', 13, ...
                    'String', 'Retry', 'Callback', @(~,~) retry_task(key_struct, 'refresh'))
                uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                    'Position', [0.21 0.01 0.18 0.05], 'FontSize', 13, ...
                    'String', 'Retry on this machine', 'Callback', @(~,~) retry_task_on_this_machine(key_struct))
                
                logfile = fullfile(conf.log_path, strrep([get_db_id() '_' char(key_struct.key) '_' char(key_struct.worker) '.txt'], ':', '-'));
                if exist(logfile, 'file')
                    uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                        'Position', [0.41 0.01 0.18 0.05], 'FontSize', 13, ...
                        'String', 'Load Log', 'Callback', @(~,~) set(edit_widget, 'String', textread(logfile, '%[^\n]')))
                end
                if strcmpi(key_struct.status, 'failed')
                    uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                        'Position', [0.61 0.01 0.18 0.05], 'FontSize', 13, ...
                        'String', 'Mark as finishd', 'Callback', @(~,~) mrc.change_key_status(key_struct.key, 'finished'))
                end
            elseif strcmpi(key_struct.status, 'pre_pending')
                uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                    'Position', [0.01 0.01 0.18 0.05], 'FontSize', 13, ...
                    'String', 'Force Start', 'Callback', @(~,~) mrc.change_key_status(key_struct.key, 'pending'))
            end
        end
        drawnow
    end

    function listbox_callback()
        if strcmp(get(gcf,'selectiontype'),'open')
            details()
        end
    end

    function kill_selceted_workers()
        for worker_key = command_list.UserData.keys(command_list.Value)'
            if ~strcmpi(mrc.redis_cmd(['HGET ' char(worker_key{1}) ' status']), 'dead')
                mrc.redis_cmd(['HSET ' char(worker_key{1}) ' status kill'])
            end
        end
        refresh;
    end

    function suspend_selceted_workers()
        mrc.change_key_status(command_list.UserData.keys(command_list.Value), 'suspended')
        refresh;
    end
    
    function activate_selceted_workers()
        mrc.change_key_status(command_list.UserData.keys(command_list.Value), 'active')
        pause(1)
        refresh;
    end

    function move_selected_tasks_to_pending()
        mrc.change_key_status(command_list.UserData.keys(command_list.Value), 'pending');
        refresh;
    end

    function mark_selceted_tasks_as_finished()
        mrc.change_key_status(command_list.UserData.keys(command_list.Value), 'finished')
        refresh;
    end


    function remove_selceted_tasks()
        switch gui_status.active_filter_button
            case 'pre_pending'
                for task_key = command_list.UserData.keys(command_list.Value)
                    mrc.redis_cmd(['LREM pre_pending_tasks 0 "' char(task_key{1}) '"'])
                end
            case 'pending'
                for task_key = command_list.UserData.keys(command_list.Value)
                    mrc.redis_cmd(['LREM pending_tasks 0 "' char(task_key{1}) '"'])
                end
            case 'ongoing'
                for task_key = command_list.UserData.keys(command_list.Value)
                    worker_key = mrc.redis_cmd(['HGET ' char(task_key{1}) ' worker']);
                    mrc.redis_cmd(['HSET ' char(worker_key) ' status restart'])
                end
            case 'finished'
                for task_key = command_list.UserData.keys(command_list.Value)
                    mrc.redis_cmd(['LREM finished_tasks 0 "' char(task_key{1}) '"'])
                end
            case 'failed'
                for task_key = command_list.UserData.keys(command_list.Value)
                    mrc.redis_cmd(['LREM failed_tasks 0 "' char(task_key{1}) '"'])
                end
        end
        refresh;
    end

    function fig_key_press(~, key_data)
        switch key_data.Key
            case 'f5'
                refresh()
            case 'delete'
                remove_selceted_tasks()
        end
    end

    function retry_task(task, varargin)
        mrc.change_key_status(task.key, 'pending')
        if any(strcmpi('refresh', varargin))
            refresh();
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
