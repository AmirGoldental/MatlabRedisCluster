function gui()
items_per_load = 50;
max_items_to_show = 500;
colors = struct();
colors.background = '#eeeeee';
colors.list_background = '#cccccc';
colors.red = '#cf4229';
colors.strong = '#bbbbbb';
colors.weak = '#dddddd';

conf = read_conf_file;

persistent fig fig_status buttons command_list context_menus tasks

if ishandle(fig)
    figure(fig);
    refresh();
    return
else
    fig = figure('Name', 'Matlab Redis Cluster', 'MenuBar', 'none', ...
        'NumberTitle', 'off', 'Units', 'normalized', ...
        'Color', colors.background, 'KeyPressFcn', @fig_key_press);
end
fig.Position = [0.02 0.04 0.95 0.85];

actions_menu= uimenu(fig, 'Text', 'Actions');
uimenu(actions_menu, 'Text', 'Abort all tasks', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Clear finished', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Clear failed', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Kill all workers', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Restart all workers', ...
    'MenuSelectedFcn', @action);
uimenu(actions_menu, 'Text', 'Restart Cluster', ...
    'MenuSelectedFcn', @action, 'ForegroundColor', [0.7,0,0]);
    function action(action_menu, ~)
        switch action_menu.Text
            case 'Abort all tasks'
                mrc.set_task_status({'all_pre_pending', 'all_pending', 'all_ongoing'}, 'deleted');
            case 'Clear finished'
                mrc.set_task_status('all_finished', 'deleted');
            case 'Clear failed'
                mrc.set_task_status('all_failed', 'deleted');
            case 'Kill all workers'
                mrc.set_worker_status('all', 'kill');
            case 'Restart all workers'
                mrc.set_worker_status('all', 'restart');
            case 'Restart Cluster'
                answer = questdlg('Are you sure you want to restart the cluster?', ...
                    'Restart cluster', ...
                    'Yes','No','No');
                % Handle response
                if strcmpi(answer, 'yes')
                    mrc.flush_db;
                end
        end
        pause(1);
        refresh();
    end
fig_status.active_filter_button = 'pending';
buttons_num = 0;
    function hndl = new_button(button_string, button_callback)
        button_length = 0.1;
        button_height = 0.04;
        button_y_ofset = 0.95;
        hndl = uicontrol(fig, 'Style', 'pushbutton', ...
            'String', button_string, 'Units', 'normalized', 'KeyPressFcn', @fig_key_press, ...
            'Position', [0.01 + buttons_num*button_length, button_y_ofset, button_length, button_height], ...
            'callback', button_callback, ...
            'FontName', 'Consolas', 'FontSize', 12);
        buttons_num = buttons_num + 1;
    end
buttons.pre_pending = new_button('Pre Pending Tasks', @(~,~) filter_button_callback('pre_pending'));
buttons.pending = new_button('Pending Tasks', @(~,~) filter_button_callback('pending'));
buttons.ongoing = new_button('Ongoing Tasks', @(~,~) filter_button_callback('ongoing'));
buttons.finished = new_button('Finished Tasks', @(~,~) filter_button_callback('finished'));
buttons.failed = new_button('Failed Tasks', @(~,~) filter_button_callback('failed'));
buttons.workers = new_button('Workers', @(~,~) filter_button_callback('workers'));
buttons.servers = new_button('Servers', @(~,~) filter_button_callback('servers'));

refresh_button = new_button('Refresh', @(~,~) refresh());
refresh_button_position = refresh_button.Position;
refresh_button_position(3) = 0.75*refresh_button_position(3);
refresh_button_position(1) = 0.99 - refresh_button_position(3);
refresh_button.Position = refresh_button_position;

load_more_button = new_button('Load More', @(~,~) load_tasks());
load_more_button_position = load_more_button.Position;
load_more_button_position(3) = 0.75*load_more_button_position(3);
load_more_button_position(1) = refresh_button_position(1) - load_more_button_position(3);
load_more_button.Position = load_more_button_position;

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
uimenu(context_menus.workers, 'Text', 'Kill', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_workers('kill'));
uimenu(context_menus.workers, 'Text', 'Restart', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_workers('restart'));

context_menus.servers = uicontextmenu(fig);
uimenu(context_menus.servers, 'Text', 'Kill Workers', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('kill'));
uimenu(context_menus.servers, 'Text', 'New Worker', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('new'));
uimenu(context_menus.servers, 'Text', 'Restart', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('restart'));
uimenu(context_menus.servers, 'Text', 'Restart server process', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('restart_server'));
uimenu(context_menus.servers, 'Text', 'Shutdown server process', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('shutdown'));
uimenu(context_menus.servers, 'Text', 'Install server process as service', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('install_service'));
uimenu(context_menus.servers, 'Text', 'Uninstall server process service', 'MenuSelectedFcn', @(~,~) send_cmd_to_selected_servers('uninstall_service'));

