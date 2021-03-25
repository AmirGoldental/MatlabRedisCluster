tasks = mrc.get_tasks({[]}, 1:1000, 1000);

tasks = tasks(cellfun(@(x) isfield(x, 'status'), tasks));
status = cellfun(@(x) x.status, tasks);
finished_tasks = tasks(strcmpi(status, 'finished'));

workers = cellfun(@(x) x.worker, finished_tasks);
start_time = cellfun(@(x) datenum(x.started_on), finished_tasks);
end_time = cellfun(@(x) datenum(x.finished_on), finished_tasks);

[~, ~, workers_inds] = unique(workers);
figure; hold on;
x0 = start_time;
x1 = end_time;%start_time + 0.1; %end_time;
y0 = workers_inds;
y1 = workers_inds + 0.99;
for i = 1:length(x0)
    fill([x0(i) x0(i) x1(i) x1(i)], [y0(i) y1(i) y1(i) y0(i)], 'r');
end
axis auto