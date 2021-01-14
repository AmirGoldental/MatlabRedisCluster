function output = mrr(varargin)
%mrr is Matlab Redis Runner's Matlab CLI
% Commands:
%   mrr set_config_files <paths_to_files>
%   mrr gui
%   mrr get_status
%   mrr join_worker_pool
%       Sets the current Matlab as a worker of the redis pool
%   mrr send_task <matlab command str>
%       Sends the command str to the commands queue
%   mrr send_task -wait str
%       Sends the command str to the commands queue and wait execution
%   mrr('send_tasks', tasks_cell_array)
%       Sens a set of tasks
%   mrr('send_tasks','-wait', tasks cell array): 
%       Sends a set of tasks and wait execution
%   Note: In addition to the -wait flag, it is possible to add -python or
%         -exec flag to change the task type

if all(ischar(varargin))
    % CLI mode
    switch numel(varargin)
        case 1
            if strcmpi(arargin{1}, 'gui')
                mrr.gui
            elseif varargin{1} == 'get_status'
                error('Not yet implemented')
            end
        case 2 
    end
else
    % Command mode
end
error('Unable to parse command') 

end

