#!/bin/bash

date

subscription_id="$1"
setupName="$2"
location="$3"
proxy1vm_size="$4"
proxy2vm_size="$5"
postgresql_master_vm_size="$6"
postgresql_slave_vm_size="$7"
postgresql_user_name="$8"
postgresql_databse_name="$9"
storagetype="${10}"
disksize="${11}"
region="$location"
postgresql_conn="${12}"
allow_ip="${13}"
sub="$subscription_id"
#mysql_version="${14}"


if [ -z $storagetype ] || [ $storagetype == null ]; then
        storagetype="LRS"
fi

if [ -z $disksize ] || [ $disksize == null ]; then
        disksize="100"
fi

if [ -z $postgresql_conn ] || [ $postgresql_conn == null ]; then
        postgresql_conn="150"
fi

if [ -z $allow_ip ] || [ $allow_ip == null ]; then
        allow_ip="0.0.0.0/0"
fi


#if [ -z $mysql_version ] || [ $mysql_version == null ]; then
#        mysql_version="5.6.*"
#fi



echo -e "\nsetupName = $setupName\nlocation = $region\nproxy1vm_size = $proxy1vm_size\nproxy2vm_size = proxy2vm_size\npostgresqll_master_vm_size = $postgresql_master_vm_size\npostgresql_slave_vm_size = $postgresql_slave_vm_size\npostgresql_user_name = $postgresql_user_name\npostgresql_databse_name = $postgresql_databse_name\nstoragetype = $storagetype\ndisksize = $disksize\n"
#mysql_version = $mysql_version\n"

user_password=`openssl rand -base64 10`

#echo "Setup Name = $setupName"
#echo "Region = $region"
#echo "VM Size = $size"
db_url=`date | md5sum|cut -c1-5`

rm -rf ~/.azure/azureProfile.json

azure login -u abc@example.com -p 123456 <<EOF
y
EOF
if [ $? -eq 0 ]; then
        echo -e "\nAzure Login Successfully \n"
else
        echo '{"success":"false","code":3001,"message":"Azure Login Failed"}'
        exit 1
fi
azure config mode arm
if [ $? -eq 0 ]; then
        echo -e "\nAzure Change Mode ARM Successfully \n"
else
        echo '{"success":"false","code":3001,"message":"Azure Change Mode ARM Failed Failed"}'
        exit 1
fi

azure account set $subscription_id
if [ $? -eq 0 ]; then
        echo -e "\nAzure Set Subscription Successfully \n"
else
        echo '{"success":"false","code":3001,"message":"Azure Set Subscription Failed"}'
        exit 1
fi



#img=`azure vm image list -l $region -p Canonical |grep "14.04.5-LTS"|grep "2016"|sort -r|head -1|awk '{print $8}'`
img=`azure vm image list -l $region -p openlogic|grep "CentOS:6.5"|grep "2016"|awk '{print $8}'`
if [ -z $img ]; then
        echo '{"success":"false","code":3001,"message":"Ubuntu 14.04 LTS 2017 Release Not Found In '$region' Region"}'
        exit 1
fi
echo -e "\n$img\n"

lowercase_setupname=`echo $setupName |tr '[A-Z]' '[a-z]'`
storage_name="$lowercase_setupname$db_url"

resourcegroup="${setupName}rg"

rgremove() {
azure group delete -n $resourcegroup <<EOF
y
EOF
}

echo -e "\nCreating Resource Group\n"

azure group create -n $resourcegroup -l $region
if [ $? -eq 0 ]; then
        echo -e "\nResource Group Created\n"
else
        echo '{"success":"false","code":3001,"message":"Resource Creation Failed"}'
        exit 1
fi

echo -e "\nCreating Storage Account\n"

azure storage account create -g $resourcegroup -l $region --kind Storage --sku-name $storagetype $storage_name
if [ $? -eq 0 ]; then
        storage_key=`azure storage account keys list -g $resourcegroup $storage_name|grep key1|awk '{print $3}'`
        if [ $? -eq 0 ]; then
                                azure storage container create --container vhds -a $storage_name -k $storage_key
                if [ $? -eq 0 ]; then
                                azure storage container create --container backup -a $storage_name -k $storage_key
                        echo -e "\nStorage Account Created\n"
                else
                        echo '{"success":"false","code":3001,"message":"Container Creation Failed"}'
                        rgremove
                        exit 1
                fi
        else
               	echo '{"success":"false","code":3001,"message":"Storage Account Key Cannot Fetch"}'
                rgremove
                exit 1
        fi
