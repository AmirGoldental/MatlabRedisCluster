function gui()
persistent tasks
persistent db_id

items_per_load = 30;
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


actions_menu= uimenu(fig, 'Text', 'Actions');
uimenu(actions_menu, 'Text', 'Clear finished', ...
    'MenuSelectedFcn', @(~,~) clear_all_finished());
uimenu(actions_menu, 'Text', 'Clear failed', ...
    'MenuSelectedFcn', @(~,~) clear_all_failed());
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

context_menu.hndl = uicontextmenu(fig);
context_menu.clear = uimenu(context_menu.hndl, 'Text', 'Clear/Abort', 'MenuSelectedFcn', @(~,~) remove_selceted_tasks);
context_menu.retry = uimenu(context_menu.hndl, 'Text', 'Retry', 'MenuSelectedFcn', @(~,~) retry_selceted_tasks, 'Visible', 'off');
context_menu.refresh = uimenu(context_menu.hndl, 'Text', 'Refresh (F5)', 'MenuSelectedFcn', @(~,~) refresh);
command_list.ContextMenu = context_menu.hndl;

load_more_button = uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Load More', 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
    'Position', [0.99-button_length, button_y_ofset, button_length, button_height], ...
    'callback', @(~,~) refresh(), 'FontName', 'Consolas', 'FontSize', 12);

