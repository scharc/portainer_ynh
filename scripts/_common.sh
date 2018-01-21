#!/bin/bash

# test in container
dockerapp_ynh_incontainer () {
        if [ -f /.dockerenv ]; then
                echo "0"
        else
                echo "1"
        fi
}

# check or do docker install
dockerapp_ynh_checkinstalldocker () {
	ret=$(sh _dockertest.sh)
	incontainer=$(dockerapp_ynh_incontainer)
        if [ $ret == 127 ]
	then
		# install
		start_docker="0"
		[ ! -e /var/run/docker.sock ] && [ -z ${DOCKER_HOST+x} ] && start_docker="1"
		curl -sSL https://get.docker.com | sh
		[ "$start_docker" == "1" ] && systemctl start docker && systemctl enable docker
		pip install docker-compose
		MORE_LOG1=" despite previous docker installation"

		# retest
		ret=$(sh _dockertest.sh)
	fi

        if [ "$incontainer" == "0" ]
        then
		MORE_LOG3=""
		[ ! -d /home/yunohost.docker ] && MORE_LOG3=". Also, you have to mount shared volume from host, add '' -v /home/yunohost.docker:/home/yunohost.docker '' "
		echo "Ho ! You are in a Docker container :)$MORE_LOG3";
		MORE_LOG2=" If your already in a Docker container please add '' -e DOCKER_HOST=tcp://$(hostname -I | awk '{print $1}'):2376 '' or '' -v /var/run/docker.sock: /var/run/docker.sock ''"
        fi

	if [ $ret != 0 ]
	then
		ynh_die "Sorry ! Your Docker deamon don't work$MORE_LOG1 ... Please check your system logs.$MORE_LOG2$MORE_LOG3"
	fi

}

# find replace
dockerapp_ynh_findreplace () {
	for file in $(grep -rl "$2" "$1")
	do
		ynh_replace_string "$2" "$3" "$file"
	done
}

dockerapp_ynh_findreplacepath () {
	dockerapp_ynh_findreplace docker/. "$1" "$2"
	dockerapp_ynh_findreplace ../conf/. "$1" "$2"
}

# find replace all variables
dockerapp_ynh_findreplaceallvaribles () {
	dockerapp_ynh_findreplacepath "YNH_APP" "$app"
        dockerapp_ynh_findreplacepath "YNH_DATA" "$data_path"
        dockerapp_ynh_findreplacepath "YNH_PORT" "$port"
        dockerapp_ynh_findreplacepath "YNH_PATH" "$path_url"
        dockerapp_ynh_findreplacepath "YNH_HOST" "$docker_host"
        [ "$incontainer" == "0" ] && dockerapp_ynh_findreplacepath "YNH_ID" "$yunohost_id"
	bash docker/_specificvariablesapp.sh
}

# load variables
dockerapp_ynh_loadvariables () {
	data_path=/home/yunohost.docker/$app
	port=$(ynh_app_setting_get $app port)
	[ "$port" == "" ] && port=0
	path_url=/
	export architecture=$(dpkg --print-architecture)
	export incontainer=$(dockerapp_ynh_incontainer)
        if [ "$incontainer" == "0" ]
        then
                docker_host=$(/sbin/ip route|awk '/default/ { print $3 }')
                yunohost_id=$(cat /proc/self/cgroup | grep "docker/.*" | head -1 | sed "s@.*docker/\(.*\)@\1@")
        else
                docker_host=$(hostname -I | awk '{print $1}')
        fi
}

# copy conf app
dockerapp_ynh_copyconf () {
	mkdir -p $data_path
	cp -rf ../conf/app $data_path
}

# docker run
dockerapp_ynh_run () {
	ret=$(bash docker/run.sh)
	if [ "$ret" != "0" ]
	then
		docker logs $app
		ynh_die "Sorry ! App cannot start with docker. Please check docker logs."
	fi
}

# docker rm
dockerapp_ynh_rm () {
	ynh_replace_string "YNH_APP" "$app" docker/rm.sh
	bash docker/rm.sh
}

# Modify Nginx configuration file and copy it to Nginx conf directory
dockerapp_ynh_preparenginx () {
	# get port after container created
	port=$(docker port "$app" | awk -F':' '{print $NF}')
	ynh_app_setting_set $app port $port


	ynh_add_nginx_config
}

# Regenerate SSOwat conf
dockerapp_ynh_reloadservices () {
	yunohost app ssowatconf
}
