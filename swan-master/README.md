# README

## SwanWorker

SwanWorker is a python process conducting background tasks for the swan rails app.
This includes preparing salt minion keys, writing configuration files and starting
and stopping the salt-minion process. The worker process is supposed to run directly
on the host operating system and not within a dedicated container. It is controlled
by a systemd service. See swan/extern/salted\_swan.service for details.
For communication purposes both rails application and background python script share
a blocking redis queue named "swan.events" by default, so a redis service must be 
available. 

### SwanWorker environment variables

SwanWorker supports a number of environment variables for configuration. You may
tweak those in the systemd service file individually or create a dedicated 
environment file for reading by systemd. This is the list of supported environment
variables:

* REDIS\_HOST, redis server host (default: 127.0.0.1)
* REDIS\_PORT, redis TCP port (default: 6379)
* REDIS\_CHAN, name of the blocking queue used in redis (default: swan.events)
* LOGLEVEL, one of these strings: critical, error, warning, info, debug (default: debug)
* TIMEOUT, for the redis reading loop, measured in seconds (default: 4)
* RAILS\_SWAN\_KEY\_PATH, copied salt minion key filepath on host and mapped into rails container (default: /var/lib/swan/minion.pub)
* SALT\_MINION\_KEY\_PATH, original salt minion key filepath used by salt-minion (default: /etc/salt/pki/minion/minion.pub)
* SALT\_MINION\_KEY\_LENGTH, salt minion key length used for salt minion key generation (default: 2048)
* SALT\_MINION\_CONF\_PATH, salt minion configuration filepath used by salt-minion (default: /etc/salt/minion.d/swan.conf)

## Rails application

### Rails application environment variables

The rails application supports the following additional environment variables:

* REDIS\_HOST, redis server host (default: 127.0.0.1)
* REDIS\_PORT, redis TCP port (default: 6379)
* REDIS\_CHAN, name of the blocking queue used in redis (default: swan.events)
* RAILS\_SWAN\_KEY\_PATH, copied salt minion key filepath mapped into rails container (default: /var/lib/swan/minion.pub)

* Deployment instructions

* ...

# Installation with ansible

To install a freshly booted  box with ubuntu on it please use ansible.
To install ansible, you have to have python3 and python3-venv installed.

After having these two available, create a virtual environment named `venv` with:
```
python3 -m venv venv
```

To load that environment run:
```
source venv/bin/activate
```

Now you can install the required python dependencies (including ansible) with:
```
pip install -r requirements.txt
```

To execute the playbook against your specific environment, you have to modify
and adapt the `inventory.yml` file to reflect your specific settings (you will
need to modify at least the hostname of your target)

After you adapted the inventory, you can run the playbook with (please make sure
that you accepted the host key fingerprint of all target hosts before starting):
```
ansible-playbook -i inventory.yml deploy_swan.playbook.yml
```

If you want to deploy only some hosts and not all that are mentioned in the
inventory.yaml, you can limit the playbook targets by using the `-l` option:
```
ansible-playbook -i inventory.yml deploy_swan.playbook.yml -l "ribbon6000-1.labor2.bisdn.de"
```
