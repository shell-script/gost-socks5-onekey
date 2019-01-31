#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

function set_fonts_colors(){
	clear
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

function check_os(){
	clear
	echo -e "正在检测当前是否为ROOT用户..."
	if [ "${EUID}" -eq "0" ]; then
		clear
		echo -e "${ok_font}检测到当前为Root用户。"
	else
		clear
		echo -e "${error_font}当前并非ROOT用户，请先切换到ROOT用户后再使用本脚本。"
		exit 1
	fi
	clear
	echo -e "正在检测此系统是否被支持..."
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
		clear
		echo -e "${error_font}目前暂不支持您使用的操作系统。"
		exit 1
	fi
	clear
	echo -e "${ok_font}该脚本支持您的系统。"
	clear
	echo -e "正在检测系统构架是否被支持..."
	if [[ "$(uname -m)" == "i686" ]] || [[ "$(uname -m)" == "i386" ]]; then
		System_Bit="386"
	elif [[ "$(uname -m)" == *"x86_64"* ]]; then
		System_Bit="amd64"
	elif [[ "$(uname -m)" == *"armv7"* ]] || [[ "$(uname -m)" == "armv6l" ]]; then
		System_Bit="arm"
	elif [[ "$(uname -m)" == *"armv8"* ]] || [[ "$(uname -m)" == "aarch64" ]]; then
		System_Bit="amd64"
	else
		clear
		echo -e "${error_font}目前暂不支持此系统的构架。"
		exit 1
	fi
	clear
	echo -e "${ok_font}该脚本支持您的系统构架。"
	clear
	echo -e "正在检测进程守护安装情况..."
	if [ -n "$(command -v systemctl)" ]; then
		clear
		daemon_name="systemd"
		echo -e "${ok_font}您的系统中已安装 systemctl。"
	elif [ -n "$(command -v chkconfig)" ]; then
		clear
		daemon_name="sysv"
		echo -e "${ok_font}您的系统中已安装 chkconfig。"
	elif [ -n "$(command -v update-rc.d)" ]; then
		clear
		daemon_name="sysv"
		echo -e "${ok_font}您的系统中已安装 update-rc.d。"
	else
		clear
		echo -e "${error_font}您的系统中没有配置进程守护工具，安装无法继续！"
		exit 1
	fi
	clear
	echo -e "${ok_font}Support OS: ${System_OS}${OS_Version} ${System_Bit} with ${daemon_name}."
}

function check_install_status(){
	if [ ! -f "/usr/local/gost/gost" ]; then
		install_status="${red_fontcolor}未安装${default_fontcolor}"
		gost_use_command="${red_fontcolor}未安装${default_fontcolor}"
	else
		install_status="${green_fontcolor}已安装${default_fontcolor}"
		gost_pid="$(ps -ef |grep "gost" |grep -v "grep" | grep -v ".sh"| grep -v "init.d" |grep -v "service" |awk '{print $2}')"
		if [ -z "${gost_pid}" ]; then
			gost_status="${red_fontcolor}未运行${default_fontcolor}"
			gost_use_command="${red_fontcolor}未运行${default_fontcolor}"
			gost_pid="0"
		else
			gost_status="${green_fontcolor}正在运行${default_fontcolor} | ${green_fontcolor}${gost_pid}${default_fontcolor}"
			ip_address="$(curl -4 ip.sb)"
			if [ -z "${ip_address}" ]; then
				ip_address="$(curl -4 https://ipinfo.io/ip)"
			fi
			if [ -n "$(grep -Eo "[0-9a-zA-Z\_\-]+:[0-9a-zA-Z\_\-]+" "/usr/local/gost/socks5.json")" ]; then
				gost_use_command="\n${green_backgroundcolor}https://t.me/socks?server=${ip_address}?port=$(grep -Eo "@\:[0-9]+" /usr/local/gost/socks5.json | sed "s/@://g")&user=$(grep -Eo "[0-9a-zA-Z\_\-]+:[0-9a-zA-Z\_\-]+" /usr/local/gost/socks5.json | awk -F : '{print $1}')&pass=$(grep -Eo "[0-9a-zA-Z\_\-]+:[0-9a-zA-Z\_\-]+" /usr/local/gost/socks5.json | awk -F : '{print $2}')${default_fontcolor}"
			else
				gost_use_command="\n${green_backgroundcolor}https://t.me/socks?server=${ip_address}?port=$(grep -Eo "\:[0-9]+" /usr/local/gost/socks5.json | sed "s/://g")${default_fontcolor}"
			fi
		fi
	fi
}

function echo_install_list(){
	clear
	echo -e "脚本当前安装状态：${install_status}
--------------------------------------------------------------------------------------------------
	1.安装Gost
--------------------------------------------------------------------------------------------------
Gost当前运行状态：${gost_status}
	2.更新脚本
	3.更新程序
	4.卸载程序

	5.启动程序
	6.关闭程序
	7.重启程序

--------------------------------------------------------------------------------------------------
Telegram代理链接：${gost_use_command}
--------------------------------------------------------------------------------------------------"
	stty erase '^H' && read -r -p "请输入序号：" determine_type
	if [ "${determine_type}" -ge "1" ] && [ "${determine_type}" -le "10" ]; then
		data_processing
	else
		clear
		echo -e "${error_font}请输入正确的序号！"
		exit 1
	fi
}

function data_processing(){
	clear
	echo -e "正在处理请求中..."
	if [ "${determine_type}" = "2" ]; then
		upgrade_shell_script
	elif [ "${determine_type}" = "3" ]; then
		stop_service
		prevent_uninstall_check
		upgrade_program
		restart_service
		clear
		echo -e "${ok_font}Gost更新成功。"
	elif [ "${determine_type}" = "4" ]; then
		prevent_uninstall_check
		uninstall_program
	elif [ "${determine_type}" = "5" ]; then
		prevent_uninstall_check
		start_service
	elif [ "${determine_type}" = "6" ]; then
		prevent_uninstall_check
		stop_service
	elif [ "${determine_type}" = "7" ]; then
		prevent_uninstall_check
		restart_service
	else
		if [ "${determine_type}" = "1" ]; then
			prevent_install_check
			os_update
			generate_base_config
			clear
			mkdir -p /usr/local/gost
			cd /usr/local/gost
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}创建文件夹成功。"
			else
				clear
				echo -e "${error_font}创建文件夹失败！"
				clear_install_reason="创建文件夹失败。"
				clear_install
				exit 1
			fi
			gost_version="$(wget -qO- "https://github.com/ginuerzh/gost/tags"|grep "/gost/releases/tag/"|head -n 1|awk -F "/tag/" '{print $2}'|sed 's/\">//'|sed 's/v//g')"
			wget "https://github.com/ginuerzh/gost/releases/download/v${gost_version}/gost_${gost_version}_linux_${System_Bit}.tar.gz"
			tar -zxvf "gost_${gost_version}_linux_${System_Bit}.tar.gz"
			mv "gost_${gost_version}_linux_${System_Bit}/gost" "./gost"
			rm -f "gost_${gost_version}_linux_${System_Bit}.tar.gz"
			rm -rf "gost_${gost_version}_linux_${System_Bit}"
			if [ -f "/usr/local/gost/gost" ]; then
				clear
				echo -e "${ok_font}下载Gost成功。"
			else
				clear
				echo -e "${error_font}下载Gost文件失败！"
				clear_install_reason="下载Gost文件失败。"
				clear_install
				exit 1
			fi
			clear
			chmod +x "/usr/local/gost/gost"
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}设置Gost执行权限成功。"
			else
				clear
				echo -e "${error_font}设置Gost执行权限失败！"
				clear_install_reason="设置Gost执行权限失败。"
				clear_install
				exit 1
			fi
			clear
			input_port
			clear
			echo -e "${info_font}温馨提示：用户名和密码仅支持大小写字母、数字、下划线和横线，输入其他字符会导致控制台输出的TG代理链接出现问题，届时请手动执行下面的命令以查看链接：\n${green_backgroundcolor}cat /usr/local/gost/telegram_link.info${default_fontcolor}\n\n"
			stty erase '^H' && read -r -p "请输入连接用户名（可空）：" connect_username
			if [ -n "${connect_username}" ]; then
				stty erase '^H' && read -r -p "请输入连接密码：" connect_password
				if [ -z "${connect_password}" ]; then
					clear
					echo -e "${error_font}连接密码不能为空！"
					clear_install_reason="连接密码不能为空！"
					clear_install
					exit 1
				fi
			fi
			clear
			echo -e "${info_font}Gost拥有路由控制功能，可以指定代理的内容，借助此功能可实现只代理Telegram，无法用其代理其他内容，例如Google、Youtube等。\n${info_font}温馨提示：脚本默认设置只能用于Telegram，如需取消请输入N。\n\n"
			stty erase '^H' && read -r -p "是否需要设定为只能用于Telegram？（Y/n）：" install_for_tgonly
			case "${install_for_tgonly}" in
			[nN][oO]|[nN])
				clear
				echo -e "${ok_font}已取消设定为Telegram专用。"
				;;
			*)
				telegram_iprange="$(echo -e "$(echo -e "$(curl https://ipinfo.io/AS59930 | grep -Eo "[0-9]+.[0-9]+.[0-9]+.[0-9]+/[0-9]+")\n$(curl https://ipinfo.io/AS62041 | grep -Eo "[0-9]+.[0-9]+.[0-9]+.[0-9]+/[0-9]+")" | sort -u -r)\n$(echo -e "$(curl https://ipinfo.io/AS59930 | grep -Eo "[0-9a-z]+\:[0-9a-z]+\:[0-9a-z]+\:\:/[0-9]+")\n$(curl https://ipinfo.io/AS62041 | grep -Eo "[0-9a-z]+\:[0-9a-z]+\:[0-9a-z]+\:\:/[0-9]+")" | sort -u)")"
				if [ -n "${telegram_iprange}" ]; then
					clear
					echo -e "${ok_font}获取Telegram IP段成功。"
				else
					clear
					echo -e "${error_font}获取Telegram IP段失败！"
					clear_install_reason="获取Telegram IP段失败！"
					clear_install
					exit 1
				fi
				echo -e "reverse true\n${telegram_iprange}" > "/usr/local/gost/telegram_iprange.info"
				if [ -n "$(cat "/usr/local/gost/telegram_iprange.info")" ]; then
					clear
					echo -e "${ok_font}写入路由控制配置成功。"
				else
					clear
					echo -e "${error_font}写入路由控制配置失败！"
					clear_install_reason="写入路由控制配置失败！"
					clear_install
					exit 1
				fi
				;;
			esac
			socks5_config="$(echo -e "
{
    \"Debug\": false,
    \"Retries\": 3,
    \"ServeNodes\": [")"
			if [ -n "${connect_username}" ] && [ -n "${connect_password}" ]; then
				socks5_config="$(echo -e "${socks5_config}
        \"socks5://${connect_username}:${connect_password}@:${install_port}")"
			else
				socks5_config="$(echo -e "${socks5_config}
        \"socks5://:${install_port}")"
			fi
			if [ -n "$(cat "/usr/local/gost/telegram_iprange.info")" ]; then
				socks5_config="$(echo -e "${socks5_config}?bypass=/usr/local/gost/telegram_iprange.info\"")"
			else
				socks5_config="$(echo -e "${socks5_config}\"")"
			fi
			socks5_config="$(echo -e "${socks5_config}
    ]
}")"
			echo -e "${socks5_config}" > "/usr/local/gost/socks5.json"
			if [ -n "$(cat "/usr/local/gost/socks5.json")" ]; then
				clear
				echo -e "${ok_font}写入配置文件成功。"
			else
				clear
				echo -e "${error_font}写入配置文件失败！"
				clear_install_reason="写入配置文件失败。"
				clear_install
				exit 1
			fi
			if [ "${daemon_name}" == "systemd" ]; then
				curl "https://raw.githubusercontent.com/shell-script/gost-socks5-onekey/master/gost.service" -o "/etc/systemd/system/gost.service"
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}下载进程守护文件成功。"
				else
					clear
					echo -e "${error_font}下载进程守护文件失败！"
					clear_install_reason="下载进程守护文件失败。"
					clear_install
					exit 1
				fi
				systemctl daemon-reload
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}重载进程守护文件成功。"
				else
					clear
					echo -e "${error_font}重载进程守护文件失败！"
					clear_install_reason="重载进程守护文件失败。"
					clear_install
					exit 1
				fi
				systemctl enable gost.service
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}设置Gost开启自启动成功。"
				else
					clear
					echo -e "${error_font}设置Gost开启自启动失败！"
					clear_install_reason="设置Gost开启自启动失败。"
					clear_install
					exit 1
				fi
			elif [ "${daemon_name}" == "sysv" ]; then
				curl "https://raw.githubusercontent.com/shell-script/gost-socks5-onekey/master/gost.sh" -o "/etc/init.d/gost"
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}下载进程守护文件成功。"
				else
					clear
					echo -e "${error_font}下载进程守护文件失败！"
					clear_install_reason="下载进程守护文件失败。"
					clear_install
					exit 1
				fi
				chmod +x "/etc/init.d/gost"
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}设置进程守护文件执行权限成功。"
				else
					clear
					echo -e "${error_font}设置进程守护文件执行权限失败！"
					clear_install_reason="设置进程守护文件执行权限失败。"
					clear_install
					exit 1
				fi
				if [ "${System_OS}" == "CentOS" ]; then
					chkconfig --add gost
					chkconfig gost on
				elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
					update-rc.d -f gost defaults
				fi
				if [ "$?" -eq "0" ]; then
					clear
					echo -e "${ok_font}设置Gost开启自启动成功。"
				else
					clear
					echo -e "${error_font}设置Gost开启自启动失败！"
					clear_install_reason="设置Gost开启自启动失败。"
					clear_install
					exit 1
				fi
			fi
			clear
			service gost start
			sleep 3s
			if [ -n "$(ps -ef |grep "gost" |grep -v "grep" | grep -v ".sh"| grep -v "init.d" |grep -v "service" |awk '{print $2}')" ]; then
				clear
				echo -e "${ok_font}Gost 启动成功。"
				echo_gost_config
			else
				clear
				echo -e "${error_font}Gost 启动失败！"
				echo_gost_config
				echo -e "\n\n${error_font}Gost 启动失败！"
			fi
		fi
	fi
	echo -e "\n${ok_font}请求处理完毕。"
}

