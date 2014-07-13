#!/bin/sh

########################
# Author : Antoine Amend
# Date : 2014-08-09
# Vagrant script to provision Hadoop CDH4 distribution without Cloudera Manager
########################

VAGRANT_ETH1_IP=`ifconfig eth1 | grep 'inet' | grep -v '127.0.0.1' | grep -v 'inet6' | cut -d: -f2 | awk '{print $1}'`
VAGRANT_HOST=`hostname`

if [ ! -e /hadoop ] ; then
  sudo mkdir /hadoop
fi

echo "**************************************"
echo "Install common packages"
echo "**************************************"
sudo apt-get install -y software-properties-common
sudo apt-get install -y apt-file
sudo apt-get install -y python-software-properties
sudo apt-get install -y curl
sudo apt-get install -y wget

echo "**************************************"
echo "Install Cloudera repository"
echo "**************************************"
echo "deb [arch=amd64] http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4 contrib" > /etc/apt/sources.list.d/cloudera-cdh4.list 
echo "deb-src http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4 contrib" >> /etc/apt/sources.list.d/cloudera-cdh4.list 
echo "deb [arch=amd64] http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib" > /etc/apt/sources.list.d/cloudera-cm.list 
echo "deb-src http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib" >> /etc/apt/sources.list.d/cloudera-cm.list
curl -s http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh/archive.key | sudo apt-key add -
sudo apt-get update

echo "**************************************"
echo "Install Hadoop packages"
echo "**************************************"
sudo apt-get install -y oracle-j2sdk1.6
sudo apt-get install -y hadoop-hdfs-namenode
sudo apt-get install -y hadoop-hdfs-datanode
sudo apt-get install -y hadoop-0.20-mapreduce-jobtracker
sudo apt-get install -y hadoop-0.20-mapreduce-tasktracker
sudo apt-get install -y hadoop-client
sudo apt-get install -y hadoop-mapreduce

echo "**************************************"
echo "Create Hadoop disk /hadoop"
echo "**************************************"
sudo mkdir -p /hadoop/dfs/{nn,dn}
sudo chown -R hdfs:hdfs /hadoop/dfs
sudo chmod 700 /hadoop/dfs
sudo mkdir -p /hadoop/mapred/local
sudo chown -R mapred:hadoop /hadoop/mapred/local

echo "**************************************"
echo "Set Hadoop configuration"
echo "**************************************"

cat > /etc/hosts <<EOF
127.0.0.1       localhost
${VAGRANT_ETH1_IP}      ${VAGRANT_HOST}

# The following lines are desirable for VAGRANT_ETH1_IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > /etc/hadoop/conf/slaves << EOF
${VAGRANT_ETH1_IP}
EOF

cat > /etc/hadoop/conf/core-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>fs.defaultFS</name>
  <value>hdfs://${VAGRANT_HOST}:8020</value>
 </property>
</configuration>
EOF

cat > /etc/hadoop/conf/hdfs-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>dfs.namenode.name.dir</name>
  <value>/hadoop/dfs/nn</value>
 </property>
 <property>
  <name>dfs.datanode.data.dir</name>
  <value>/hadoop/dfs/dn</value>
 </property>
 <property>
  <name>dfs.webhdfs.enabled</name>
  <value>true</value>
 </property>
 <property>
  <name>dfs.replication</name>
  <value>1</value>
 </property>
</configuration>
EOF

cat > /etc/hadoop/conf/mapred-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>mapred.job.tracker</name>
  <value>${VAGRANT_HOST}:8021</value>
 </property>
 <property>
  <name>mapred.local.dir</name>
  <value>/hadoop/mapred/local</value>
 </property>
 <property>
  <name>mapred.system.dir</name>
  <value>/tmp/mapred/system</value>
 </property>
 <property>
  <name>mapreduce.jobtracker.staging.root.dir</name>
  <value>/user</value>
 </property>
 <property>
  <name>mapred.reduce.tasks</name>
  <value>1</value>
 </property>
</configuration>
EOF

if [ ! -e /hadoop/setup-hdfs ] ; then
  echo "**************************************"
  echo "Format HDFS"
  echo "**************************************"
  sudo -u hdfs hdfs namenode -format
  touch /hadoop/setup-hdfs
fi

echo "**************************************"
echo "Starting HDFS"
echo "**************************************"
sudo service hadoop-hdfs-namenode start
sudo service hadoop-hdfs-datanode start

