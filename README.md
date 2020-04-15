# cgnas

## usage
```sh
cp conf/openvpn_account.sample conf/openvpn_account # please edit it
cp scripts_dynamic/settings.py.sample scripts_dynamic/settings.py # please edit it
ssh-keygen -f ssh_host_keys/ssh_host_rsa_key -N '' -t rsa
ssh-keygen -f ssh_host_keys/ssh_host_ecdsa_key -N '' -t ecdsa
chmod 600 conf/openvpn_account scripts_dynamic/settings.py
docker-compose up --build -d
```