function upgrade_shell_script(){
	clear
	echo -e "正在更新脚本中..."
	filepath="$(cd "$(dirname "$0")"; pwd)"
	filename="$(echo -e "${filepath}"|awk -F "$0" '{print $1}')"
	curl "https://raw.githubusercontent.com/shell-script/gost-socks5-onekey/master/gost-go.sh" -o "${filename}/gost-go.sh"
	if [ "$?" -eq "0" ]; then
		clear
		echo -e "${ok_font}脚本更新成功，脚本位置：\"${green_backgroundcolor}${filename}/$0${default_fontcolor}\"，使用：\"${green_backgroundcolor}bash ${filename}/$0${default_fontcolor}\"。"
	else
		clear
		echo -e "${error_font}脚本更新失败！"
	fi
}

function prevent_uninstall_check(){
	clear
	echo -e "正在检查安装状态中..."
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		echo -e "${ok_font}您已安装本程序，正在执行相关命令中..."
	else
		clear
		echo -e "${error_font}检测到您的系统中未安装Gost。"
		exit 1
	fi
}

function start_service(){
	clear
	echo -e "正在启动服务中..."
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		if [ "${gost_pid}" -eq "0" ]; then
			service gost start
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}Gost 启动成功。"
			else
				clear
				echo -e "${error_font}Gost 启动失败！"
			fi
		else
			clear
			echo -e "${error_font}Gost 正在运行。"
		fi
	else
		clear
		echo -e "${error_font}检测到您的系统中未安装Gost。"
		exit 1
	fi
}

