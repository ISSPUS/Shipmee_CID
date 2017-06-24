#!/bin/bash

CONFIG_ROOT="/home/core/Shipmee_CID"

## Include dependencies

source $CONFIG_ROOT/commonDependencies/DockerUtils.sh


## Defining variables

source $CONFIG_ROOT/commonDependencies/variables.sh

BRANCH="bdConnection"
URL_VIRTUAL_HOST="bdc.shipmee.es"
URL_IMG_HOST="i.$URL_VIRTUAL_HOST"
CONF_TOMCAT_SERVER="$CONFIG_ROOT/$BRANCH-conf/tomcat7/server.xml"
IMG_PATH="$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/images"

ENVS_FILE="$SHIPMEE_PRIV_CONFIG_PATH/.env-variables-file_dev"


## Compiling source
echo "_____________ Generando WAR _____________"

COMPILE_FOLDER="$PATH_ROOT/war_generation/$RANDOM_FOLDER_NAME"

mkdir -p "$COMPILE_FOLDER"

cp -r $REPO_PATH/$ENV_NAME-$BRANCH/* $COMPILE_FOLDER

cd $COMPILE_FOLDER

    # Eliminar robots.txt para que no sea indexada por los buscadores
rm -f src/main/webapp/robots.txt

docker run --rm \
    -v $COMPILE_FOLDER:/root \
    -v "$PATH_ROOT/war_generation/.m2":/root/.m2 \
    -w /root \
    maven:3-jdk-8-alpine \
    mvn clean compile war:war


echo "_____________ Persistiendo war y otros archivos necesarios _____________"

find "$COMPILE_FOLDER/target/" -follow -name *.war -exec cp {} "$PATH_ROOT/Shipmee-$BRANCH.war" \;
# mv -f $COMPILE_FOLDER/target/Shipmee-*.war $PATH_ROOT/Shipmee-$BRANCH.war
mv -f $COMPILE_FOLDER/initialize.sql $PATH_ROOT/initialize-$BRANCH.sql


echo "_____________ Eliminando despliegue actual _____________"

dockerStopAndRm $ENV_NAME-$BRANCH-mysql
dockerStopAndRm $ENV_NAME-$BRANCH-tomcat
dockerStopAndRm $ENV_NAME-$BRANCH-images



echo "_____________ Preparando archivos _____________"

rm -r "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/"
mkdir -p "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/"
mkdir -p "$IMG_PATH"

# WAR
cp $PATH_ROOT/Shipmee-$BRANCH.war $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/ROOT.war

# SQL
cp $PATH_ROOT/initialize-$BRANCH.sql $PATH_ROOT/deploys/$ENV_NAME/$BRANCH/populate.sql

# Settings
cp -R $CONFIG_ROOT/$BRANCH-conf/* "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/"

# Permissions
chmod -R 777 $IMG_PATH


echo "_____________ Desplegando contenedores de $ENV_NAME - $BRANCH _____________"

docker run --name $ENV_NAME-$BRANCH-mysql \
    -v "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/populate.sql":/home/user/populate.sql \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    --restart=always \
    -d mysql:5.7 \
    --bind-address=0.0.0.0



echo "$ENV_NAME-mysql creado !"

sleep 20

persistPasswords $ENV_NAME-$BRANCH-mysql $BRANCH $MYSQL_ROOT_PASSWORD $PASSWORD_PATH

docker exec $ENV_NAME-$BRANCH-mysql \
    bash -c "exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < /home/user/populate.sql"

echo "$ENV_NAME-$BRANCH-mysql populado !"

sleep 20

dockerTimeZoneGeneric $ENV_NAME-$BRANCH-mysql

docker restart $ENV_NAME-$BRANCH-mysql

sleep 5

docker run --rm \
    --link $ENV_NAME-$BRANCH-mysql:$MYSQL_PROJECT_ROUTE \
    -v $COMPILE_FOLDER/:/root \
    -v "$PATH_ROOT/war_generation/.m2":/root/.m2 \
    -w /root \
    maven:3-jdk-8-alpine \
    mvn exec:java -Dexec.mainClass="utilities.PopulateDatabase"

rm -rf $COMPILE_FOLDER











docker run -d --name $ENV_NAME-$BRANCH-tomcat \
    --user root \
    --link $ENV_NAME-$BRANCH-mysql:$MYSQL_PROJECT_ROUTE \
    -v "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/webapps/":/usr/local/tomcat/webapps \
    -v "$PATH_ROOT/deploys/$ENV_NAME/$BRANCH/tomcat7/server.xml":/usr/local/tomcat/conf/server.xml \
    -v "$IMG_PATH":/public_images \
    -v /dev/urandom:/dev/random \
    --restart=always \
    -e IMG_PATH="/public_images" \
    -e URL_IMG_HOST="https://$URL_IMG_HOST" \
    --env-file $ENVS_FILE \
    -e VIRTUAL_HOST="$URL_VIRTUAL_HOST" \
    -e VIRTUAL_PORT=8080 \
    -e "LETSENCRYPT_HOST=$URL_VIRTUAL_HOST" \
    -e "LETSENCRYPT_EMAIL=shipmee.contact@gmail.com" \
    tomcat:7-jre8

dockerTimeZoneGeneric $ENV_NAME-$BRANCH-tomcat

docker run -d --name $ENV_NAME-$BRANCH-images \
    -v $IMG_PATH:/usr/share/nginx/html:ro \
    -e VIRTUAL_HOST="$URL_IMG_HOST" \
    -e VIRTUAL_PORT=80 \
    -e "LETSENCRYPT_HOST=$URL_IMG_HOST" \
    -e "LETSENCRYPT_EMAIL=shipmee.contact@gmail.com" \
    --restart=always \
    nginx:1.11-alpine

echo "Aplicación desplegada en https://$URL_VIRTUAL_HOST"

