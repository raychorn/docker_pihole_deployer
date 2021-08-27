#!/bin/bash

VENV=/workspaces/.venv
REQS=/workspaces/requirements.txt

PYTHON39=$(which python3.9)
PIP3=$(which pip3)

echo "python39=$PYTHON39"
echo "PIP3=$PIP3"

apt-get update -y
apt-get upgrade -y
apt-get install net-tools -y
apt install iputils-ping -y

apt install curl wget unzip gpg -y

export DEBIAN_FRONTEND=noninteractive
export TZ=America/Denver

apt-get install -y tzdata wget

apt-get install jq -y

apt install awscli -y

. /etc/lsb-release

apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable"
apt update -y
apt install docker-ce -y
#usermod -aG docker ${USER}

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

sleeping () {
    while true; do
        echo "Sleeping... this is what this is supposed to do but this keesp the container running forever and it is doing wakeonlan's."
        sleep 9999s
    done
}

DOCKER_COMPOSE_TEST=$(docker-compose --version | grep "docker-compose version")
echo "Docker Compose Test #1: $DOCKER_COMPOSE_TEST"

if [ -z $DOCKER_COMPOSE_TEST ]; then
    echo "Docker Compose not installed? Trying to resolve."
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

DOCKER_COMPOSE_TEST2=$(docker-compose --version | grep "docker-compose version")
echo "Docker Compose Test #2: $DOCKER_COMPOSE_TEST2"

if [ -z $DOCKER_COMPOSE_TEST2 ]; then
    echo "Docker Compose not installed. Cannot continue."
    sleeping
fi

if [ -z "$PYTHON39" ]; then
    echo "Python 3.9 is not installed. Installing now..."
    apt-get update -y
    apt install software-properties-common -y
    add-apt-repository ppa:deadsnakes/ppa -y
    apt-get install python3.9 -y
    PYTHON39=$(which python3.9)
fi

if [ -z "$PIP3" ]; then
    echo "Pip 3 is not installed. Installing now..."
    apt-get install python3-pip -y
    PIP3=$(which pip3)
fi

PYTHON39=$(which python3.9)
PIP3=$(which pip3)

echo "PYTHON39=$PYTHON39"
echo "PIP3=$PIP3"

PWD=$(pwd)
DIR0=$(dirname $0)

if [ "$DIR0." == ".." ]; then
    DIR0=$PWD
fi
echo "DIR0=$DIR0"
echo "PWD=$PWD"

AWS_CLI_TEST=$(aws --version | grep 'aws-cli/2.2.')
echo "AWS_CLI_TEST=$AWS_CLI_TEST"

if [ -z "$AWS_CLI_TEST" ]; then
    echo "Cannot find awscli so installing it manually."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$DIR0/awscliv2.zip"

    if [ -f "$DIR0/awscliv2.zip" ]; then
        echo "Unzipping awscli."
        unzip $DIR0/awscliv2.zip -d $DIR0 > /dev/null
        echo "Done unzipping awscli."
        if [ -f "$DIR0/aws/install" ]; then
            echo "awscli can be installed."
            $DIR0/aws/install
        else
            echo "awscli is not installed"
            sleeping
        fi
    fi
    AWS_CLI_TEST=$(aws --version | grep 'aws-cli/2.2.')

    if [ -z "$AWS_CLI_TEST" ]; then
        echo "ERROR: AWS CLI is not installed. Please install it and try again."
        sleeping
    fi
fi

#################################################
###  BEGIN: Simulated Build Environment  ########
#################################################

AWS_CLI_TEST=$(aws --version | grep 'aws-cli/2.2.')
echo "AWS_CLI_TEST=$AWS_CLI_TEST"

if [ -z "$AWS_CLI_TEST" ]; then
    echo "ERROR: AWS CLI is not installed. Please install it and try again."
    sleeping
fi

if [ -f "$DIR0/.env" ]; then
    echo "Importing environment variables."
    export $(cat $DIR0/.env | sed 's/#.*//g' | xargs)
    echo "Done importing environment variables."
else
    echo "ERROR: Environment variables not found. Please run the following command to generate them:"
    sleeping
fi

VIRTUALENV=$(which virtualenv)

if [ -z "$VIRTUALENV" ]; then
    echo "Virtualenv is not installed. Installing now..."
    $PIP3 install virtualenv
