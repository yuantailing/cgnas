# cgnas

## usage
```sh
cp .env.sample .env
cp scripts_dynamic/settings.py.sample scripts_dynamic/settings.py # please edit it
ssh-keygen -f ssh_host_keys/ssh_host_rsa_key -N '' -t rsa
ssh-keygen -f ssh_host_keys/ssh_host_ecdsa_key -N '' -t ecdsa
chmod 600 conf/openvpn_account scripts_dynamic/settings.py
# change ports in docker-compose.yml
docker-compose up --build -d
```
