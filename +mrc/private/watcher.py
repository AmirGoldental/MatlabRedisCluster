
import sys
from datetime import datetime
import os
import signal
import redis
import time
import random

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
    return os.popen(f'tasklist /nh /fi "pid eq {pid}"').read().strip().split()[1] == f'{pid}'

def bytes2str(b):
    return b.decode() if isinstance(b, bytes) else b

def handle_task_fail(rdb, worker_key, err_msg):
    current_task = bytes2str(rdb.hget(worker_key, 'current_task'))
    if (current_task is not None) and current_task != "None" and len(current_task) > 0:
        rdb.multi()
        rdb.hset(current_task, 'failed_on', datetime.now().isoformat())
        rdb.hset(current_task, 'status', 'failed')
        rdb.hset(current_task, 'err_msg', err_msg)
        rdb.lrem('ongoing_tasks', 0, current_task)
        rdb.lpush('failed_tasks', current_task)
        rdb.hset(worker_key, 'current_task', "None")
        rdb.exec()

def start_new_worker(rdb, worker_key, params):
    worker_id = worker_key.replace('worker:', '')
    rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} start new matlab worker')
    os.system(f'start "{random.randint(1,20000)}_matlab_worker" "{params["matlab_path"]}" -sd "{os.getcwd()}" -r "mrc.join_as_worker(\'{worker_id}\')')
    exit(0x00)   

def kill_and_handle_fail(rdb, worker_key, matlab_pid, err_msg):    
    logger('INFO', 'kill matlab worker')
    os.kill(matlab_pid, signal.SIGTERM)
    handle_task_fail(rdb, worker_key, err_msg)

def main_logic(rdb, mrc_redis_id, worker_key, matlab_pid, params):
    worker_process_alive = check_pid(matlab_pid)
    try:
        if not mrc_redis_id == rdb.get('db_timetag'):
            worker_redis_status = ''
            watcher_cmd = 'restart'
        else:
            worker_redis_status = bytes2str(rdb.hget(worker_key, 'status'))
            watcher_cmd = bytes2str(rdb.blpop(f'{worker_key}:watcher_cmds', int(params['wrapper_loop_wait_seconds'])))
            if watcher_cmd is not None and (not isinstance(watcher_cmd, str)) and len(watcher_cmd) > 1:
                watcher_cmd = bytes2str(watcher_cmd[-1])
    except redis.exceptions.ConnectionError:
        logger('WARNING', 'redis could not be reached')
        time.sleep(1)
    
    logger('VERBOSE', f'alive {worker_process_alive} status {worker_redis_status} command {watcher_cmd}')

    # revive
    if not worker_process_alive and worker_redis_status == 'active':
        logger('INFO', 'matlab crashed')
        rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} matlab crashed')
        rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} change status to dead')
        rdb.hset(worker_key, 'status', 'dead')
        handle_task_fail(rdb, worker_key, "worker died")
        if params['matlab_restart_on_fail'] == "true":
            watcher_cmd = "restart"
            rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} change watcher_cmd to restart')

    if watcher_cmd == 'restart':    
        if worker_process_alive:
            kill_and_handle_fail(rdb, worker_id, matlab_pid, "worker killed")
        rdb.hset(worker_key, 'status', 'dead')
        start_new_worker(rdb, worker_key, params)
    elif watcher_cmd == 'wakeup':
        if worker_process_alive:
            logger('WARNING', 'received wakeup but worker was already active')
        else:
            start_new_worker(rdb, worker_key, params)
    elif watcher_cmd == 'suspend':
        if worker_process_alive:
            rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} suspends matlab worker')
            kill_and_handle_fail(rdb, worker_id, matlab_pid, "worker suspended")
        rdb.hset(worker_key, 'status', 'suspended')
    elif watcher_cmd == 'kill':
        if worker_process_alive:
            rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} kill matlab worker')
            kill_and_handle_fail(rdb, worker_id, matlab_pid, "worker killed")
        rdb.hset(worker_key, 'status', 'dead')
        rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} watcher shutdown')
        exit(0x00)

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