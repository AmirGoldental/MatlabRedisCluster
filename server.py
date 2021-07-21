
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
rdb = None

class Worker:
    key = ''
    pid = None

    def __init__(self, worker_key) -> None:
        self.key = worker_key
        self.start()

    def start(self):
        self.pid = start_matlab_worker(self.key, params)
        return self

    def isalive(self):
        return check_pid(self.pid)

    def kill(self):
        logger('INFO', f'kill worker {self.key}')
        os.kill(self.pid, signal.SIGTERM)
        return self

    def fail_current_task(self, err_msg='task failed'):
        current_task = bytes2str(rdb.hget(self.key, 'current_task'))
        if (current_task is None) or current_task == "None" or len(current_task) > 0:
            return

        logger('INFO', f'fail task {current_task} of worker {self.key}')
        p = rdb.pipeline()
        p.hset(current_task, 'failed_on', datetime.now().isoformat())
        p.hset(current_task, 'status', 'failed')
        p.hset(current_task, 'err_msg', err_msg)
        p.lrem('ongoing_tasks', 0, current_task)
        p.lpush('failed_tasks', current_task)
        p.hset(self.key, 'current_task', "None")
        p.execute()


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
    
def start_matlab_worker(rdb, worker_key, params):
    worker_id = worker_key.replace('worker:', '')
    rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} start new matlab worker')
    matlab_process = subprocess.Popen([params["matlab_path"], '-r', f'mrc.join_as_worker(\'{worker_id}\', \'false\')'], shell=True)
    while rdb.hget(worker_key, 'status') != 'active' and rdb.hget(worker_key, 'pid') is None:
        time.sleep(0.1)
    return int(rdb.hget(worker_key, 'pid'))

def perform_command(cmd):
    # restart worker
    # kill worker
    # add [n] workers
    # kill [n] workers
    # kill all workers
    # restart all workers
    # add as schdtask
    # add as service
    # shutdown
    cmd = cmd.split()
    if cmd[0] == 'shutdown':
        for worker in workers:
            worker.fail_current_task('server shutdown')
            worker.kill()
        rdb.hset(server_key, 'status', 'dead')
        exit(0x00)
    if cmd[0] == 'restart':
        for worker in workers:
            if len(cmd) == 1 or worker.key in cmd[1:]:
                worker.fail_current_task('worker restart')
                worker.kill().start()
    if cmd[0] == 'kill':
        for worker in workers:
            if len(cmd) == 1 or worker.key in cmd[1:]:
                worker.fail_current_task('worker restart')
                worker.kill()
    if cmd[0] == 'new':
        n = 1 if len(cmd) == 1 else int(cmd[1])
        counter_key = f'worker:{hostname}:count'
        for i in range(n):
            workers.append(Worker(f'worker:{hostname}:{rdb.incr(counter_key)}'))
    

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
                for worker in workers:
                    worker.kill()
            else:
                cmd = bytes2str(rdb.blpop(f'{server_key}:cmds', int(params['event_loop_wait_seconds'])))
                if cmd is not None and (not isinstance(cmd, str)) and len(cmd) > 1:
                    cmd = bytes2str(cmd[-1])
                    perform_command(cmd)
        except redis.exceptions.ConnectionError:
            logger('WARNING', 'redis could not be reached')
            time.sleep(1)
            continue
            
        alive_workers = []
        for worker in workers:
            if worker.isalive():
                alive_workers.append(worker)
                continue
            logger('INFO', f'worker {worker.key} crashed')
            rdb.hset(worker.key, 'status', 'dead')
            worker.fail_current_task("worker died")

        workers = alive_workers
        logger('INFO', f'current alive workers {len(workers)}')