else
        echo '{"success":"false","code":3001,"message":"Storage Account Creation Failed"}'
        rgremove
        exit 1
fi

echo -e "\nCreating Virtual Network\n"

azure network vnet create -g $resourcegroup -l $region -n $setupName-vnet -a 10.20.1.0/24
if [ $? -eq 0 ]; then
        azure network vnet subnet create -g $resourcegroup -e $setupName-vnet -n $setupName-subnet -a 10.20.1.0/25
        if [ $? -eq 0 ]; then
                echo -e "\nVirtual Network Created\n"
		else
			echo '{"success":"false","code":3001,"message":"Subnet Creation Failed"}'
			rgremove
			exit 1
		fi
else
	echo '{"success":"false","code":3001,"message":"Virtual Network Creation Failed"}'
    rgremove
    exit 1
fi


echo -e "\nCreating Public IP's\n"

azure network public-ip create -g $resourcegroup -l $region -n ${setupName}p1  -d ${lowercase_setupname}p1 -a static -i 4
if [ $? -eq 0 ]; then
        echo -e "\nPublic IP For $setupName-proxyha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Public IP For '$setupName'-proxyha1 Creation Failed"}'
        rgremove
        exit 1
fi
azure network public-ip create -g $resourcegroup -l $region -n ${setupName}p2  -d ${lowercase_setupname}p2 -a static -i 4
if [ $? -eq 0 ]; then
        echo -e "\nPublic IP For $setupName-proxyha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Public IP For '$setupName'-proxyha2 Creation Failed"}'
        rgremove
        exit 1
fi
azure network public-ip create -g $resourcegroup -l $region -n ${setupName}postgres1  -d ${lowercase_setupname}postgres1 -a static -i 4
if [ $? -eq 0 ]; then
        echo -e "\nPublic IP For $setupName-postgresqlha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Public IP For '$setupName'-postgresqlha1 Creation Failed"}'
        rgremove
        exit 1
fi
azure network public-ip create -g $resourcegroup -l $region -n ${setupName}postgres2 -d ${lowercase_setupname}postgres2 -a static -i 4
if [ $? -eq 0 ]; then
        echo -e "\nPublic IP For $setupName-postgresqlha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Public IP For '$setupName'-postgresqlha2 Creation Failed"}'
        rgremove
        exit 1
fi
azure network public-ip create -g $resourcegroup -l $region -n ${setupName}proxylb  -d ${lowercase_setupname}${db_url} -a static -i 4
if [ $? -eq 0 ]; then
        echo -e "\nPublic IP For $setupName-proxylb Created\n"
else
        echo '{"success":"false","code":3001,"message":"Public IP For '$setupName'-proxylb Creation Failed"}'
        rgremove
        exit 1
fi


echo -e "\nCreating LoadBalancer\n"

azure network lb create -g $resourcegroup -l $region -n $setupName-lb
if [ $? -eq 0 ]; then
        azure network lb frontend-ip create -g $resourcegroup -l $setupName-lb -i ${setupName}proxylb -n $setupName-FrontEndPool
        if [ $? -eq 0 ]; then
                azure network lb address-pool create -g $resourcegroup -l $setupName-lb   -n $setupName-BackEndPool
                if [ $? -eq 0 ]; then
                        azure network lb rule create -g $resourcegroup -l $setupName-lb -n $setupName-LoadBalancerRulePostgreSql -p tcp -f 5432 -b 5432   -t $setupName-FrontEndPool -o $setupName-BackEndPool
                        if [ $? -eq 0 ]; then
                                azure network lb probe create -g $resourcegroup -l $setupName-lb -n $setupName-HealthProbe -p "tcp" -i 15 -c 4
                                if [ $? -eq 0 ]; then
                                        echo -e "\nLoadBalancer Created\n"
                                else
                                        echo '{"success":"false","code":3001,"message":"LoadBalancer HealthProbe Creation Failed"}'
                                        rgremove
                                        exit 1
                                fi
                        else
                                echo '{"success":"false","code":3001,"message":"LoadBalancer LoadBalancerRulePostgreSql Creation Failed"}'
								rgremove
                                exit 1
                        fi
                else
                        echo '{"success":"false","code":3001,"message":"LoadBalancer BackEndPool Creation Failed"}'
						rgremove
                        exit 1
                fi
        else
                echo '{"success":"false","code":3001,"message":"LoadBalancer FrontEndPool Creation Failed"}'
		rgremove
                exit 1
        fi
