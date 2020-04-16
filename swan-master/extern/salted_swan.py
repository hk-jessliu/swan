#!/usr/bin/env python3

import os
import sys
import pwd
import grp
import json
import stat
import time
import yaml
import redis
import shutil
import logging
import threading
import traceback
import subprocess

import salt.crypt


loglevel = logging.DEBUG

ch = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)

if __name__ == "__main__":
  log = logging.getLogger('swan.worker')
else:
  log = logging.getLogger(__name__)
log.addHandler(ch)
log.setLevel(loglevel)




class SwanWorker(threading.Thread):
    ''' swan worker '''
    _defaults = {
        'host'     : os.environ.get('REDIS_HOST', '127.0.0.1'),
        'port'     : os.environ.get('REDIS_PORT', 6379),
        'chan'     : os.environ.get('REDIS_CHAN', 'swan.events'),
        'loglevel' : os.environ.get('LOGLEVEL', 'debug'),
        'timeout'  : os.environ.get('TIMEOUT', 4),
        'rails_swan_key_path'    : os.environ.get('RAILS_SWAN_KEY_PATH', '/var/lib/swan/minion.pub'),
        'salt_minion_key_path'   : os.environ.get('SALT_MINION_KEY_PATH', '/etc/salt/pki/minion/minion.pub'),
        'salt_minion_conf_path'  : os.environ.get('SALT_MINION_CONF_PATH', '/etc/salt/minion.d/swan.conf'),
        'salt_minion_key_length' : os.environ.get('SALT_MINION_KEY_LENGTH', 2048),
        }

    _loglevels = {
        'critical' : logging.CRITICAL,
        'error'    : logging.ERROR,
        'warning'  : logging.WARNING,
        'info'     : logging.INFO,
        'debug'    : logging.DEBUG,
    }

    _events = {
        'swan.rails.salt.minion.key.get'       : 'get_key',
        'swan.rails.salt.minion.config.create' : 'set_conf',
        'swan.rails.salt.minion.config.delete' : 'del_conf',
        }

    def __init__(self, **kwargs):
        ''' initializer #1 '''
        threading.Thread.__init__(self)
        self._stop_thread = threading.Event()
        self._lock_thread = threading.RLock()
        self.initialize(**kwargs)

    def initialize(self, **kwargs):
        ''' initializer #2 '''
        for key, value in self._defaults.items():
            setattr(self, key, kwargs.get(key, value))
        # set loglevel, set to DEBUG, if self.loglevel is invalid
        log.setLevel(self._loglevels.get(self.loglevel, logging.DEBUG))

    def __str__(self):
        ''' string representation '''
        return '{}({})'.format(
                        self.__class__.__name__,
                        ', '.join(['{}={}'.format(k,getattr(self, k, v)) for k,v in self._defaults.items()])
                        )
        
    def stop(self):
        ''' stop thread loop '''
        log.debug('{}.run() thread received termination notification'.format(self.__class__.__name__))
        self._stop_thread.set()
        self.join()

    def run(self):
        ''' thread main loop '''
        try:
            log.info('{}.run() thread started'.format(self.__class__.__name__))

            r = redis.Redis( connection_pool=redis.BlockingConnectionPool(host=self.host, port=self.port) )

            while not self._stop_thread.is_set():
                try:
                    msg = r.brpop(self.chan, timeout=self.timeout)
                    self.handle_msg(msg)

                except Exception as e:
                    log.error('exception caught: {}'.format(e))

        except Exception as e:
            log.error('thread terminating exception caught: {}'.format(e))

        finally:
            log.info('{}.run() thread terminated'.format(self.__class__.__name__))

    def handle_msg(self, msg):
        ''' handle msg '''
        if msg is None:
            return
        try:
            name, payload = (str(msg[0]), json.loads(msg[1]))
            log.debug('on {}: {}'.format(name, payload))

            if 'event' not in payload:
                log.warning('no event found in redis message, ignoring => {}'.format(msg))
                return
            event = payload['event']

            if event not in self._events.keys():
                log.warning('event {} not registered locally, ignoring => {}'.format(event, msg))
                return

            if not hasattr(self, self._events[event]):
                log.warning('event {} has no associated method, ignoring => {}'.format(event, msg))
                return

            getattr(self, self._events[event])(payload)

        except Exception as e:
            log.error('exception caught: {}'.format(e))

    def execute(self, command, dump=False, throw=True, returncodes=[]):
        ''' execute system command '''
        try:
            if command is None:
                return
            args = command.split(' ')
            if len(args) == 0:
                return
            log.debug('execute: %s' % "".join(['{} '.format(arg) for arg in args]))
            if dump is False:
                with open(os.devnull, "w") as f:
                    return subprocess.call(args, stdout=f, stderr=None)
            else:
                return subprocess.check_output(args)
    
        except subprocess.CalledProcessError as e:
            if e.returncode in returncodes:
                return
            log.error('execute() caught exception: {} with backtrack {}'.format(e, traceback.print_exc()))
            if throw:
                raise
    
        except Exception as e:
            log.error('execute() caught exception: {} with backtrack {}'.format(e, traceback.print_exc()))

    def get_key(self, payload):
        ''' get salt minion key '''
        log.debug('get_key')

        # parent directory
        salt_minion_key_dir, salt_minion_key_file = os.path.split(self.salt_minion_key_path)

        # check existence of parent directory: create if non-existing
        if not os.path.isdir(salt_minion_key_dir):
            log.debug('creating directory {}'.format(salt_minion_key_dir))
            os.makedirs(salt_minion_key_dir)

        # check existence of key file: create if non-existing
        if not os.path.isfile(self.salt_minion_key_path):
            log.debug('creating salt minion key {}'.format(self.salt_minion_key_path))
            tmp = salt_minion_key_file.rstrip('.pub')
            salt.crypt.gen_keys(salt_minion_key_dir, tmp, int(self.salt_minion_key_length))

        # parent directory
        rails_swan_key_dir, rails_swan_key_file = os.path.split(self.rails_swan_key_path)

        # check existence of parent directory: create if non-existing
        if not os.path.isdir(rails_swan_key_dir):
            log.debug('creating directory {}'.format(rails_swan_key_dir))
            os.makedirs(rails_swan_key_dir)

        # check existence of rails volume path
        #if not os.path.isfile(self.rails_swan_key_path):
        log.debug('copying salt minion key from {} to {}'.format(self.salt_minion_key_path, self.rails_swan_key_path))
        shutil.copyfile(self.salt_minion_key_path, self.rails_swan_key_path)

        # set mode on rails volume path
        os.chmod(self.rails_swan_key_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
    
    def set_conf(self, payload):
        ''' set salt minion configuration '''
        log.debug('set_conf')

        # parent directory
        salt_minion_conf_dir, salt_minion_conf_file = os.path.split(self.salt_minion_conf_path)

        # check existence of parent directory: create if non-existing
        if not os.path.isdir(salt_minion_conf_dir):
            os.makedirs(salt_minion_conf_dir)

        # extract salt minion configuration from redis message payload
        if 'data' not in payload:
            log.warning('no data found in redis message payload, ignoring => {}'.format(payload))
            return
        data = payload['data']

        # write salt minion configuration to file
        with open(self.salt_minion_conf_path, "w") as f:
            f.write(yaml.dump(data, default_flow_style=False))

        # re-start salt-minion
        self.execute('systemctl enable --now salt-minion')
        self.execute('systemctl restart salt-minion')
    
    def del_conf(self, payload):
        ''' delete salt minion configuration '''
        log.debug('del_conf')

        # check existence of salt minion configuration
        if not os.path.isfile(self.salt_minion_conf_path):
            log.warning('no salt minion configuration found for removal at path {}'.format(self.salt_minion_conf_path))
            return

        # remove salt minion configuration
        os.remove(self.salt_minion_conf_path)

        # stop salt-minion
        self.execute('systemctl stop salt-minion')
        self.execute('systemctl disable --now salt-minion')
    

def main():
    ''' main function '''
    worker = SwanWorker()
    try:
        worker.start()

        while True:
            time.sleep(60)

    except KeyboardInterrupt as e:
        log.info('terminating on ctrl-c')

    finally:
        worker.stop()
 

def test_get_key():
    ''' test function '''
    payload = dict()
    worker = SwanWorker()
    print(worker)
    worker.get_key(payload)


def test_set_conf():
    ''' test function '''
    payload = {
        'data': {
            'id': 'test_id',
            'master' : 'test_master',
            'grains' : {
                'roles' : [
                    'kernel',
                    'systemd',
                    'frr',
                    'strongswan',
                    'redis',
                    ],
                },
            },
        }
    worker = SwanWorker()
    print(worker)
    worker.set_conf(payload)


def test_del_conf():
    ''' test function '''
    payload = dict()
    worker = SwanWorker()
    print(worker)
    worker.del_conf(payload)



if __name__ == "__main__":

    if   len(sys.argv) > 1 and sys.argv[1] == 'set_conf':
        test_set_conf()
    elif len(sys.argv) > 1 and sys.argv[1] == 'del_conf':
        test_del_conf()
    elif len(sys.argv) > 1 and sys.argv[1] == 'get_key':
        test_get_key()
    else:
        main()