fi

VIRTUALENV=$(which virtualenv)
if [ -f "$VIRTUALENV" ]; then
    echo "$VIRTUALENV exists."
else
    echo "ERROR: $VIRTUALENV was not installed.  Cannot continue."
    sleeping
fi

VENV=$DIR0/.venv
$VIRTUALENV --python $PYTHON39 -v $VENV

if [ -f "$VENV/bin/activate" ]; then
    echo "$VENV/bin/activate exists."
else
    echo "ERROR: $VENV/bin/activate was not installed.  Cannot continue."
    sleeping
fi

. $VENV/bin/activate

PYTHON39=$(which python3.9)
PIP3=$(which pip3)

echo "PYTHON39=$PYTHON39"
echo "PIP3=$PIP3"

PIPTEST=$(pip3 --version)
echo "PIPTEST=$PIPTEST"

if [ -f "$PIP3" ]; then
    echo "Importing Python REQS"
    $PIP3 install python-dotenv
else
    echo "ERROR: Cannot configure AWS from .env using $PYFILE.  Cannot continue."
    sleeping
fi

PYFILE=$DIR0/configure.py
cat << PYEOF1 > $PYFILE
import os
import sys

print('BEGIN: ' + sys.version)
for f in sys.path:
    print(f)
print('END!!!')

import dotenv

fp = dotenv.find_dotenv()
print('*** DEBUG: fp={}'.format(fp))
dotenv.load_dotenv(fp)

__u_option__ = "-u"
is_u = any([str(arg).find(__u_option__) > -1 for arg in sys.argv])

whoami = None
if (is_u):
    try:
        whoami = [str(arg).split('=')[-1] for arg in sys.argv if (str(arg).find(__u_option__) > -1)][0]
    except:
        pass

assert whoami is not None, 'ERROR: No user specified.  Please specify a user with the -u option.'

print('*** whoami: {}'.format(whoami))

home_directory = '/home/{}'.format(whoami)
if (whoami == 'root'):
    home_directory = '/{}'.format(whoami)

aws_directory = '{}/.aws'.format(home_directory)
if (not os.path.exists(aws_directory)):
    os.mkdir(aws_directory)

print('BEGIN: os.environ')
for k,v in os.environ.items():
    print('{} -> {}'.format(k, v))
print('END!!! os.environ')

AWS_CREDS_FILE = '{}/credentials'.format(aws_directory)
with open(AWS_CREDS_FILE, 'w') as fOut:
    fOut.write('[default]\n')
    fOut.write('aws_access_key_id = {}\n'.format(os.environ.get('aws_access_key_id')))
    fOut.write('aws_secret_access_key = {}\n'.format(os.environ.get('aws_secret_access_key')))

AWS_CONFIG_FILE = '{}/config'.format(aws_directory)
with open(AWS_CONFIG_FILE, 'w') as fOut:
    fOut.write('[default]\n')
    fOut.write('region = {}\n'.format(os.environ.get('aws_region')))
PYEOF1

if [ -f "$DIR0/.env" ]; then
    if [ -f "$PYFILE" ]; then
        echo "Configuring AWS from .env."
        $PYTHON39 $PYFILE -e=$DIR0/.env -u=$(whoami)
    else
        echo "ERROR: Cannot configure AWS from .env using $PYFILE.  Cannot continue."
        sleeping
    fi
fi

AWS_CREDS_FILE=~/.aws/credentials

if [ -f "$AWS_CREDS_FILE" ]; then
    echo "AWS credentials file created."
    cat $AWS_CREDS_FILE
fi

AWS_CONFIG_FILE=~/.aws/config

if [ -f "$AWS_CONFIG_FILE" ]; then
    echo "AWS config file created."
    cat $AWS_CONFIG_FILE
fi

echo "INFO: AWS CLI is installed and configured. Good to go!"

ETC_PIHOLE=etc_pihole
ETC_DNSMASQ_D=etc_dnsmasq_d
##################################################
ETC_PIHOLE_TEST=$(docker volume ls | grep $ETC_PIHOLE)

if [ -z "$ETC_PIHOLE_TEST" ]; then
    echo "Creating: ETC_PIHOLE:$ETC_PIHOLE."
    docker volume create $ETC_PIHOLE
fi

ETC_DNSMASQ_D_TEST=$(docker volume ls | grep $ETC_DNSMASQ_D)

