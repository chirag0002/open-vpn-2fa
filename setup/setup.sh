#!/usr/bin/env bash

wget https://go.dev/dl/go1.24.0.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/usr/local/go/bin/go

rm go1.24.0.linux-amd64.tar.gz

go install github.com/gobuffalo/packr/v2/packr2@v2.8.3
export PATH=$(go env GOPATH)/bin:$PATH

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

\. "$HOME/.nvm/nvm.sh"
nvm install 14

cd /home/ubuntu/open-vpn-2fa/
chmod +x build.sh
chmod +x setup/configure.sh