else
        echo '{"success":"false","code":3001,"message":"LoadBalancer Creation Failed"}'
	rgremove
        exit 1
fi

echo -e "\nCreating NIC\n"

azure network nic create -g $resourcegroup -l $region -a 10.20.1.5  --public-ip-name ${setupName}p1 -n $setupName-proxyha1Nic -m $setupName-vnet -k $setupName-subnet -d "/subscriptions/$sub/resourceGroups/$resourcegroup/providers/Microsoft.Network/loadBalancers/$setupName-lb/backendAddressPools/$setupName-BackEndPool"
if [ $? -eq 0 ]; then
        echo -e "\nNIC For $setupName-proxyha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"NIC For '$setupName'-proxyha1 Creation Failed"}'
		rgremove
        exit 1
fi

azure network nic create -g $resourcegroup -l $region -a 10.20.1.6  --public-ip-name ${setupName}p2 -n $setupName-proxyha2Nic -m $setupName-vnet -k $setupName-subnet -d "/subscriptions/$sub/resourceGroups/$resourcegroup/providers/Microsoft.Network/loadBalancers/$setupName-lb/backendAddressPools/$setupName-BackEndPool"
if [ $? -eq 0 ]; then
        echo -e "\nNIC For $setupName-proxyha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"NIC For '$setupName'-proxyha2 Creation Failed"}'
	rgremove
        exit 1
fi

azure network nic create -g $resourcegroup -l $region -a 10.20.1.7  --public-ip-name ${setupName}postgres1 -n $setupName-postgresqlha1Nic -m $setupName-vnet -k $setupName-subnet
if [ $? -eq 0 ]; then
        echo -e "\nNIC For $setupName-postgressqlha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"NIC For '$setupName'-postgresha1 Creation Failed"}'
		rgremove
        exit 1
fi

azure network nic create -g $resourcegroup -l $region -a 10.20.1.8  --public-ip-name ${setupName}postgres2 -n $setupName-postgresqlha2Nic -m $setupName-vnet -k $setupName-subnet
if [ $? -eq 0 ]; then
        echo -e "\nNIC For $setupName-postgressqlha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"NIC For '$setupName'-postgresha2 Creation Failed"}'
		rgremove
        exit 1
fi

echo -e "\nCreating NSG\n"

azure network nsg create -g $resourcegroup -l $region -n $setupName-proxyhansg
if [ $? -eq 0 ]; then
        azure network nsg rule create -p tcp -r inbound -y 1000 -u 22 -c allow   -g $resourcegroup -a $setupName-proxyhansg -n $setupName-ProxynsgRuleSSH
        if [ $? -eq 0 ]; then
		counter=1010
		rule_no=1
		for ip in $allow_ip
		do
                azure network nsg rule create -p tcp -r inbound -y $counter -u 5432 -c allow   -g $resourcegroup -a $setupName-proxyhansg -n $setupName-ProxynsgRulePostgreSql-$rule_no -f $ip
		if [ $? -eq 0 ]; then
			echo "$setupName-ProxynsgRulePostgreSql-$rule_no $counter $ip," >> /tmp/$setupName-proxyhansg
			counter=$((counter+10))
			rule_no=$((rule_no+1))
		else
			echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-proxyha Rule Postgresql Could Not Be Create"}'
			rgremove
			exit 1
		fi
		done
                if [ $? -eq 0 ]; then
			nsg_rule=`cat /tmp/$setupName-proxyhansg|tr '\n' ' '`
                        echo -e "\nNSG For $setupName-proxyha Created\n"
                else
                        echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-proxyha Rule Postgresql Could Not Be Create"}'
						rgremove
                        exit 1
                fi
        else
                echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-proxyha Rule SSH Could Not Be Create"}'
				rgremove
                exit 1
        fi
else
        echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-proxyha Could Not Be Create"}'
		rgremove
        exit 1
fi

azure network nsg create -g $resourcegroup -l $region -n $setupName-postgresqlhansg
if [ $? -eq 0 ]; then
        azure network nsg rule create -p tcp -r inbound -y 1000 -u 22 -c allow   -g $resourcegroup -a $setupName-postgresqlhansg -n $setupName-PostgresqlnsgRuleSSH
        if [ $? -eq 0 ]; then
                echo -e "\nNSG For $setupName-postgresqlha Created\n"
        else
                echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-postgresqlha Rule SSH Could Not Be Create"}'
				rgremove
                exit 1
        fi
else
        echo '{"success":"false","code":3001,"message":"NSG For '$setupName'-postgresqlha Could Not Be Create"}'
		rgremove
        exit 1
