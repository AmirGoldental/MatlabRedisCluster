
import sys
from datetime import datetime, timedelta
import os
import signal
import redis
import time
import random
import subprocess
import socket

service_name = 'MRC\\MrcServer'
params_path = 'mrc.conf'
hostname = socket.gethostname().lower()
server_key = f'server:{hostname}'
params = dict()
workers = []
dbid = ''
rdb = None

class MrcWorker:
    key = ''
    pid = None

    def __init__(self, worker_key, pid=None) -> None:
        self.key = worker_key
        if pid is None:
            self.start()
        else:
            self.pid = pid

    def start(self):
        rdb.hset(self.key, 'status', 'starting')
        self.pid = start_matlab_worker(self.key)
        return self

    def isalive(self):
        return check_pid(self.pid)

    def kill(self):
        logger('INFO', f'kill worker {self.key} with pid {self.pid}')
        rdb.hset(self.key, 'status', 'dead')
        
        try:
            os.kill(self.pid, signal.SIGTERM)
        except:
            if self.isalive():
                logger('WARN', f'could not kill the wicked process {pid}', pid)     
            else:
                logger('WARN', 'process was already dead')
        return self

    def fail_current_task(self, err_msg='task failed'):
        current_task = bytes2str(rdb.hget(self.key, 'current_task'))
        if (current_task is None) or (current_task == "None") or (len(current_task) == 0):
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
    
def start_matlab_worker(worker_key, wait_interval=0.1, timeout=60):
    rdb.rpush(f'{worker_key}:log', f'{datetime.now().isoformat()} start new matlab worker')
    subprocess.Popen([params["matlab_path"], '-r', f'mrc.join_as_worker(\'{worker_key}\')'], shell=True)
    counter = 0
    while bytes2str(rdb.hget(worker_key, 'status')) != 'active':
        time.sleep(wait_interval)
        counter += wait_interval
        if counter > timeout:
            logger('WARN', 'could not start new matlab worker')
            return 2000000
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
    global workers
    cmd = cmd.split()
    if cmd[0] == 'shutdown':
        for worker in workers:
            worker.fail_current_task('server shutdown')
            worker.kill()
        rdb.hset(server_key, 'status', 'dead')
        exit(0x00)
    if cmd[0] == 'restart_server':
        rdb.hset(server_key, 'status', 'starting')
        python = sys.executable
        os.execl(python, python, *sys.argv)
    # if cmd[0] == 'install_service':
    #     os.system(f'schtasks /create /SC MINUTE /TN "{service_name}" /TR "{os.path.join(os.getcwd(), "start_server.bat")}"')
    #     rdb.hset(server_key, 'service_installed', 'true')
    # if cmd[0] == 'uninstall_service':
    #     os.system(f'schtasks /delete /TN "{service_name}" /f')
    #     rdb.hset(server_key, 'service_installed', 'false')
    if cmd[0] == 'restart':
        for worker in workers:
            if len(cmd) == 1 or worker.key in cmd[1:]:
                worker.fail_current_task('worker restart')
                worker.kill().start()
    if cmd[0] == 'kill':
        alive_workers = []
        for worker in workers:
            if len(cmd) == 1 or worker.key in cmd[1:]:
                worker.fail_current_task('worker killed')
                worker.kill()
            else:
                alive_workers.append(worker)
        workers = alive_workers
        rdb.hset(f'{server_key}', 'number_of_workers', len(workers))
    if cmd[0] == 'new':
        n = 1 if len(cmd) == 1 else int(cmd[1])
        counter_key = f'worker:{hostname}:count'
        for i in range(n):
            workers.append(MrcWorker(f'worker:{hostname}:{rdb.incr(counter_key)}'))
        rdb.hset(f'{server_key}', 'number_of_workers', len(workers))

