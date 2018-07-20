#!/bin/bash

HOME=/home/paasadmin

#sudo iptables -t nat -F

#sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080

# start nginx function
rubystart() {
        cd $HOME/nginx/sbin/ && ./nginx
}

# stop nginx function
rubystop() {
#	pkill -9 Passenger
#	pkill -9 nginx
        
#	sudo ps aux |grep Passenger|awk '{print $2}' > $HOME/Passenger.pid
 #       head -3 $HOME/Passenger.pid >  $HOME/F.pid
  #      sudo ps aux |grep nginx|awk '{print $2}' > $HOME/nginx.pid
        #head -2 $HOME/nginx.pid >>  $HOME/F.pid
#        /usr/bin/tr '\n' ' ' < $HOME/F.pid > $HOME/P.pid
 #       pid=`cat $HOME/P.pid`
  #      sudo kill  $pid
   #     rm -rf /tmp/passenger*
#	rm -rf  $HOME/F.pid $HOME/P.pid $HOME/nginx.pid $HOME/Passenger.pid
	sudo pkill -9 Passenger
        sudo pkill -9 nginx
#	sudo /root/atr_set
}


case $1 in

cmd)		
		$2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27} ${28} ${29} ${30} 			${31} ${32} ${33} ${34} ${35} ${36} ${37} ${38} ${39} ${40} ${41} ${42} ${43} ${44} ${45} ${46} ${47} ${48} ${49} ${50} ${51}
		if [ $? -eq 0 ]; then
                        echo '{"code":5000,"success":"true", "message":"Command Successfully Executed"}'
                else
			echo '{"success":"false", "code":9401,"message":"Command Execution Failed"}'
                fi;;

# webserver start case
start)
	state=`sudo netstat -npl|grep nginx|grep 8080|grep -v worker|head -1|cut -d'/' -f1|rev|awk '{print $1}'|rev`
	echo "state=$state+1"
	if [ -n "$state" ]; then
		echo '{"code":5000,"success":"true", "message":"Nginx Already Started"}'
	else
#		/opt/log_rename
		rubystart
		if [ $? -eq 0 ]; then
			crontab -u paasadmin $HOME/cronjob
			echo '{"code":5000,"success":"true", "message":"Nginx Started Successfully"}'
     		else
			echo '{"success":"false","code":9402, "message":"Nginx Could Not Be Started"}'
		fi
    	fi;;

# webserver stop case
stop)
	state=`sudo netstat -npl|grep nginx|grep 8080|grep -v worker|head -1|cut -d'/' -f1|rev|awk '{print $1}'|rev`
        echo "state=$state+1"
	if [ -z "$state" ]; then
		echo '{"code":5000,"success":"true", "message":"Nginx Already Stopped"}'
	else
		crontab -r
		rubystop
		if [ $? -eq 0 ]; then
			echo '{"code":5000,"success":"true", "message":"Nginx Stopped Successfully"}'
		else
			echo '{"success":"false","code":9403, "message":"Nginx Could Not Be Stopped"}'
		fi
  	fi;;


# deploy and update application
deploy)
		depid=`cat $HOME/DepID`
                echo $2 > $HOME/url
                rgn=`cat $HOME/url|cut -d "/" -f1`
                if [ "$rgn" = "cdn.vmpath.com" ]; then
                        region=us-west-2
                else
                        region=us-east-1
                fi

                if [ ! -d $HOME/.aws/ ]; then
                        mkdir -p $HOME/.aws/
                fi

echo "[default]
output = json
region = $region
aws_access_key_id = xxxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxx" >$HOME/.aws/config
                # download application
                aws s3 cp s3://$2 $HOME/download/

		# download application
          #	wget --no-check-certificate --directory-prefix=$HOME/download $2
		if [ $? -eq 0 ]; then
			rm -rf $HOME/.aws/config $HOME/url
			state=`sudo netstat -npl|grep nginx|grep 8080|grep -v worker|head -1|cut -d'/' -f1|rev|awk '{print $1}'|rev`
		        echo "state=$state+1"
        		if [ -n "$state" ]; then
	               		rubystop 
				sudo pkill -9 Passenger
				sudo pkill -9 nginx
