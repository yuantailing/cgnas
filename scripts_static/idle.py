import os
import subprocess
import time

if __name__ == '__main__':
    while True:
        start = time.time()
        cwd = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'scripts_dynamic')
        subprocess.call(['python3', 'update.py'], cwd=cwd)
        wait = 5 - (time.time() - start)
        if wait > 0:
            time.sleep(wait)