function stop_service(){
	clear
	echo -e "正在停止服务中..."
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		if [ "${gost_pid}" -eq "0" ]; then
			echo -e "${error_font}Gost 未在运行。"
		else
			service gost stop
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}Gost 停止成功。"
			else
				clear
				echo -e "${error_font}Gost 停止失败！"
			fi
		fi
	else
		clear
		echo -e "${error_font}检测到您的系统中未安装Gost。"
		exit 1
	fi
}

function restart_service(){
	clear
	echo -e "正在重启服务中..."	
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		service gost restart
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}Gost 重启成功。"
		else
			clear
			echo -e "${error_font}Gost 重启失败！"
		fi
	else
		clear
		echo -e "${error_font}检测到您的系统中未安装Gost。"
		exit 1
	fi
}

function prevent_install_check(){
	clear
	echo -e "正在检测安装状态中..."
	if [ "${determine_type}" = "1" ]; then
		if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
			clear
			stty erase '^H' && read -r -r -p "您已经安装Gost，是否需要强制重新安装？[y/N]" install_force
			case "${install_force}" in
			[yY][eE][sS]|[yY])
				service gost stop
				close_port
				rm -rf /usr/local/gost
				if [ "${daemon_name}" == "systemd" ]; then
					systemctl disable gost
					rm -rf "/etc/systemd/system/gost.service"
				elif [ "${daemon_name}" == "sysv" ]; then
					if [ "${System_OS}" == "CentOS" ]; then
						chkconfig --del gost
					elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
						update-rc.d -f gost remove
					fi
					rm -rf /etc/init.d/gost
				fi
				;;
			*)
				clear
				echo -e "${error_font}安装已取消。"
				exit 1
				;;
			esac
		else
			clear
			echo -e "${ok_font}检测到您的系统中未安装Gost，正在执行相关命令中..."
		fi
	fi
}

