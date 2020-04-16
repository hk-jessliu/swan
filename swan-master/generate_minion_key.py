#!/usr/bin/env python
import salt.crypt
salt.crypt.gen_keys('/etc/salt/pki/minion', 'minion', 2048)