if [ -z "$ETC_DNSMASQ_D_TEST" ]; then
    echo "Creating: ETC_DNSMASQ_D:$ETC_PIHOLE."
    docker volume create $ETC_DNSMASQ_D
fi

##################################################

if [ "$DIR0." == "/." ]; then
    DIR0=
fi

PRODUCT_DIR=$DIR0
echo "(***) PRODUCT_DIR=$PRODUCT_DIR"
cd $PRODUCT_DIR

ls -la $PRODUCT_DIR*

exit

REDIS_DATA_DIR=$PRODUCT_DIR/redis/data

if [ -d "$REDIS_DATA_DIR" ]; then
    echo "INFO: Redis data directory exists. Proceeding."
else
    echo "ERROR: Redis data directory does not exist. Cannot continue."
    sleeping
fi

REDIS_VOLUME_DIR=$(docker volume inspect $REDIS_DATA | jq -r '.[0].Mountpoint')

if [ -d "$REDIS_VOLUME_DIR" ]; then
    echo "INFO: Redis volume directory exists. Proceeding."
else
    echo "ERROR: Redis volume directory does not exist. Cannot continue."
    sleeping
fi

cp $REDIS_DATA_DIR/* $REDIS_VOLUME_DIR

if [ -f "$REDIS_VOLUME_DIR/$REDIS_CONF" ]; then
    echo "INFO: Redis config file exists. Proceeding."
else
    echo "ERROR: Redis config file does not exist. Cannot continue."
    sleeping
fi

SOURCE_DEPLOY_DIR=$PRODUCT_DIR/postgres-deploy

if [ -d "$SOURCE_DEPLOY_DIR" ]; then
    echo "INFO: $SOURCE_DEPLOY_DIR directory exists. Proceeding."
else
    echo "ERROR: $SOURCE_DEPLOY_DIR directory does not exist. Cannot continue."
    sleeping
fi

TARGET_VOLUME_DIR=$(docker volume inspect $POSTGRES_DEPLOY_DB | jq -r '.[0].Mountpoint')

if [ -d "$TARGET_VOLUME_DIR" ]; then
    echo "INFO: $TARGET_VOLUME_DIR directory exists. Proceeding."
else
    echo "ERROR: $TARGET_VOLUME_DIR directory does not exist. Cannot continue."
    sleeping
fi

cp -R $SOURCE_DEPLOY_DIR/db/* $TARGET_VOLUME_DIR/.
cp $SOURCE_DEPLOY_DIR/pgdbsrcipts.sh $TARGET_VOLUME_DIR/pgdbsrcipts.sh

if [ -f "$TARGET_VOLUME_DIR/pgdbsrcipts.sh" ]; then
    echo "INFO: $TARGET_VOLUME_DIR/pgdbsrcipts.sh file exists. Proceeding."
else
    echo "ERROR: $TARGET_VOLUME_DIR/pgdbsrcipts.sh file does not exist. Cannot continue."
    sleeping
fi

if [ -f "/docker-compose.yml" ]; then
    echo "INFO: /docker-compose.yml file exists. Proceeding."
else
    echo "ERROR: /docker-compose.yml file does not exist. Cannot continue."
    sleeping
fi

if [ -f "$PRODUCT_DIR/docker-compose.yml" ]; then
    echo "INFO: $PRODUCT_DIR/docker-compose.yml file exists. Proceeding."
else
    echo "ERROR: $PRODUCT_DIR/docker-compose.yml file does not exist. Cannot continue."
    sleeping
fi

echo "Replacing the old docker-compose.yml with the one that works for deployments."
rm -f $PRODUCT_DIR/docker-compose.yml
cp /docker-compose.yml $PRODUCT_DIR/docker-compose.yml

cd $PRODUCT_DIR && docker-compose up -d --build

CID=$(docker ps -qf "name=sx-postgres")

if [ -z "$CID" ]; then
    echo "ERROR: Postgres container not found. Cannot continue."
    sleeping
else
    echo "INFO: Postgres container found. Proceeding."
fi

POSTGRES_INIT_SCRIPT=/docker-entrypoint-initdb.d/pgdbsrcipts.sh
docker exec -it $CID $POSTGRES_INIT_SCRIPT

#################################################
###  END!!! Simulated Build Environment  ########
#################################################

sleeping
exit