refresh()

    function refresh()        
        fig.Name = ['Matlab Redis Cluster, ' datestr(now, 'yyyy-mm-dd HH:MM:SS')];
        category = fig_status.active_filter_button;
        command_list.ContextMenu = context_menus.(category);
        structfun(@(button) set(button, 'BackgroundColor', colors.weak), buttons);
        structfun(@(button) set(button, 'FontWeight', 'normal'), buttons);
        buttons.(category).BackgroundColor = colors.strong;
        buttons.(category).FontWeight = 'Bold';
        command_list.Value = [];
        command_list.String = {};
        
        cluster_status = structfun(@num2str, mrc.get_cluster_status(), 'UniformOutput', false);
        buttons.pre_pending.String = [cluster_status.num_pre_pending ' Pre-pending Tasks'];
        buttons.pending.String = [cluster_status.num_pending ' Pending Tasks'];
        buttons.ongoing.String = [cluster_status.num_ongoing ' Ongoing Tasks'];
        buttons.finished.String = [cluster_status.num_finished ' Finished Tasks'];
        buttons.failed.String = [cluster_status.num_failed ' Failed Tasks'];
        buttons.workers.String = [cluster_status.num_workers ' Workers'];
        buttons.servers.String = [cluster_status.num_servers ' Servers'];
        
        if strcmp(category, 'workers')
            mrc.redis('reconnect');
            worker_keys = mrc.redis().smembers('available_workers');
            worker_keys(cellfun(@isempty, worker_keys)) = [];
            load_more_button.Visible = 'off';
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
                    if ~strcmpi(workers{cell_idx}.current_task, 'None')
                        workers{cell_idx}.status = [workers{cell_idx}.status  '. "' workers{cell_idx}.last_command '"'];
                    end
                    
                end
            end
            workers_strings = cellfun(@(worker) ['[' worker.computer '/' worker.key '] ' ...
                worker.status], workers, 'UniformOutput', false);
            [workers_strings, order] = sort(workers_strings);
            command_list.String = workers_strings;
            command_list.UserData.keys = cellfun(@(worker) worker.key, workers(order), 'UniformOutput', false);
            command_list.UserData.server_keys = cellfun(@(worker) worker.server_key, workers(order), 'UniformOutput', false);
        elseif strcmp(category, 'servers')
            server_keys = mrc.redis().smembers('servers');
            load_more_button.Visible = 'off';
            if numel(server_keys) == 0
                command_list.String = '';
                command_list.UserData.keys = [];
                return
            end
            servers = get_redis_hash(server_keys);
            last_ping_seconds = cellfun(@(server) {24*60*60*(now - datenum(server.last_ping, 'yyyy-mm-ddTHH:MM:SS.FFF'))}, servers);
            strings = cellfun(@(server, last_ping) ['[' server.key '] server ' ...
                server.status  ' has ' server.number_of_workers ' workers, last ping - ' num2str(last_ping) ' seconds'], servers, last_ping_seconds, 'UniformOutput', false);
            
            
            [strings, order] = sort(strings);
            command_list.String = strings;
            command_list.UserData.keys = cellfun(@(server) server.key, servers(order), 'UniformOutput', false);
        else
            tasks = get_tasks(category);
            command_list.UserData.keys = cellfun(@(task_cell) task_cell{1}, tasks, 'UniformOutput', false);
            command_list.String = cellfun(@(task_cell) task_cell{2}, tasks, 'UniformOutput', false);
        end
    end

    function load_tasks()
        loaded = numel(command_list.String);
        keys_to_load = command_list.UserData.keys((loaded+1):min(loaded+items_per_load, end));
        if ~isempty(keys_to_load)
            command_list.String = [command_list.String; get_redis_hash(keys_to_load, 'str')'];
            command_list.ListboxTop = loaded+1;
        end
        if numel(command_list.String) == numel(command_list.UserData.keys)
            load_more_button.Visible = 'off';
        else
            load_more_button.Visible = 'on';
        end
    end

    function filter_button_callback(category)
        if ~strcmpi(fig_status.active_filter_button, category)
            fig_status.active_filter_button = category;
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
                new_key_button('Retry', @(~,~) set_selected_tasks_status('pending', key));
                new_key_button('Retry on this machine', @(~,~) retry_task_on_this_machine(key_struct));
                
                mrc_path = fileparts(fileparts(mfilename('fullpath')));
                log_file_full_path = fullfile(mrc_path, conf.log_path, strrep(['DB_' get_db_timetag() '_' char(key_struct.key) '_' char(key_struct.worker) '.txt'], ':', '-'));
                if exist(log_file_full_path, 'file')
                    new_key_button('Show Log', @(~,~) set(edit_widget, 'String', textread(log_file_full_path, '%[^\n]')));
                end
                if strcmpi(key_struct.status, 'failed')
                    new_key_button('Mark as finishd',  @(~,~) set_selected_tasks_status('finished', key));
                end
            elseif strcmpi(key_struct.status, 'pre_pending')
                new_key_button('Force Start',  @(~,~) set_selected_tasks_status('pending', key));
            end
        end
        drawnow
    end

    function listbox_callback()
        if strcmp(get(gcf,'selectiontype'),'open')
            details();
        end
    end

    function set_selected_tasks_status(status, keys)
        if exist('keys', 'var')
            close;
        else
            keys = command_list.UserData.keys(command_list.Value);
        end
        mrc.set_task_status(keys, status, 'force');
        refresh;
    end

    function send_cmd_to_selected_workers(cmd)
        keys = command_list.UserData.keys(command_list.Value);
        server_keys = command_list.UserData.server_keys(command_list.Value);
        for ind = 1:length(keys)
            mrc.redis().lpush([server_keys{ind} ':cmd'], [cmd ' ' keys{ind}]);
        end
        refresh;
    end

    function send_cmd_to_selected_servers(cmd)
        keys = command_list.UserData.keys(command_list.Value);
        for ind = 1:length(keys)
            mrc.redis().lpush([keys{ind} ':cmd'], cmd);
        end
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
