#!/bin/bash
# chkconfig: 2345 90 10
# description: Socks5Proxy
### BEGIN INIT INFO
# Provides:          CTCGFW_SHELLSCRIPT
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Socks5Proxy at boot time
# Description:       Enable rclone by daemon.
### END INIT INFO###

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

function set_fonts_colors(){
	# Font colors
	default_fontcolor="\033[0m"
	red_fontcolor="\033[31m"
	green_fontcolor="\033[32m"
	warning_fontcolor="\033[33m"
	info_fontcolor="\033[36m"

	# Background colors
	red_backgroundcolor="\033[41;37m"
	green_backgroundcolor="\033[42;37m"
	yellow_backgroundcolor="\033[43;37m"

	# Fonts
	error_font="${red_fontcolor}[Error]${default_fontcolor}"
	ok_font="${green_fontcolor}[OK]${default_fontcolor}"
	warning_font="${warning_fontcolor}[Warning]${default_fontcolor}"
	info_font="${info_fontcolor}[Info]${default_fontcolor}"
}

function base_check(){
	[ "$(id -u)" != "0" ] && { echo "${error_font}You must be root to run this script."; exit 1; }

	if [ -n "$(grep 'Aliyun Linux release' /etc/issue)" -o -e "/etc/redhat-release" ]; then
		System_OS="CentOS"
		[ -n "$(grep ' 7\.' /etc/redhat-release)" ] && OS_Version="7"
		[ -n "$(grep ' 6\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release6 15' /etc/issue)" ] && OS_Version="6"
		[ -n "$(grep ' 5\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release5' /etc/issue)" ] && OS_Version="5"
		if [ -z "${OS_Version}" ]; then
			[ ! -e "$(command -v lsb_release)" ] && { yum -y update; yum -y install redhat-lsb-core; clear; }
			OS_Version="$(lsb_release -sr | awk -F. '{print $1}')"
		fi
	elif [ -n "$(grep 'Amazon Linux AMI release' /etc/issue)" -o -e /etc/system-release ]; then
		System_OS="CentOS"
		OS_Version="6"
	elif [ -n "$(grep Debian /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Debian' ]; then
		System_OS="Debian"
		[ ! -e "$(command -v lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
		OS_Version="$(lsb_release -sr | awk -F. '{print $1}')"
	elif [ -n "$(grep Deepin /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Deepin' ]; then
		System_OS="Debian"
		[ ! -e "$(command -v lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
		OS_Version="$(lsb_release -sr | awk -F. '{print $1}')"
	elif [ -n "$(grep Ubuntu /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Ubuntu' ]; then
		System_OS="Ubuntu"
		[ ! -e "$(command -v lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
		OS_Version="$(lsb_release -sr | awk -F. '{print $1}')"
	else
		echo -e "${error_font}Unsupport OS, please change your OS and retry."
		exit 1
	fi

	if [[ "$(uname -m)" == "i686" ]] || [[ "$(uname -m)" == "i386" ]]; then
		System_Bit="386"
	elif [[ "$(uname -m)" == *"x86_64"* ]]; then
		System_Bit="arm64"
	elif [[ "$(uname -m)" == *"armv7"* ]] || [[ "$(uname -m)" == "armv6l" ]]; then
		System_Bit="arm"
	elif [[ "$(uname -m)" == *"armv8"* ]] || [[ "$(uname -m)" == "aarch64" ]]; then
		System_Bit="arm64"
	else
		echo -e "${error_font}Unsupported architecture, please change your architecture and retry."
		exit 1
	fi
}

function check_running(){
	running_pid="$(ps -ef |grep "gost" |grep -v "grep" | grep -v ".sh"| grep -v "init.d" |grep -v "service" |awk '{print $2}')"
	if [ -n "${running_pid}" ]; then
		return 0
	else
		return 1
	fi
}

function start_running(){
	check_running
	if [ "$?" -eq "0" ]; then
		echo -e "${info_font}Gost is already running, PID: ${running_pid}."
		exit_code=2
	else
		cd "/usr/local/gost"
		echo -e "Try to start Gost..."
		nohup /usr/local/gost/gost -C /usr/local/gost/socks5.json > /usr/local/gost/running_log.log 2>&1 &
		sleep 3
		check_running
		if [ "$?" -eq "0" ]; then
			echo -e "${ok_font}Started successfully, Gost is running now."
			exit_code=0
		else
			echo -e "${error_font}Failed to start, please retry later."
			exit_code=1
		fi
	fi
}

function stop_running(){
	check_running
	if [ "$?" -eq "0" ]; then
		kill -9 "${running_pid}"
		if [ "$?" -eq "0" ]; then
			echo -e "${ok_font}Stopped successfully, Gost isn't running now."
			exit_code=0
		else
			echo -e "${error_font}Failed to stop, please retry later."
			exit_code=1
		fi
	else
		echo -e "${info_font}Gost is already stopped."
		exit_code=2
	fi
}

function running_status(){
	check_running
	if [ "$?" -eq "0" ]; then
		echo -e "${info_font}Gost is running, PID: ${running_pid}."
		exit_code=0
	else
		echo -e "${error_font}Gost isn't running."
		exit_code=1
	fi
}

function restart_running(){
	stop_running
	sleep 3
	start_running
}

function main(){
	set_fonts_colors
	base_check
	case "${operational}" in
		"start")
			start_running
		;;
		"stop")
			stop_running
		;;
		"restart")
			restart_running
		;;
		"status")
			running_status
		;;
		*)
			echo -e "${info_font}Usage: $0 {start|stop|restart|status}" >&2
			exit_code=3
		;;
	esac
}

case "$1" in
	start|stop|restart|status)
		operational="$1"
		main
	;;
	*)
		echo -e "${info_font}Usage: $0 {start|stop|restart|status}" >&2
		exit_code=3
	;;
esac

exit "${exit_code}"