fi

echo -e "\nAttaching NSG To NIC\n"

azure network nic set -g $resourcegroup -o $setupName-proxyhansg -n $setupName-proxyha1Nic
if [ $? -eq 0 ]; then
        echo -e "\nNSG Attached to NIC $setupName-proxyha1Nic Created\n"
else
        echo '{"success":"false","code":3001,"message":"NSG Attached to NIC '$setupName'-proxyha1Nic Failed"}'
		rgremove
        exit 1
fi
azure network nic set -g $resourcegroup -o $setupName-proxyhansg -n $setupName-proxyha2Nic
if [ $? -eq 0 ]; then
        echo -e "\nNSG Attached to NIC $setupName-proxyha2Nic Created\n"
else
        echo '{"success":"false","code":3001,"message":"NSG Attached to NIC '$setupName'-proxyha2Nic Failed"}'
	rgremove
        exit 1
fi
azure network nic set -g $resourcegroup -o $setupName-postgresqlhansg -n $setupName-postgresqlha1Nic
if [ $? -eq 0 ]; then
        echo -e "\nNSG Attached to NIC $setupName-postgresqlha1Nic Created\n"
else
        echo '{"success":"false","code":3001,"message":"NSG Attached to NIC '$setupName'-postgresqlha1Nic Failed"}'
		rgremove
        exit 1
fi
azure network nic set -g $resourcegroup -o $setupName-postgresqlhansg -n $setupName-postgresqlha2Nic
if [ $? -eq 0 ]; then
        echo -e "\nNSG Attached to NIC $setupName-postgresqlha2Nic Created\n"
else
        echo '{"success":"false","code":3001,"message":"NSG Attached to NIC '$setupName'-postgresqlha2Nic Failed"}'
		rgremove
        exit 1
fi

echo -e "\nCreating AvailabilitySet\n"

azure availset create -g $resourcegroup -l $region -n $setupName-pAvSet
if [ $? -eq 0 ]; then
        echo -e "\nAvailabilitySet $setupName-proxyhaAvSet Created\n"
else
        echo '{"success":"false","code":3001,"message":"AvailabilitySet '$setupName'-proxyhaAvSet Creation Failed"}'
	rgremove
        exit 1
fi
azure availset create -g $resourcegroup -l $region -n $setupName-postgresAvSet
if [ $? -eq 0 ]; then
        echo -e "\nAvailabilitySet $setupName-postgresqlhaAvSet Created\n"
else
        echo '{"success":"false","code":3001,"message":"AvailabilitySet '$setupName'-postgresqlhaAvSet Creation Failed"}'
		rgremove
        exit 1
fi

echo -e "\nCreating Virtual Machine\n"

azure vm create --resource-group $resourcegroup --name $setupName-proxyha1 --location $region --os-type linux --availset-name $setupName-pAvSet --nic-name $setupName-proxyha1Nic --vnet-name $setupName-vnet --vnet-subnet-name $setupName-subnet --storage-account-name $storage_name --image-urn $img --ssh-publickey-file /var/keys/app42rds_key.pub --admin-username azureuser  --vm-size $proxy1vm_size --disable-boot-diagnostics
if [ $? -eq 0 ]; then
        echo -e "\nVirtual Machine $setupName-proxyha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Virtual Machine '$setupName'-proxyha1 Creation Failed"}'
		rgremove
        exit 1
fi

azure vm create --resource-group $resourcegroup --name $setupName-proxyha2 --location $region --os-type linux --availset-name $setupName-pAvSet --nic-name $setupName-proxyha2Nic --vnet-name $setupName-vnet --vnet-subnet-name $setupName-subnet --storage-account-name $storage_name --image-urn $img --ssh-publickey-file /var/keys/app42rds_key.pub --admin-username azureuser  --vm-size $proxy2vm_size --disable-boot-diagnostics
if [ $? -eq 0 ]; then
        echo -e "\nVirtual Machine $setupName-proxyha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Virtual Machine '$setupName'-proxyha2 Creation Failed"}'
	rgremove
        exit 1
fi

azure vm create --resource-group $resourcegroup --name $setupName-postgresqlha1 --location $region --os-type linux --availset-name $setupName-postgresAvSet --nic-name $setupName-postgresqlha1Nic --vnet-name $setupName-vnet --vnet-subnet-name $setupName-subnet --storage-account-name $storage_name --image-urn $img --ssh-publickey-file /var/keys/app42rds_key.pub --admin-username azureuser  --vm-size $postgresql_master_vm_size --disable-boot-diagnostics
if [ $? -eq 0 ]; then
        echo -e "\nVirtual Machine $setupName-postgresqlha1 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Virtual Machine '$setupName'-postgresqlha1 Creation Failed"}'
	rgremove
        exit 1