function uninstall_program(){
	clear
	echo -e "正在卸载中..."
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		service gost stop
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}停止Gost成功。"
		else
			clear
			echo -e "${error_font}停止Gost失败！"
		fi
		close_port
		if [ "${daemon_name}" == "systemd" ]; then
			systemctl disable gost.service
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}取消开机自启动成功。"
			else
				clear
				echo -e "${error_font}取消开机自启动失败！"
			fi
			rm -f /etc/systemd/system/gost.service
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}删除进程守护文件成功。"
			else
				clear
				echo -e "${error_font}删除进程守护文件失败！"
			fi
		elif [ "${daemon_name}" == "sysv" ]; then
			if [ "${System_OS}" == "CentOS" ]; then
				chkconfig --del gost
			elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
				update-rc.d -f gost remove
			fi
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}取消开机自启动成功。"
			else
				clear
				echo -e "${error_font}取消开机自启动失败！"
			fi
			rm -f /etc/init.d/gost
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}删除进程守护文件成功。"
			else
				clear
				echo -e "${error_font}删除进程守护文件失败！"
			fi
		fi
		rm -rf /usr/local/gost
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}删除Gost文件夹成功。"
		else
			clear
			echo -e "${error_font}删除Gost文件夹失败！"
		fi
		clear
		echo -e "${ok_font}Gost卸载成功。"
	fi
}

