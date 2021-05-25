
import sys
from datetime import datetime
import os
import signal
import redis
import time

params_path = 'worker.conf'
params = dict()
worker_id = ''
matlab_pid = ''
dbid = ''

def logger(level, log):
    print(f'{datetime.now().isoformat()}:[{level}] {log}')

def load_params_file(params_path):
    with open(params_path, 'r') as f:
        params = {key:value for key, value in [l.split('=') for l in f.read().split('\n') if '=' in l]}
    return params

def check_pid(pid):        
    """ Check For the existence of a unix pid. """
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    else:
        return True

def main_logic(rdb, mrc_redis_id, worker_key, matlab_pid, params):
    worker_process_alive = check_pid(matlab_pid)
    try:
        if not mrc_redis_id == rdb.get('db_timetag'):
            # TODO: restart
            pass
        worker_redis_status = rdb.hget(worker_key, 'status')
        watcher_cmd = rdb.blpop(f'{worker_key}:watcher_cmds', int(params['wrapper_loop_wait_seconds']))
    except: # TODO: catch the right exception
        logger('WARNING', 'redis could not be reached')
        time.sleep(1)
    
    logger('VERBOSE', f'alive {worker_process_alive} status {worker_redis_status} command {watcher_cmd}')

    if not worker_process_alive and worker_redis_status == 'active':
        # revive
        pass

    if watcher_cmd == 'restart':
        pass    
    elif watcher_cmd == 'wakeup':
        pass    
    elif watcher_cmd == 'suspend':
        pass
    elif watcher_cmd == 'kill':
        pass

if __name__ == '__main__':
    params_path = sys.argv[1]
    worker_key = sys.argv[2]
    matlab_pid = int(sys.argv[3])

    logger('INFO', f'watcher of {worker_key} started on matlab {matlab_pid}')

    params = load_params_file(params_path)
    logger('INFO', f'params loaded from {params_path}')

    logger('INFO', f'connect to redis at {params["redis_hostname"]}:{params["redis_port"]} with password {params["redis_password"]}')
    rdb = redis.Redis(params["redis_hostname"], int(params["redis_port"]), password=params["redis_password"])
    mrc_redis_id = rdb.get('db_timetag')    
    logger('DEBUG', f'redis ping result: {rdb.ping()} with redis-id {mrc_redis_id}')

    logger('INFO', f'initialization done begin main loop')
    while True:
        main_logic(rdb, mrc_redis_id, worker_key, matlab_pid, params)