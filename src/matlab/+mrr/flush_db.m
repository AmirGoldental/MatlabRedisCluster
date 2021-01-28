function flush_db()
mrr.redis_cmd('FLUSHALL');
mrr.get_cluster_status([], true);
end