def server_join():    
    rdb.hset(server_key, 'status', 'active')
    rdb.hset(server_key, 'key', server_key)
    rdb.hset(server_key, 'pid', os.getpid())
    rdb.sadd('servers', server_key)
    workers_keys = rdb.smembers(f'{server_key}:workers')
    for worker_key in workers_keys:
        worker_key = bytes2str(worker_key)
        status = bytes2str(rdb.hget(worker_key, 'status'))
        if status == 'dead':
            continue
        worker = MrcWorker(worker_key, int(rdb.hget(worker_key, 'pid')))
        if status == 'active':
            workers.append(worker)
        else:
            worker.kill()
    rdb.hset(f'{server_key}', 'number_of_workers', len(workers))    
    service_installed = os.system(f'schtasks /query /TN "{service_name}"')
    rdb.hset(server_key, 'service_installed', 'true' if service_installed == 0 else 'false')


def is_another_server_alive(wait_interval=1, timeout=60):
    if bytes2str(rdb.hget(server_key, 'status')) != 'active':
        return False

    redis_entry_pid = bytes2str(rdb.hget(server_key, 'pid'))
    if redis_entry_pid is None or int(redis_entry_pid) == os.getpid():
        return False

    current_datetime = datetime.now()
    redis_entry_datetime = bytes2str(rdb.hget(server_key, 'last_ping'))
    if redis_entry_datetime is None or current_datetime - datetime.fromisoformat(redis_entry_datetime) > timedelta(seconds=timeout):
        return False
        
    logger('WARN', f'another server is suspected on the same host wait for resolve (max wait {timeout} seconds)')
    while datetime.now() > datetime.fromisoformat(redis_entry_datetime):
        time.sleep(wait_interval)
        redis_entry_datetime = bytes2str(rdb.hget(server_key, 'last_ping'))
        if datetime.now() - datetime.fromisoformat(redis_entry_datetime) > timedelta(seconds=timeout):
            return False
    return True

def get_db_timetag():
    db_timetag = datetime.now().strftime('%Y_%m_%d__%H_%M_%S')
    rdb.setnx('db_timetag', db_timetag)
    return rdb.get('db_timetag')

if __name__ == '__main__':
    logger('INFO', f'begin {server_key}')

    params_path = sys.argv[1]
    params = load_params_file(params_path)
    logger('INFO', f'params loaded from {params_path}')

    logger('INFO', f'connect to redis at {params["redis_hostname"]}:{params["redis_port"]} with password {params["redis_password"]}')
    rdb = redis.Redis(params["redis_hostname"], int(params["redis_port"]), password=params["redis_password"])

    mrc_redis_id = get_db_timetag()  
    logger('DEBUG', f'redis ping result: {rdb.ping()} with redis-id {mrc_redis_id}')

    if is_another_server_alive():
        logger('WARN', f'another server is alive on this host exit')
        exit(0x00)

    server_join()
    logger('INFO', f'initialization done begin event loop')
    while True:        
        try:
            if not mrc_redis_id == get_db_timetag():
                mrc_redis_id = get_db_timetag()
                for worker in workers:
                    worker.kill()
                server_join()
            else:
                cmd = bytes2str(rdb.blpop(f'{server_key}:cmd', int(params['event_loop_wait_seconds'])))
                if cmd is not None and (not isinstance(cmd, str)) and len(cmd) > 1:
                    cmd = bytes2str(cmd[-1])
                    logger('INFO', f'received command {cmd}')
                    perform_command(cmd)
        except redis.exceptions.ConnectionError:
            logger('WARNING', 'redis could not be reached')
            time.sleep(1)
            continue
            
        rdb.hset(f'{server_key}', 'last_ping', datetime.now().isoformat())
        
        for worker in workers:
            if worker.isalive():
                continue
            logger('VERBOSE', f'worker {worker.key} crashed')
            rdb.hset(worker.key, 'status', 'restart')
            worker.fail_current_task("worker died")
            worker.start()

        logger('INFO', f'current alive workers {len(workers)}')
