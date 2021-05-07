function terminate_cluster()
% Kill all workers and close redis server
mrc.set_worker_status('all', 'dead');
if ~wait_for_condition(@() mrc.redis().scard('available_workers') == '0')
    warning('Not sure all workers are dead');
end
mrc.redis().shutdown('NOSAVE');
end

