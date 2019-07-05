#!/bin/bash

echo
echo "Environment:        ${APP_ENVIRONMENT}"

[[ -n ${APP_OTF_DEPLOY_OPT} ]] && APP_OTF_UPDATES="enabled" || APP_OTF_UPDATES="disabled"
echo "On the fly updates: ${APP_OTF_UPDATES}"

echo "Working direcotry:  $(pwd)"
echo
echo "File listing:"
echo "-------------"

ls -l

echo

# only if the following are all satisfied:
#       - environment is local
#       - on the fly changes are enabled
#       - working directory is the on the fly directory
#       - the on the fly directory is empty
#       - the release directory is populated ( with the packaged application )
# then the on the fly directory can be automatically initially populated with cloned contents from the release directory to avoid having to do this manually on the local docker host
if [[ ( -n $(echo ${APP_ENVIRONMENT} | grep "local") ) && ( -n "${APP_OTF_DEPLOY_OPT}" ) && ( $(pwd) == "${APP_HOME_DIR}/otf" ) && ( -z "$(ls ${APP_HOME_DIR}/otf)" ) && ( -n "$(ls ${APP_HOME_DIR}/release)" ) ]]
then
	rsync -a --stats ${APP_HOME_DIR}/release/ ${APP_HOME_DIR}/otf/
fi

if [[ -f .env ]]
then
	# Populate configuration with actual intended settings ( done during runtime so as not to store such settings permanently in the image ) 
	if [[ -n $(grep _INHERIT_ .env) ]]  
    	then
		sed -i -re "s/APP_ENV=.*/APP_ENV=${APP_ENVIRONMENT}/g;s/DB_HOST=.*/DB_HOST=${MYSQL_HOST}/g;s/DB_PORT=.*/DB_PORT=${MYSQL_PORT}/g" .env
		sed -i -re "s/DB_DATABASE=.*/DB_DATABASE=${MYSQL_DATABASE}/g;s/DB_USERNAME=.*/DB_USERNAME=${MYSQL_USER}/g" .env

		sed -i -re "s#APP_KEY=.*#APP_KEY=${APPKEY}#g;s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_PASSWORD}/g;s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDISPW}/g" .env
		sed -i -re "s/MAIL_PASSWORD=.*/MAIL_PASSWORD=${MAILPW}/g;s/PUSHER_APP_KEY=.*/PUSHER_APP_KEY=${PUSHKEY}/g;s/PUSHER_APP_SECRET=.*/PUSHER_APP_SECRET=${PUSHSEC}/g" .env
    	fi
	
	DBCHECK=2

	echo "Wating for DB at $MYSQL_HOST:$MYSQL_PORT to come up ..."

	while [ $DBCHECK -ne 0 ]
	do
		sleep 5

		echo -n ".."

		echo | nc -w 2 $MYSQL_HOST $MYSQL_PORT > /dev/null 2>&1
		
		DBCHECK=$?
	done

	echo

	# if the DB is empty and no tables are found then proceed to set up the tables and add data
	if [[ -z "$(mysql -N -B -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'show tables' ${MYSQL_DATABASE})" ]] 
	then
		php artisan migrate --seed
	else
		echo "Skipping table creation and seeding as DB has already been populated ..."
	fi

	# clear variables that are now no longer required
        unset APP_ENVIRONMENT APP_OTF_DEPLOY_OPT APP_HOME_DIR APPKEY MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD REDISPW MAILPW PUSHKEY PUSHSEC

	php artisan serve --host=0.0.0.0 --port=${APPPORT}
else
	echo -e "\nQuitting due to missing .env file! Please ensure this file is present to be able to launch the application.\n"
fi