function upgrade_program(){
	clear
	echo -e "正在更新程序中..."
	if [ "${install_status}" = "${green_fontcolor}已安装${default_fontcolor}" ]; then
		clear
		cd /usr/local/gost
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}进入Gost目录成功。"
		else
			clear
			echo -e "${error_font}进入Gost目录失败！"
			exit 1
		fi
		mv /usr/local/gost/gost /usr/local/gost/gost.bak
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}备份旧文件成功。"
		else
			clear
			echo -e "${error_font}备份旧文件失败！"
			exit 1
		fi
		echo -e "更新Gost主程序中..."
		clear
		gost_version="$(wget -qO- "https://github.com/ginuerzh/gost/tags"|grep "/gost/releases/tag/"|head -n 1|awk -F "/tag/" '{print $2}'|sed 's/\">//'|sed 's/v//g')"
		wget "https://github.com/ginuerzh/gost/releases/download/v${gost_version}/gost_${gost_version}_linux_${System_Bit}.tar.gz"
		tar -zxvf "gost_${gost_version}_linux_${System_Bit}.tar.gz"
		mv "gost_${gost_version}_linux_${System_Bit}/gost" "./gost"
		rm -f "gost_${gost_version}_linux_${System_Bit}.tar.gz"
		rm -rf "gost_${gost_version}_linux_${System_Bit}"
		if [ -f "/usr/local/gost/gost" ]; then
			clear
			echo -e "${ok_font}下载Gost成功。"
		else
			clear
			echo -e "${error_font}下载Gost文件失败！"
			mv /usr/local/gost/gost.bak /usr/local/gost/gost
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}恢复备份文件成功。"
			else
				clear
				echo -e "${error_font}恢复备份文件失败！"
			fi
			clear
			echo -e "${error_font}Gost升级失败！"
			echo -e "${error_font}失败原因：下载Gost文件失败。"
			echo -e "${info_font}如需获得更详细的报错信息，请在shell窗口中往上滑动。"
			exit 1
		fi
		clear
		chmod +x "/usr/local/gost/gost"
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}设置Gost执行权限成功。"
		else
			clear
			echo -e "${error_font}下载Gost文件失败！"
			mv /usr/local/gost/gost.bak /usr/local/gost/gost
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}恢复备份文件成功。"
			else
				clear
				echo -e "${error_font}恢复备份文件失败！"
			fi
			clear
			echo -e "${error_font}Gost升级失败！"
			echo -e "${error_font}失败原因：设置Gost执行权限失败。"
			echo -e "${info_font}如需获得更详细的报错信息，请在shell窗口中往上滑动。"
			exit 1
		fi
		clear
		echo -e "${ok_font}Gost更新成功。"
	fi
}

function clear_install(){
	clear
	echo -e "正在卸载中..."
	if [ "${determine_type}" -eq "1" ]; then
		service gost stop
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}停止Gost成功。"
		else
			clear
			echo -e "${error_font}停止Gost失败！"
		fi
		close_port
		if [ "${daemon_name}" == "systemd" ]; then
			systemctl disable gost.service
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}取消开机自启动成功。"
			else
				clear
				echo -e "${error_font}取消开机自启动失败！"
			fi
			rm -f /etc/systemd/system/gost.service
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}删除进程守护文件成功。"
			else
				clear
				echo -e "${error_font}删除进程守护文件失败！"
			fi
		elif [ "${daemon_name}" == "sysv" ]; then
			if [ "${System_OS}" == "CentOS" ]; then
				chkconfig --del gost
			elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
				update-rc.d -f gost remove
			fi
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}取消开机自启动成功。"
			else
				clear
				echo -e "${error_font}取消开机自启动失败！"
			fi
			rm -f /etc/init.d/gost
			if [ "$?" -eq "0" ]; then
				clear
				echo -e "${ok_font}删除进程守护文件成功。"
			else
				clear
				echo -e "${error_font}删除进程守护文件失败！"
			fi
		fi
		rm -rf /usr/local/gost
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}删除Gost文件夹成功。"
		else
			clear
			echo -e "${error_font}删除Gost文件夹失败！"
		fi
		echo -e "${error_font}Gost安装失败。"
		echo -e "\n${error_font}失败原因：${clear_install_reason}"
		echo -e "${info_font}如需获得更详细的报错信息，请在shell窗口中往上滑动。"
	fi
}