fi

azure vm create --resource-group $resourcegroup --name $setupName-postgresqlha2 --location $region --os-type linux --availset-name $setupName-postgresAvSet --nic-name $setupName-postgresqlha2Nic --vnet-name $setupName-vnet --vnet-subnet-name $setupName-subnet --storage-account-name $storage_name --image-urn $img --ssh-publickey-file /var/keys/app42rds_key.pub --admin-username azureuser  --vm-size $postgresql_slave_vm_size --disable-boot-diagnostics
if [ $? -eq 0 ]; then
        echo -e "\nVirtual Machine $setupName-postgresqlha2 Created\n"
else
        echo '{"success":"false","code":3001,"message":"Virtual Machine '$setupName'-postgresqlha2 Creation Failed"}'
	rgremove
        exit 1
fi

echo -e "\nAttaching Empty Data Disk For Postgresql\n"

#echo "azure vm disk attach-new -g $resourcegroup -n $setupName-postgresqlha1 -z $disksize -d $setupName-postgresqlha1disk1 -c ReadWrite -o $storage_name -r vhds"

azure vm disk attach-new -g $resourcegroup -n $setupName-postgresqlha1 -z $disksize -d $setupName-postgresqlha1disk1 -c ReadWrite -o $storage_name -r vhds
if [ $? -eq 0 ]; then
        echo -e "\nData Disk On $setupName-postgresqlha1 Attached\n"
else
        echo '{"success":"false","code":3001,"message":"Data Disk On '$setupName'-postgresqlha1 Could Not Be Attach"}'
		rgremove
        exit 1
fi

echo "azure vm disk attach-new -g $resourcegroup -n $setupName-postgresqlha2 -z $disksize -d $setupName-postgresqlha2disk1 -c ReadWrite -o $storage_name -r vhds"
azure vm disk attach-new -g $resourcegroup -n $setupName-postgresqlha2 -z $disksize -d $setupName-postgresqlha2disk1 -c ReadWrite -o $storage_name -r vhds
if [ $? -eq 0 ]; then
        echo -e "\nData Disk On $setupName-postgresqlha2 Attached\n"
else
        echo '{"success":"false","code":3001,"message":"Data Disk On '$setupName'-postgresqlha2 Could Not Be Attach"}'
		rgremove
        exit 1
fi

proxyha1=`azure network public-ip show -g $resourcegroup -n ${setupName}p1|grep "IP Address"|rev|awk '{print $1}'|rev`
proxyha2=`azure network public-ip show -g $resourcegroup -n ${setupName}p2|grep "IP Address"|rev|awk '{print $1}'|rev`
postgresqlha1=`azure network public-ip show -g $resourcegroup -n ${setupName}postgres1|grep "IP Address"|rev|awk '{print $1}'|rev`
postgresqlha2=`azure network public-ip show -g $resourcegroup -n ${setupName}postgres2|grep "IP Address"|rev|awk '{print $1}'|rev`
proxylb=`azure network public-ip show -g $resourcegroup -n ${setupName}proxylb|grep "IP Address"|rev|awk '{print $1}'|rev`

echo "/app42RDS/sbin/Installation_Arm_Postgres $proxyha1 $proxyha2 $postgresqlha1 $postgresqlha2 $postgresql_conn $setupName"
/app42RDS/sbin/Installation_Arm_Postgres $proxyha1 $proxyha2 $postgresqlha1 $postgresqlha2 $postgresql_conn $setupName
if [ $? -eq 0 ]; then
        echo -e "\nSetup Installation Completed\n"
else
        echo '{"success":"false","code":3001,"message":"Setup Installation Failed"}'
	rgremove
        exit 1
fi

echo "/app42RDS/sbin/Configuare_Arm_Postgres $proxyha1 $proxyha2 $postgresqlha1 $postgresqlha2 $postgresql_databse_name $postgresql_user_name "$user_password" $setupName $postgresql_conn"
/app42RDS/sbin/Configuare_Arm_Postgres $proxyha1 $proxyha2 $postgresqlha1 $postgresqlha2 $postgresql_databse_name $postgresql_user_name "$user_password" $setupName $postgresql_conn
if [ $? -eq 0 ]; then
        echo -e "\nSetup Configuration Completed\n"
