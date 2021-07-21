
import sys
from datetime import datetime
import os
import signal
import redis
import time
import random
import subprocess
import socket

params_path = 'worker.conf'
hostname = socket.gethostname()
server_key = f'server:{hostname}'
params = dict()
workers = []
dbid = ''

class Worker:
    key = ''
    pid = None
    status = None    

    def __init__(self) -> None:
        pass

    def isalive(self):
        return check_pid(self.pid)

    def kill(self):
        pass

    def update(self):
        pass

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
        p = rdb.pipeline()
        p.hset(current_task, 'failed_on', datetime.now().isoformat())
        p.hset(current_task, 'status', 'failed')
        p.hset(current_task, 'err_msg', err_msg)
        p.lrem('ongoing_tasks', 0, current_task)
        p.lpush('failed_tasks', current_task)
        p.hset(worker_key, 'current_task', "None")
        p.execute()

def reset_worker(rdb, worker_key, params):
    worker_id = worker_key.replace('worker:', '')
    rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} start new matlab worker')
    os.system(f'start "{random.randint(1,20000)}_matlab_worker" "{params["matlab_path"]}" -sd "{os.getcwd()}" -r "mrc.join_as_worker(\'{worker_id}\')')
    exit(0x00)   
    
def start_matlab_worker(rdb, worker_key, params):
    worker_id = worker_key.replace('worker:', '')
    rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} start new matlab worker')
    matlab_process = subprocess.Popen([params["matlab_path"], '-r', f'mrc.join_as_worker(\'{worker_id}\', \'false\')'], shell=True)
    while rdb.hget(worker_key, 'status') != 'active' and rdb.hget(worker_key, 'pid') is None:
        time.sleep(0.1)
    return int(rdb.hget(worker_key, 'pid'))

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
        reset_worker(rdb, worker_key, params)
    elif watcher_cmd == 'wakeup':
        if worker_process_alive:
            logger('WARNING', 'received wakeup but worker was already active')
        else:
            reset_worker(rdb, worker_key, params)
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

def perform_command(cmd):
    pass

if __name__ == '__main__':
    logger('INFO', f'begin {server_key}')

    params_path = sys.argv[1]
    params = load_params_file(params_path)
    logger('INFO', f'params loaded from {params_path}')

    logger('INFO', f'connect to redis at {params["redis_hostname"]}:{params["redis_port"]} with password {params["redis_password"]}')
    rdb = redis.Redis(params["redis_hostname"], int(params["redis_port"]), password=params["redis_password"])
    mrc_redis_id = rdb.get('db_timetag')    
    logger('DEBUG', f'redis ping result: {rdb.ping()} with redis-id {mrc_redis_id}')

    logger('INFO', f'initialization done begin event loop')
    while True:        
        try:
            if not mrc_redis_id == rdb.get('db_timetag'):
                pass
                # restart all workers?
            else:
                cmd = bytes2str(rdb.blpop(f'{server_key}:cmds', int(params['event_loop_wait_seconds'])))
                if cmd is not None and (not isinstance(cmd, str)) and len(cmd) > 1:
                    cmd = bytes2str(cmd[-1])
                    perform_command(cmd)
        except redis.exceptions.ConnectionError:
            logger('WARNING', 'redis could not be reached')
            time.sleep(1)
            continue
            
        for worker in workers:
            worker.update()
        