function os_update(){
	clear
	echo -e "正在更新系统组件中..."
	if [ "${System_OS}" == "CentOS" ]; then
		yum update -y
		if [[ $? -ne 0 ]]; then
			clear
			echo -e "${error_font}系统源更新失败！"
			exit 1
		else
			clear
			echo -e "${ok_font}系统源更新成功。"
		fi
		yum upgrade -y
		if [[ $? -ne 0 ]]; then
			clear
			echo -e "${error_font}系统组件更新失败！"
			exit 1
		else
			clear
			echo -e "${ok_font}系统组件更新成功。"
		fi
		if [ "${OS_Version}" -le "6" ]; then
			yum install -y wget curl unzip lsof daemon iptables ca-certificates
			if [[ $? -ne 0 ]]; then
				clear
				echo -e "${error_font}所需组件安装失败！"
				exit 1
			else
				clear
				echo -e "${ok_font}所需组件安装成功。"
			fi
		elif [ "${OS_Version}" -ge "7" ]; then
			yum install -y wget curl unzip lsof daemon firewalld ca-certificates
			if [[ $? -ne 0 ]]; then
				clear
				echo -e "${error_font}所需组件安装失败！"
				exit 1
			else
				clear
				echo -e "${ok_font}所需组件安装成功。"
			fi
			systemctl start firewalld
			if [[ $? -ne 0 ]]; then
				clear
				echo -e "${error_font}启动firewalld失败！"
				exit 1
			else
				clear
				echo -e "${ok_font}启动firewalld成功。"
			fi
		else
			clear
			echo -e "${error_font}目前暂不支持您使用的操作系统的版本号。"
			exit 1
		fi
	elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
		apt-get update -y
		if [[ $? -ne 0 ]]; then
			clear
			echo -e "${error_font}系统源更新失败！"
			exit 1
		else
			clear
			echo -e "${ok_font}系统源更新成功。"
		fi
		apt-get upgrade -y
		if [[ $? -ne 0 ]]; then
			clear
			echo -e "${error_font}系统组件更新失败！"
			exit 1
		else
			clear
			echo -e "${ok_font}系统组件更新成功。"
		fi
		apt-get install -y wget curl unzip lsof daemon iptables ca-certificates
		if [[ $? -ne 0 ]]; then
			clear
			echo -e "${error_font}所需组件安装失败！"
			exit 1
		else
			clear
			echo -e "${ok_font}所需组件安装成功。"
		fi
	fi
	clear
	echo -e "${ok_font}相关组件 安装/更新 完毕。"
}

function generate_base_config(){
	clear
	echo "正在生成基础信息中..."
	ip_address="$(curl -4 ip.sb)"
	if [ -z "${ip_address}" ]; then
		ip_address="$(curl -4 https://ipinfo.io/ip)"
	fi
	if [ -z "${ip_address}" ]; then
		clear
		echo -e "${warning_font}获取服务器公网IP失败，请手动输入服务器公网IP地址！"
		stty erase '^H' && read -r -p "请输入您服务器的公网IP地址：" ip_address
	fi
	if [[ -z "${ip_address}" ]]; then
		clear
		echo -e "${error_font}获取服务器公网IP地址失败，安装无法继续。"
		exit 1
	else
		clear
		echo -e "${ok_font}您的vps_ip为：${ip_address}"
	fi
}

function input_port(){
	clear
	stty erase '^H' && read -r -p "请输入监听端口(默认监听1080端口)：" install_port
	if [ -z "${install_port}" ]; then
		install_port="1080"
	fi
	check_port
	echo -e "${install_port}" > "/usr/local/gost/install_port.info"
	if [ "$?" -eq "0" ]; then
		clear
		echo -e "${ok_font}Gost端口配置成功。"
	else
		clear
		echo -e "${error_font}Gost端口配置失败！"
		clear_install_reason="Gost端口配置失败。"
		clear_install
		exit 1
	fi
}