else
        echo '{"success":"false","code":3001,"message":"Setup Configuration Failed"}'
	rgremove
        exit 1
fi

echo -e "\nProxyHA1 = $proxyha1\nProxyHA2 = $proxyha2\nPostgresqlHA1 = $postgresqlha1\nPostgresqlHA2 = $postgresqlha2\n"

echo -e "\n==============================================================\n"
echo -e "\nDB Url = $proxylb \nDatabase Name = $postgresql_databse_name \nUser Name = $postgresql_user_name \nPassword = "$user_password" \n"
echo -e "\nSetup created successefully. Thank You for choosing App42 PostgreSQL HA Solution\n"
echo -e "\n==============================================================\n"

date

#/bin/echo '{"code":5000,"success":"true", "message":"App42RDS Setup Completed Successfully", "subscription_id":"'$subscription_id'", "resource_group":"'$resourcegroup'", "region":"'$region'", "setup_ip":"'$proxylb'", "nodes":[{"pub_ip":"'$proxyha1'", "private_ip":"10.20.1.5", "type":"proxy1", "name":"'$setupName'-proxyha1"}, {"pub_ip":"'$proxyha2'", "private_ip":"10.20.1.6", "type":"proxy2", "name":"'$setupName'-proxyha2"}, {"pub_ip":"'$postgresqlha1'", "private_ip":"10.20.1.7", "type":"master", "name":"'$setupName'-postgresqlha1"}, {"pub_ip":"'$postgresqlha2'", "private_ip":"10.20.1.8", "type":"slave", "name":"'$setupName'-postgresqlha2"}], "setupConfig":{"postgresql_user_name":"'$postgresql_user_name'", "postgresql_password":"'$user_password'", "postgresql_database":"'$postgresql_databse_name'"}}'

#/bin/echo '{"code":5000,"success":"true", "message":"App42RDS Setup Completed Successfully", "subscription_id":"'$subscription_id'", "resource_group":"'$resourcegroup'", "region":"'$region'", "storage_account":"'$storage_name'", "storage_account_key":"'$storage_key'", "setup_ip":"'$proxylb'", "nodes":[{"pub_ip":"'$proxyha1'", "private_ip":"10.20.1.5", "type":"proxy1", "name":"'$setupName'-proxyha1"}, {"pub_ip":"'$proxyha2'", "private_ip":"10.20.1.6", "type":"proxy2", "name":"'$setupName'-proxyha2"}, {"pub_ip":"'$postgresqlha1'", "private_ip":"10.20.1.7", "type":"master", "name":"'$setupName'-postgresqlha1", "data_disk":"'$setupName'-postgresqlha1disk1"}, {"pub_ip":"'$postgresqlha2'", "private_ip":"10.20.1.8", "type":"slave", "name":"'$setupName'-postgresqlha2", "data_disk":"'$setupName'-postgresqlha2disk1"}], "setupConfig":{"postgresql_user_name":"'$postgresql_user_name'", "postgresql_password":"'$user_password'", "postgresql_database":"'$postgresql_databse_name'"}}'

/bin/echo '{"code":5000,"success":"true", "message":"App42RDS Setup Completed Successfully", "subscription_id":"'$subscription_id'", "resource_group":"'$resourcegroup'", "region":"'$region'", "storage_account":"'$storage_name'", "storage_account_key":"'$storage_key'", "setup_ip":"'$proxylb'", "network_security_group":"'$setupName'-proxyhansg", "network_security_group_rule":"'$nsg_rule'",  "nodes":[{"pub_ip":"'$proxyha1'", "private_ip":"10.20.1.5", "type":"proxy1", "name":"'$setupName'-proxyha1"}, {"pub_ip":"'$proxyha2'", "private_ip":"10.20.1.6", "type":"proxy2", "name":"'$setupName'-proxyha2"}, {"pub_ip":"'$postgresqlha1'", "private_ip":"10.20.1.7", "type":"master", "name":"'$setupName'-postgresqlha1", "data_disk":"'$setupName'-postgresqlha1disk1;'$storagetype';'$disksize'"}, {"pub_ip":"'$postgresqlha2'", "private_ip":"10.20.1.8", "type":"slave", "name":"'$setupName'-postgresqlha2", "data_disk":"'$setupName'-postgresqlha2disk1;'$storagetype';'$disksize'"}], "setupConfig":{"user_name":"'$postgresql_user_name'", "password":"'$user_password'", "database":"'$postgresql_databse_name'"}}'