#				nm=`ps aux |grep nginx|grep master|awk '{print $2}'`
#				nw=`ps aux |grep nginx|grep worker|awk '{print $2}'`
#				kill -15 $nm $nw
				echo "nginx kill"
			else
		                echo "Nginx Already Started"
			fi
			if [ $? -eq 0 ]; then
                        	# backup existing application
				rm -rf $HOME/backup/*
				mkdir -p $HOME/backup/
				if [ -d $HOME/rubyapp/app ]; then
					mv  $HOME/rubyapp/app $HOME/backup/.
                else
					echo "dir not found"
                fi
				
				if [ $? -eq 0 ]; then
					# get download file name
					fileWithExt=${2##*/}
					echo "file=$fileWithExt"
					FileExt=${fileWithExt#*.}
					#d=`echo "$fileWithExt" | cut -d'.' -f1`
					d=$fileWithExt
					echo "file with ext =$d"
                        if [ "$FileExt" = "tar.gz" ] || [ "$FileExt" -eq "tar.gz" ]; then
							echo "file tar.gz ext true = $FileExt"
                        else
							f=`echo $FileExt | cut -d'.' -f2`
                            FileExt=$f
                            echo "file tar.gz ext false = $FileExt"
                        fi

                        echo "Archive Going to Extract = $FileExt"
                                       
                        # extract source
                        case $FileExt in
                                                
                        # extract tar.gz format
                        	tar.gz)
                                	tar xvzf $HOME/download/$fileWithExt -C $HOME/download/ > $HOME/fname
									rm $HOME/download/$fileWithExt
                                    count=`ls -l $HOME/download/|wc -l`
                                    if [ $count = 2 ]; then
										f=`head -1 $HOME/fname|cut -d'/' -f1`
                                        if [ -d $HOME/download/$f ]; then
											d=$f
										else
											cd $HOME/download/ && mv "$f" "${f// /_}" && rm $HOME/download/*.tar.gz
											d=`ls $HOME/download |awk '{ print $1 }'|head -1`
										fi
                                    else
										mkdir -p $HOME/download/$USER
                                        mv $HOME/download/* $HOME/download/$USER/ 2> /dev/null
                                        d=$USER
									fi
									echo "fname=$d";;
                                                
			# extract gzip format
                        	gz)
                                	gunzip $HOME/download/$fileWithExt
                                        f=`ls $HOME/download`
                                        if [ -f $HOME/download/$f ]; then
						d=$f
                                     	else
						cd $HOME/download/ && mv "$f" "${f// /_}" && rm $HOME/download/*.gz
                                                d=`ls $HOME/download`
                                        fi
					echo "fname=$d";;
                                        
                   	# extract zip format
                        	zip)
                                	unzip $HOME/download/$fileWithExt -d $HOME/download/ > $HOME/fname
					rm $HOME/download/$fileWithExt
                                        count=`ls -l $HOME/download/|wc -l`
                                        if [ $count = 2 ]; then
                                                f=`egrep "(inflating|creating)" $HOME/fname |head -2 |cut -d'/' -f5|head -1`
                                                if [ -d $HOME/download/$f ]; then
                                                        d=$f
                                                else
                                                        cd $HOME/download/ && mv "$f" "${f// /_}" && rm $HOME/download/*.zip
                                                        d=`ls $HOME/download |awk '{ print $1 }'|head -1`
                                                fi
                                        else
                                                mkdir -p $HOME/download/$USER
                                                mv $HOME/download/* $HOME/download/$USER/ 2> /dev/null
                                                d=$USER
                                        fi
                                        echo "fname=$d";;
                                        
			esac

					# move source to workspace folder
					if [ -d $HOME/download/$d ]; then	
						mv $HOME/download/$d $HOME/rubyapp/app
#						ln -sf $HOME/rubyapp/rails_logger/public $HOME/rubyapp/app/$depid
						rm -rf $HOME/rubyapp/app/log
						ln -sf $HOME/log $HOME/rubyapp/app/log
					else
						mkdir -p $HOME/rubyapp/app
						mv $HOME/download/$d $HOME/rubyapp/app
#                                               ln -sf $HOME/rubyapp/rails_logger/public $HOME/rubyapp/app/$depid
                                                rm -rf $HOME/rubyapp/app/log
                                                ln -sf $HOME/log $HOME/rubyapp/app/log
					fi
					
					if [ -f $HOME/rubyapp/app/config/database.yml ]; then
  						cd $HOME/rubyapp/app/ && sudo  /usr/local/bin/bundle install --without development:test 2>> $HOME/rubyapp/app/log/production.log
						rake assets:clean 2>> $HOME/rubyapp/app/log/production.log
						rake assets:precompile RAILS_ENV=production 2>> $HOME/rubyapp/app/log/production.log
						rake db:create RAILS_ENV=production 2>> $HOME/rubyapp/app/log/production.log
						rake db:migrate RAILS_ENV=production 2>> $HOME/rubyapp/app/log/production.log
						rake db:seed RAILS_ENV=production 2>> $HOME/rubyapp/app/log/production.log
						sudo chown -R 1001.1001 $HOME/rubyapp/app
					else
						cd $HOME/rubyapp/app && sudo /usr/local/bin/bundle install --without development:test 2>> $HOME/rubyapp/app/log/production.log
						rake assets:clean 2>> $HOME/rubyapp/app/log/production.log
						rake assets:precompile RAILS_ENV=production 2>> $HOME/rubyapp/app/log/production.log
						sudo chown -R 1001.1001 $HOME/rubyapp/app
					fi					
					if [ $? -eq 0 ]; then
						rubystart	
						sleep 20
						state=`sudo netstat -npl|grep nginx|grep 8080|grep -v worker|head -1|cut -d'/' -f1|rev|awk '{print $1}'|rev`
                        			echo "state=$state+1"
			                        if [ -n "$state" ]; then	
#						cd $HOME
							# remove downloaded and backup file
							rm -rf $HOME/download
							rm -rf $HOME/backup/app*
							rm -rf $HOME/fname
							echo '{"code":5000,"success":"true", "message":"Ruby App Deployed Successfully"}'	
										

#############################################
					######### ------------######################
						else
							rubystop
                                                        sudo pkill -9 nginx
							sudo pkill -9 Passenger
                                                        sleep 10
                                                        rubystart
                                                        sleep 20
							state=`sudo netstat -npl|grep nginx|grep 8080|grep -v worker|head -1|cut -d'/' -f1|rev|awk '{print $1}'|rev`
        	                                        echo "state=$state+1"
	                                                if [ -n "$state" ]; then
                                	                        # remove downloaded and backup file
                        	                                rm -rf $HOME/download
                	                                        rm -rf $HOME/backup/app*
        	                                                rm -rf $HOME/fname
	                                                        echo '{"code":5000,"success":"true", "message":"Ruby App Deployed Successfully"}'
							else
								rm -rf $HOME/rubyapp/app*
			                                        mv $HOME/backup/app $HOME/rubyapp/
                        			                rm -rf $HOME/rubyapp/app/log
			                                        ln -sf $HOME/log $HOME/rubyapp/app/log
								rubystop
                	                                        sudo pkill -9 nginx
        	                                                sudo pkill -9 Passenger
	                                                        sleep 10
                                                		rubystart
                        			                rm -rf $HOME/backup/app*
			                                        rm -rf $HOME/download
        	                                                rm -rf $HOME/fname
								echo '{"success":"false","code":9404, "message":"Nginx Could Not Be Started With New Ruby App, Deployment Failed"}'
								exit 1
							fi
                                        	fi

					
					else
						# remove apps contents, coping app data from backup, start webserver & remove downloaded and backup file
						rm -rf $HOME/rubyapp/app*
						mv $HOME/backup/app $HOME/rubyapp/
#						ln -sf $HOME/rubyapp/rails_logger/public $HOME/rubyapp/app/$depid
						rm -rf $HOME/rubyapp/app/log
                                         	ln -sf $HOME/log $HOME/rubyapp/app/log
						rubystart
						rm -rf $HOME/backup/app*
						rm -rf $HOME/download
						rm -rf $HOME/fname
						echo '{"success":"false","code":9405, "message":"Ruby App Deployment Failed"}'
					fi 

				else
					rubystart
					# remove downloaded file
					rm -rf $HOME/download
					echo '{"success":"false","code":9406, "message":"Ruby App Contents For Backup Could Not Be Moved"}'
					exit 1
				fi
			else
				rubystart
				# remove downloaded file
				rm -rf $HOME/download
				echo '{"success":"false","code":9407, "message":"Nginx Could Not Be Stopped"}'
	       	        	exit 1
			fi
		else

			# remove downloaded file
			rm -rf $HOME/download
			rm -rf $HOME/.aws/config $HOME/url
			echo '{"success":"false","code":9408, "message":"Ruby App Download Failed"}'
			exit 1
	fi;;

createkey)

                if [ ! -d $HOME/sshkey ]; then
                        mkdir -p $HOME/sshkey
                fi

                /usr/bin/ssh-keygen -t rsa -f $HOME/sshkey/paasuser -N ""
                sudo /sbin/katr sheppaasuserkey
                mv $HOME/sshkey/paasuser $HOME/sshkey/paasuser.pem
                rm $HOME/sshkey/paasuser.pub

                if [ ! -z /home/paasuser/.ssh/authorized_keys ]; then
                         echo '{"code":5000,"success":"true","message":"PaaSUser SSH key Created","path":"'$HOME/sshkey/paasuser.pem'"}'
                else
                        echo '{"success":"false","code":9409,"message":"PaaSUser SSH key Could Not Be Created"}'
                fi;;

setup)
		logval=`grep "tomcat" /etc/apache2/sites-available/default|tail -1|cut -d"/" -f5|cut -d">" -f1`
		if [ "$logval" = "tomcat" ]; then
			sudo sed -i 's/'tomcat'/'$2'/g' /etc/apache2/sites-available/default
	        	ln -sf $HOME/log $HOME/logging/$2        
			echo "$2" > $HOME/DepID
        	        sudo /sbin/katr sheppaasuseratr
			if [ -L $HOME/logging/$2 ]; then
				sudo /etc/init.d/apache2 restart
				rubystart
				crontab -u paasadmin $HOME/cronjob

                	        echo '{"code":5000,"success":"true","message":"LOG Link Created, Setup is Successfully"}'
	                else
        	                echo '{"success":"false","code":9410,"message":"LOG Link Could Not Be Create, Setup is Failed"}'
                	fi
		else
			echo '{"success":"false","code":9411,"message":"LOG Value Could Not Be Match in Apache Server, Setup is Failed"}'
		fi;;

addcronjob)
        	crontab -u paasadmin $HOME/cronjob
	        if [ $? -eq 0 ]; then
        	        echo '{"code":5000,"success":"true","message":"CronJob Added Successfully"}'
	        else
        	        echo '{"success":"false","code":9412,"message":"CronJob Could Not Be Added"}'
	        fi;;

deletecronjob)
        	crontab -r
	        if [ $? -eq 0 ]; then
        	        echo '{"code":5000,"success":"true","message":"CronJob Deleted Successfully"}'
	        else
        	        echo '{"success":"false","code":9413,"message":"CronJob Could Not Be Deleted"}'
	        fi;;

usages)
                mem=`free -m |grep "Mem"|awk '{print $3}'`
                cpu=`top -bn1 |grep "Cpu"|awk '{print $2}'|cut -d"%" -f1`
                echo '{"code":5000,"success":"true","message":"Current Resorce Usages In '$containername'","memory":"'$mem'","cpu":"'$cpu'"}'
                ;;	

reset_htpasswd)
                htpasswd -bc $HOME/htpasswd $2 $3
                if [ $? -eq 0 ]; then
                        echo '{"code":5000,"success":"true","message":"Http Auth Reset Successfully"}'
                else
                        echo '{"success":"false","code":9313,"message":"Http Auth Not Be Reset"}'
                fi;;


*)
                echo 'Usage: {cmd|start|stop|deploy}'
                echo '{"success":"false", "code":9414,"message":"Invalid Command"}'
                ;;

esac