echo "**************************************"
echo "Creating HDFS structure"
echo "**************************************"
sudo -u hdfs hadoop fs -mkdir /tmp
sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -mkdir -p /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
sudo -u hdfs hadoop fs -chmod 1777 /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
sudo -u hdfs hadoop fs -chown -R mapred /var/lib/hadoop-hdfs/cache/mapred
sudo -u hdfs hadoop fs -mkdir /tmp/mapred/system
sudo -u hdfs hadoop fs -chown mapred:hadoop /tmp/mapred/system
sudo -u hdfs hadoop fs -mkdir -p /user/vagrant
sudo -u hdfs hadoop fs -chown vagrant /user/vagrant

echo "**************************************"
echo "Starting MapReduce"
echo "**************************************"
sudo service hadoop-0.20-mapreduce-jobtracker start
sudo service hadoop-0.20-mapreduce-tasktracker start

echo "**************************************"
echo "Installing Hadoop ecosystem"
echo "**************************************"
sudo apt-get install -y sqoop
sudo apt-get install -y pig
sudo apt-get install -y hive

echo "**************************************"
echo "Install MySQL"
echo "**************************************"
sudo debconf-set-selections << EOF
mysql-server-5.5 mysql-server/root_password password root
EOF

sudo debconf-set-selections << EOF
mysql-server-5.5 mysql-server/root_password_again password root
EOF

sudo apt-get install -y mysql-server-5.5
sudo apt-get install -y mysql-client-core-5.5
sudo chkconfig mysql on

if [ ! -e /hadoop/setup-mysql ] ; then
  echo "**************************************"
  echo "Create Hive Metastore Schema"
  echo "**************************************"
  touch /hadoop/setup-mysql
  mysql -uroot -proot << EOF
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'hive';
CREATE DATABASE metastore;
GRANT ALL ON metastore.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
USE metastore;
SOURCE /usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.10.0.mysql.sql;
EOF
fi

if [ ! -e /usr/lib/sqoop/lib/mysql-connector-java.jar || ! -e /usr/lib/hive/lib/mysql-connector-java.jar ] ; then
  echo "**************************************"
  echo "Download / Install MySQL Driver"
  echo "**************************************"
  wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.31.tar.gz
  gunzip mysql-connector-java-5.1.31.tar.gz
  tar xf mysql-connector-java-5.1.31.tar
  JAR=mysql-connector-java-5.1.31/mysql-connector-java-5.1.31-bin.jar
  sudo cp $JAR /usr/lib/sqoop/lib/mysql-connector-java.jar
  sudo cp $JAR /usr/lib/hive/lib/mysql-connector-java.jar
  if [[ -e mysql-connector-java-5.1.31 ]] ; then
    sudo rm -rf mysql-connector-java-5.1.31
  fi
  if [[ -e mysql-connector-java-5.1.31.tar ]] ; then
    sudo rm -rf mysql-connector-java-5.1.31.tar
  fi
  if [[ -e mysql-connector-java-5.1.31.tar.gz ]] ; then
    sudo rm -rf mysql-connector-java-5.1.31.tar.gz
  fi
fi

echo "**************************************"
echo "Set Hive configuration"
echo "**************************************"
cat > /etc/hive/conf/hive-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:mysql://localhost/metastore</value>
 </property>
 <property>
  <name>javax.jdo.option.ConnectionDriverName</name>
  <value>com.mysql.jdbc.Driver</value>
 </property>
 <property>
  <name>javax.jdo.option.ConnectionUserName</name>
  <value>hive</value>
 </property>
 <property>
  <name>javax.jdo.option.ConnectionPassword</name>
  <value>hive</value>
 </property>
 <property>
  <name>datanucleus.autoCreateSchema</name>
  <value>false</value>
 </property>
 <property>
  <name>datanucleus.fixedDatastore</name>
  <value>true</value>
 </property>
 <property>
  <name>hive.metastore.uris</name>
  <value>thrift://${VAGRANT_ETH1_IP}:9083</value>
 </property>
</configuration>
EOF

echo "**************************************"
echo "Creating Hive HDFS structure"
echo "**************************************"

sudo -u hdfs hadoop fs -mkdir -p /user/hive/warehouse
sudo -u hdfs hadoop fs -chown hive /user/hive/warehouse
sudo -u hdfs hadoop fs -chmod 1777 /user/hive/warehouse

echo "**************************************"
echo "Install Hive Server + Metastore"
echo "**************************************"

sudo apt-get install -y hive-metastore
sudo apt-get install -y hive-server2

echo "**************************************"
echo "All done !"
echo "**************************************"

