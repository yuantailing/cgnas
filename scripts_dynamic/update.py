import fcntl
import logging
import operator
import os
import requests
import settings
import subprocess
import urllib.parse


def check_name(name):
    if not (2 <= len(name) <= 40):
        return False
    for c in name.lower():
        if c not in '0123456789abcdefghijklmnopqrstuvwxyz-_':
            return False
    return True

def passwd_name(line):
    return line.split(':')[0]

def passwd_uid(line):
    return int(line.split(':')[2])

def group_name(line):
    return line.split(':')[0]

def group_gid(line):
    return int(line.split(':')[2])

def shadow_name(line):
    return line.split(':')[0]


if __name__ == '__main__':
    # set logging and lock
    var_dir = '/var/lib/cgnas'
    if not os.path.isdir(var_dir):
        os.makedirs(var_dir)
    stat = os.stat(var_dir)
    if stat.st_mode & 0o7777 != 0o700:
        os.chmod(var_dir, 0o700)
    lock_f = open(os.path.join(var_dir, 'lock'), 'w')
    fcntl.flock(lock_f, fcntl.LOCK_EX)
    log_filename = os.path.join(var_dir, 'recent')
    handlers = [logging.FileHandler(log_filename, mode='w'), logging.StreamHandler()]
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s',
        handlers=handlers,
    )

    try:
        # communicate with API
        latest_password_update_filename = os.path.join(var_dir, 'latest_password_update')
        latest_password_update = 0
        if os.path.isfile(latest_password_update_filename):
            with open(latest_password_update_filename) as f:
                try:
                    latest_password_update = float(f.read())
                except ValueError:
                    pass
        try:
            r = requests.post(settings.CGNAS_API_URL, data={
                'api_secret': settings.CGNAS_API_SECRET,
                'latest_password_update': latest_password_update,
            })
        except requests.exceptions.ConnectionError:
            logging.error('cgserver connection error')
            raise
        if 200 != r.status_code:
            logging.error('cgserver API failed')
        assert 200 == r.status_code
        data = r.json()
        public_ip = data['from_ip']
        users = data['users']
        users.sort(key=operator.itemgetter('staff_number'))

        # save latest password update
        latest_password_update = 0 if 0 == len(users) else max([user['password_updated_at'] for user in users])
        with open(latest_password_update_filename, 'w') as f:
            f.write('{:f}'.format(latest_password_update))

        # get system users
        protected_users = set()
        forbidden_names = set()
        with open('/etc/passwd') as f:
            passwd = f.readlines()
        with open('/etc/group') as f:
            group = f.readlines()
        with open('/etc/shadow') as f:
            shadow = f.readlines()
        passwd = [line for line in passwd if not (10000 <= passwd_uid(line) < 20000)]
        group = [line for line in group if not (10000 <= group_gid(line) < 20000)]
        for line in passwd:
            protected_users.add(passwd_name(line))
            forbidden_names.add(passwd_name(line))
        for line in group:
            forbidden_names.add(group_name(line))
        shadow = [line for line in shadow if shadow_name(line) in protected_users]
        smbpasswd = []
        user_gid = group_gid([g for g in group if group_name(g) == 'user'][0])

        # check valid usersnames
        # note that staff_number and username MUST NOT duplicate
        valid_users = []
        username_taken = set()
        for user in users:
            if not user['shadow_password'] or not user['nt_password_hash']:
                continue
            if not (1 <= user['staff_number'] < 10000):
                logging.info('staff number {:d} is invalid'.format(user['staff_number']))
                continue
            if not check_name(user['username']):
                logging.info('username "{:s}" is invalid'.format(user['username']))
                continue
            if user['username'] in forbidden_names:
                logging.info('username "{:s}" is prohibited'.format(user['username']))
                continue
            username_taken.add(user['username'])
            valid_users.append(user)
        users = valid_users

        # set home and prepare passwd (and group, shadow, smbpasswd)
        for user in users:
            uid = 10000 + user['staff_number']
            gid = user_gid
            mnt_path = os.path.join('/nas/{:d}'.format(uid))
            home_path = os.path.join('/home/{:s}'.format(user['username']))

            # prepare passwd
            passwd.append('{:s}:x:{:d}:{:d}::{:s}:/bin/bash\n'.format(user['username'], uid, gid, mnt_path))
            shadow.append('{:s}:{:s}:{:d}:0:90:7:::\n'.format(user['username'], user['shadow_password'], int(user['password_updated_at'] / 86400)))
            smbpasswd.append('{:s}:{:d}:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:{:s}:[U          ]:LCT-{:s}:'.format(
                user['username'], uid, user['nt_password_hash'], hex(int(user['password_updated_at']))[2:].upper()))

            # set home
            if not os.path.isdir(mnt_path):
                os.makedirs(mnt_path)
            stat = os.stat(mnt_path)
            if stat.st_uid != uid or stat.st_gid != gid:
                os.chown(mnt_path, uid, gid)
            relpath = os.path.relpath(mnt_path, os.path.dirname(home_path))
            if os.path.islink(home_path):
                if not os.readlink(home_path) == relpath:
                    os.unlink(home_path)
            if not os.path.islink(home_path):
                os.symlink(relpath, home_path)

        # clear other users
        for name in os.listdir('/home'):
            path = os.path.join('/home', name)
            if os.path.islink(path):
                if name not in username_taken:
                    os.unlink(path)

        # disable /usr/bin/passwd and /usr/bin/smbpasswd
        path = '/usr/bin/passwd'
        stat = os.stat(path)
        if stat.st_mode & 0o7777 != 0o4750:
            os.chmod(path, 0o4750)
        path = '/usr/bin/smbpasswd'
        stat = os.stat(path)
        if stat.st_mode & 0o7777 != 0o4750:
            os.chmod(path, 0o4750)

        # write passwd
        with open(os.open('/etc/passwd.tmp', os.O_CREAT | os.O_WRONLY, 0o644), 'w') as f:
            f.write(''.join(passwd))
        with open(os.open('/etc/shadow.tmp', os.O_CREAT | os.O_WRONLY, 0o600), 'w') as f:
            f.write(''.join(shadow))
        with open(os.open('/etc/samba/smbpasswd.tmp', os.O_CREAT | os.O_WRONLY, 0o600), 'w') as f:
            f.write(''.join(smbpasswd))
        os.rename('/etc/passwd.tmp', '/etc/passwd')
        os.rename('/etc/shadow.tmp', '/etc/shadow')
        os.rename('/etc/samba/smbpasswd.tmp', '/etc/samba/smbpasswd')

        # write /etc/vsftpd.conf
        with open('/etc/vsftpd.conf') as f:
            lines = f.readlines()
        old_ip_line = [line for line in lines if line.startswith('pasv_address=')]
        if not old_ip_line:
            old_ip = ''
        else:
            old_ip = old_ip_line[-1].strip().split('=')[1]
        if len(old_ip_line) > 1 or old_ip != public_ip:
            lines = [line for line in lines if not line.startswith('pasv_address=')]
            lines.append('pasv_address={:s}\n'.format(public_ip))
            with open('/etc/vsftpd.conf', 'w') as f:
                f.write(''.join(lines))
            subprocess.call(['service', 'vsftpd', 'reload'])

        logging.info('Everything up-to-date.')
    except:
        logging.error('error occurred, please contact administrator.')
        raise
    finally:
        # write status to apache
        html_dir = '/var/www/html'
        path = os.path.join(html_dir, '.index.html.tmp')
        url = urllib.parse.urljoin(settings.CGNAS_API_URL, '/serverlist/nas')
        with open(path, 'w') as f:
            f.write('<!DOCTYPE html>')
            f.write('<html><head><meta charset="UTF-8"></head><body>')
            f.write('<h1>NAS Status</h1>')
            f.write('<pre>')
            with open(log_filename) as log_f:
                f.write(log_f.read())
            f.write('</pre><hr>')
            f.write('<p>Please go to <a href="{:s}">{:s}</a> to setup your account.</p>'.format(url, url))
            f.write('<p>&copy; <script>document.write((new Date()).getFullYear());</script> CSCG Group</p>')
            f.write('</body></html>')
        os.rename(path, os.path.join(html_dir, 'index.html'))

        fcntl.flock(lock_f, fcntl.LOCK_UN)
