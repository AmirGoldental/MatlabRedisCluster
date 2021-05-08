%% Add new task to cluster
mrc.new_task("disp('Hello World!')")

%% Show GUI
mrc.gui;

%% Start a worker
mrc.start_worker

%% Show GUI
mrc.gui;

%% Add many tasks
for itter = 1:30
    mrc.new_task(['disp(''' num2str(itter) ''')'])
end

%% Show GUI
mrc.gui;

%% Start a worker
mrc.start_worker

%% Plot Progress
mrc.plot_tasks;

%% Add tasks with depenencies
first_task = mrc.new_task('pause(10)');
mrc.new_task("disp('Finally')", 'dependencies', first_task);