refresh()

    function download_tasks(task_ids, items_per_load)
        % task_ids are sorted by priority
        tasks2download = setdiff(task_ids, find(~cellfun(@isempty, tasks)), 'stable');
        tasks2download = tasks2download(1:min(items_per_load, end));
        keys = arrayfun(@(task_id) ['task:' num2str(task_id)], tasks2download(:), 'UniformOutput', false);
        if isempty(keys)
            return
        elseif numel(keys) == 1
            tasks(tasks2download) = {get_redis_hash(keys)};
        else
            tasks(tasks2download) = get_redis_hash(keys);
        end
    end

    function refresh()
        fig.Name = ['Matlab Redis Cluster, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
        category = gui_status.active_filter_button;
        
        structfun(@(button) set(button, 'BackgroundColor', colors.weak), filter_buttons)
        structfun(@(button) set(button, 'FontWeight', 'normal'), filter_buttons)
        filter_buttons.(category).BackgroundColor = colors.strong;
        filter_buttons.(category).FontWeight = 'Bold';
        command_list.Value = [];
        command_list.String = {};
        
        cluster_status = mrc.get_cluster_status();
        filter_buttons.pending.String = [num2str(cluster_status.num_pending) ' Pending Tasks'];
        filter_buttons.ongoing.String = [num2str(cluster_status.num_ongoing) ' Ongoing Tasks'];
        filter_buttons.finished.String = [num2str(cluster_status.num_finished) ' Finished Tasks'];
        filter_buttons.failed.String = [num2str(cluster_status.num_failed) ' Failed Tasks'];
        filter_buttons.workers.String = [num2str(cluster_status.num_workers) ' Workers'];
        
        if strcmp(category, 'workers')
            keys = arrayfun(@(worker_id) {['worker:' num2str(worker_id)]}, (1:cluster_status.num_workers)');
            
            context_menu.retry.Visible = 'off';
            load_more_button.Enable = 'off';
            if numel(keys) == 0
                command_list.String = '';
                command_list.UserData.keys = [];                
            end
            if numel(keys) == 1
                data_cells = {get_redis_hash(keys)};
                keys = {keys};
            else
                data_cells = get_redis_hash(keys);
            end
                command_list.String = cellfun(@(datum, key) strcat("[", key, "] (", ...
                    datum.computer, "): ",datum.status), data_cells, keys);
                command_list.UserData.keys = keys;
            return
        end
        
        % allocate space for new tasks
        if ~strcmp(db_id, get_db_id())
            db_id = get_db_id();
            tasks = cell(0);
        end
        if numel(tasks) < cluster_status.num_tasks
            tasks{cluster_status.num_tasks} = {};
        end
        
        task_ids = cellfun(@(task_key) str2double(task_key(6:end)), ...
            split(mrc.redis_cmd(['lrange ' category '_tasks 0 -1']), newline));
        if isnan(task_ids)
            command_list.String = '';
            command_list.UserData.keys = [];
            return
        end
        downloaded_task_ids = intersect(task_ids, find(~cellfun(@isempty, tasks)), 'stable');
        % find tasks that were downloaded but now the status is changed
        changed_tasks = downloaded_task_ids(...
            arrayfun(@(task_id) ~strcmpi(tasks{task_id}.status, category), downloaded_task_ids));
        tasks(changed_tasks) = {[]};
        download_tasks(task_ids, items_per_load) 
        
        downloaded_task_ids = intersect(task_ids, find(~cellfun(@isempty, tasks)), 'stable');
        changed_tasks = downloaded_task_ids(...
            arrayfun(@(task_id) ~strcmpi(tasks{task_id}.status, category), downloaded_task_ids));
        tasks(changed_tasks) = {[]};
        downloaded_task_ids = setdiff(downloaded_task_ids, changed_tasks, 'stable');
        
        switch category
            case 'pending'
                context_menu.retry.Visible = 'off';
                command_list.String = cellfun(@(task) strcat("[", task.created_on, "] (",...
                    task.created_by, "): ", task.command), tasks(downloaded_task_ids));
            case 'ongoing'
                context_menu.retry.Visible = 'off';
                command_list.String = cellfun(@(task) strcat("[", task.started_on, "] (",...
                    task.created_by, "->", task.worker, "): ", task.command), tasks(downloaded_task_ids));
            case 'finished'
                context_menu.retry.Visible = 'on';
                command_list.String = cellfun(@(task) strcat("[", task.finished_on, "] (",...
                    task.created_by, "->", task.worker, "): ", task.command), tasks(downloaded_task_ids));
            case 'failed'
                context_menu.retry.Visible = 'on';                
                command_list.String = cellfun(@(datum) strcat("[",datum.failed_on, "] (",...
                        datum.created_by, "->", datum.worker, "): ", datum.command), tasks(downloaded_task_ids));
        end
        command_list.UserData.keys = cellfun(@(task) task.key, tasks(downloaded_task_ids), 'UniformOutput', false);

        if size(command_list.String,1) < cluster_status.(['num_' category])
            load_more_button.Enable = 'on';
        else
            load_more_button.Enable = 'off';
        end
        
    end

    function clear_all_finished()
        mrc.redis_cmd('DEL finished_tasks')
        refresh()
    end

    function clear_all_failed()
        mrc.redis_cmd('DEL failed_tasks')
        refresh()
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
        uicontrol(Hndl, 'Style', 'edit', 'Units', 'normalized', 'max', 2, ...
            'Position', [0.01 0.07 0.98 0.92], 'String', strcells,...
            'Callback', @(~,~) close(Hndl), 'FontSize', 12, ...
            'FontName', 'Consolas', 'HorizontalAlignment', 'left');
        drawnow
        if any(strcmpi(gui_status.active_filter_button, {'failed', 'finished'}))
            uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.01 0.01 0.1 0.05], 'FontSize', 13, ...
                'String', 'Retry', 'Callback', @(~,~) retry_task(key_struct, 'refresh'))
            uicontrol(Hndl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.12 0.01 0.2 0.05], 'FontSize', 13, ...
                'String', 'Retry on this machine', 'Callback', @(~,~) retry_task_on_this_machine(key_struct))
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
    
    function remove_selceted_tasks()
        switch gui_status.active_filter_button
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
            case 'workers'
                for worker_key = command_list.UserData.keys(command_list.Value)'
                    if strcmpi(mrc.redis_cmd(['HGET ' char(worker_key{1}) ' status']), 'active')
                        mrc.redis_cmd(['HSET ' char(worker_key{1}) ' status kill'])
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
                remove_selceted_tasks()
        end
    end
    
    function retry_selceted_tasks()
        task_keys = command_list.UserData.keys(command_list.Value);
        task_keys = cellfun(@(task_key) char(task_key), task_keys, 'UniformOutput', false);
        task_ids = cellfun(@(task_key) str2double(task_key(6:end)), task_keys);
        download_tasks(task_ids, items_per_load) 
        cellfun(@retry_task, tasks(task_ids));
        refresh()
    end

    function retry_task(task, varargin)
         mrc.new_task(task.command, 'path', task.path2add);
         if any(strcmpi('refresh', varargin))
             refresh();
         end
    end
    
    function retry_task_on_this_machine(task)
        path2add = char(task.path2add);
        if ~strcmpi(path2add, 'None')
            disp(['>> addpath(' path2add ')']);
            evalin('base', ['addpath(' path2add ')'])
        end
        disp(['>> ' char(task.command)])
        evalin('base', task.command)
    end


end