function check_port(){
	clear
	echo -e "正在检测端口占用情况中..."
	if [[ 0 -eq "$(lsof -i:"${install_port}" | wc -l)" ]]; then
		clear
		echo -e "${ok_font}${install_port}端口未被占用"
		open_port
	else
		clear
		echo -e "${error_font}检测到${install_port}端口被占用，以下为端口占用信息："
		lsof -i:"${install_port}"
		stty erase '^H' && read -r -r -p "是否尝试强制终止该进程？[Y/n]" install_force
		case "${install_force}" in
		[nN][oO]|[nN])
			clear
			echo -e "${error_font}取消安装。"
			clear_install_reason="${install_port}端口被占用。"
			clear_install
			exit 1
			;;
		*)
			clear
			echo -e "正在尝试强制终止该进程..."
			if [ -n "$(lsof -i:"${install_port}" | awk '{print $1}' | grep -v "COMMAND" | grep "nginx")" ]; then
				service nginx stop
			fi
			if [ -n "$(lsof -i:"${install_port}" | awk '{print $1}' | grep -v "COMMAND" | grep "apache")" ]; then
				service apache stop
				service apache2 stop
			fi
			if [ -n "$(lsof -i:"${install_port}" | awk '{print $1}' | grep -v "COMMAND" | grep "caddy")" ]; then
				service caddy stop
			fi
			lsof -i:"${install_port}" | awk '{print $2}'| grep -v "PID" | xargs kill -9
			if [ "0" -eq "$(lsof -i:"${install_port}" | wc -l)" ]; then
				clear
				echo -e "${ok_font}强制终止进程成功，${install_port}端口已变为未占用状态。"
				open_port
			else
				clear
				echo -e "${error_font}尝试强制终止进程失败，${install_port}端口仍被占用！"
				clear_install_reason="尝试强制终止进程失败，${install_port}端口仍被占用。"
				clear_install
				exit 1
			fi
			;;
		esac
	fi
}

function open_port(){
	clear
	echo -e "正在设置防火墙中..."
	if [ "${System_OS}" == "CentOS" ] && [ "${OS_Version}" -ge "7" ]; then
		firewall-cmd --permanent --zone=public --add-port="${install_port}"/tcp
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 请求失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 请求失败。"
			clear_install
			exit 1
		fi
		firewall-cmd --complete-reload
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}重载firewalld规则成功。"
		else
			clear
			echo -e "${error_font}重载firewalld规则失败！"
			clear_install_reason="重载firewalld规则失败。"
			clear_install
			exit 1
		fi
		if [ "$(firewall-cmd --query-port="${install_port}"/tcp)" == "yes" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 失败。"
			clear_install
			exit 1
		fi
	elif [ "${System_OS}" == "CentOS" ] && [ "${OS_Version}" -le "6" ]; then
		service iptables save
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存当前iptables规则成功。"
		else
			clear
			echo -e "${warning_font}保存当前iptables规则失败！"
		fi
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport "${install_port}" -j ACCEPT
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 请求失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 请求失败。"
			clear_install
			exit 1
		fi
		service iptables save
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存iptables规则失败！"
			clear_install_reason="保存iptables规则失败。"
			clear_install
			exit 1
		fi
		service iptables restart
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}重启iptables成功。"
		else
			clear
			echo -e "${error_font}重启iptables失败！"
			clear_install_reason="重启iptables失败。"
			clear_install
			exit 1
		fi
		if [ -n "$(iptables -L -n | grep ACCEPT | grep tcp |grep "${install_port}")" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 失败。"
			clear_install
			exit 1
		fi
	elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
		iptables-save > /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存当前iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存当前iptables规则失败！"
			clear_install_reason="保存当前iptables规则失败。"
			clear_install
			exit 1
		fi
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}配置iptables启动规则成功。"
		else
			clear
			echo -e "${error_font}配置iptables启动规则失败！"
			clear_install_reason="配置iptables启动规则失败。"
			clear_install
			exit 1
		fi
		chmod +x /etc/network/if-pre-up.d/iptables
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}设置iptables启动文件执行权限成功。"
		else
			clear
			echo -e "${error_font}设置iptables启动文件执行权限失败！"
			clear_install_reason="设置iptables启动文件执行权限失败。"
			clear_install
			exit 1
		fi
		iptables-restore < /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}导入iptables规则成功。"
		else
			clear
			echo -e "${error_font}导入iptables规则失败！"
			clear_install_reason="导入iptables规则失败。"
			clear_install
			exit 1
		fi
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport "${install_port}" -j ACCEPT
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 请求失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 请求失败。"
			clear_install
			exit 1
		fi
		iptables-save > /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存iptables规则失败！"
			clear_install_reason="保存iptables规则失败。"
			clear_install
			exit 1
		fi
		if [ -n "$(iptables -L -n | grep ACCEPT | grep tcp |grep "${install_port}")" ]; then
			clear
			echo -e "${ok_font}开放 ${install_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}开放 ${install_port}端口tcp协议 失败！"
			clear_install_reason="开放 ${install_port}端口tcp协议 失败。"
			clear_install
			exit 1
		fi
	fi
	clear
	echo -e "${ok_font}防火墙配置完毕。"
}

function close_port(){
	clear
	echo -e "正在设置防火墙中..."
	if [ "${daemon_name}" == "systemd" ] && [ -f "/etc/systemd/system/gost.service" ]; then
		uninstall_port="$(grep -Eo "@\:[0-9]+" /usr/local/gost/socks5.json | sed "s/@://g")"
	elif [ "${daemon_name}" == "sysv" ] && [ -f "/etc/init.d/gost" ]; then
		uninstall_port="$(grep -Eo "@\:[0-9]+" /etc/init.d/gost | sed "s/@://g")"
	fi
	if [ -z "${uninstall_port}" ]; then
		uninstall_port="$(cat "/usr/local/gost/install_port.info")"
	fi
	if [ "${System_OS}" == "CentOS" ] && [ "${OS_Version}" -ge "7" ]; then
		firewall-cmd --permanent --zone=public --remove-port="${uninstall_port}"/tcp
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 请求失败！"
		fi
		firewall-cmd --complete-reload
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}重载firewalld规则成功。"
		else
			clear
			echo -e "${error_font}重载firewalld规则失败！"
		fi
		if [ "$(firewall-cmd --query-port="${uninstall_port}"/tcp)" == "no" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 失败！"
		fi
	elif [ "${System_OS}" == "CentOS" ] && [ "${OS_Version}" -le "6" ]; then
		service iptables save
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存当前iptables规则成功。"
		else
			clear
			echo -e "${warning_font}保存当前iptables规则失败！"
		fi
		iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport "${uninstall_port}" -j ACCEPT
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 请求失败！"
		fi
		service iptables save
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存iptables规则失败！"
		fi
		service iptables restart
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}重启iptables成功。"
		else
			clear
			echo -e "${error_font}重启iptables失败！"
		fi
		if [ -z "$(iptables -L -n | grep ACCEPT | grep tcp |grep "${uninstall_port}")" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 失败！"
		fi
	elif [ "${System_OS}" == "Debian" -o "${System_OS}" == "Ubuntu" ]; then
		iptables-save > /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存当前iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存当前iptables规则失败！"
			clear_install_reason="保存当前iptables规则失败。"
			clear_install
			exit 1
		fi
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}配置iptables启动规则成功。"
		else
			clear
			echo -e "${error_font}配置iptables启动规则失败！"
			clear_install_reason="配置iptables启动规则失败。"
			clear_install
			exit 1
		fi
		chmod +x /etc/network/if-pre-up.d/iptables
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}设置iptables启动文件执行权限成功。"
		else
			clear
			echo -e "${error_font}设置iptables启动文件执行权限失败！"
			clear_install_reason="设置iptables启动文件执行权限失败。"
			clear_install
			exit 1
		fi
		iptables-restore < /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}导入iptables规则成功。"
		else
			clear
			echo -e "${error_font}导入iptables规则失败！"
			clear_install_reason="导入iptables规则失败。"
			clear_install
			exit 1
		fi
		iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport "${uninstall_port}" -j ACCEPT
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 请求成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 请求失败！"
		fi
		iptables-save > /etc/iptables.up.rules
		if [ "$?" -eq "0" ]; then
			clear
			echo -e "${ok_font}保存iptables规则成功。"
		else
			clear
			echo -e "${error_font}保存iptables规则失败！"
		fi
		if [ -z "$(iptables -L -n | grep ACCEPT | grep tcp |grep "${uninstall_port}")" ]; then
			clear
			echo -e "${ok_font}关闭 ${uninstall_port}端口tcp协议 成功。"
		else
			clear
			echo -e "${error_font}关闭 ${uninstall_port}端口tcp协议 失败！"
		fi
	else
		clear
		echo -e "${error_font}目前暂不支持您使用的操作系统。"
	fi
	clear
	echo -e "${ok_font}防火墙配置完毕。"
}

function echo_gost_config(){
	if [ "${determine_type}" = "1" ]; then
		clear
		if [ -n "${connect_username}" ] && [ -n "${connect_password}" ]; then
			telegram_link="https://t.me/socks?server=${ip_address}&port=${install_port}&user=${connect_username}&pass=${connect_password}"
		else
			telegram_link="https://t.me/socks?server=${ip_address}&port=${install_port}"
		fi
		echo -e "您的连接信息如下："
		echo -e "服务器地址：${ip_address}"
		echo -e "端口：${install_port}"
		if [ -n "${connect_username}" ] && [ -n "${connect_password}" ]; then
			echo -e "用户名：${connect_username}"
			echo -e "密码：${connect_password}"
		fi
		echo -e "Telegram设置指令：${green_backgroundcolor}${telegram_link}${default_fontcolor}"
	fi
	echo -e "${telegram_link}" > /usr/local/gost/telegram_link.info
}

function main(){
	set_fonts_colors
	check_os
	check_install_status
	echo_install_list
}

	main
