#!/bin/sh

########################
# Author : Antoine Amend
# Date : 2014-08-09
# Vagrant script to provision Hadoop Hortonworks distribution without Ambari
########################

VAGRANT_ETH1_IP=`ifconfig eth1 | grep 'inet' | grep -v '127.0.0.1' | grep -v 'inet6' | cut -d: -f2 | awk '{print $1}'`
VAGRANT_HOST=`hostname`

echo "**************************************"
echo "Install common packages"
echo "**************************************"

sudo apt-get install -y unzip
sudo apt-get install -y software-properties-common
sudo apt-get install -y apt-file
sudo apt-get install -y vim
sudo apt-get install -y python-software-properties
sudo apt-get install -y curl
sudo apt-get install -y wget

echo "**************************************"
echo "Install SSH key"
echo "**************************************"

ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
chown vagrant:vagrant /root/.ssh/id_rsa
chown vagrant:vagrant /root/.ssh/id_rsa.pub
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

echo "**************************************"
echo "Install Hortonworks repository"
echo "**************************************"

wget http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.1.5.0/hdp.list -O /etc/apt/sources.list.d/hdp.list  
sudo gpg --keyserver pgp.mit.edu --recv-keys B9733A7A07513CAD
sudo gpg -a --export 07513CAD | apt-key add -

echo "**************************************"
echo "Install Hadoop packages"
echo "**************************************"

wget http://www.magnatempusgroup.net/ftphost/releases/MTG-0.3.1/ubuntu/pool/contrib/b/bigtop-utils/bigtop-utils_0.3.1.MTG-1_all.deb
sudo dpkg -i bigtop-utils_0.3.1.MTG-1_all.deb
rm bigtop-utils_0.3.1.MTG-1_all.deb

sudo apt-get update
sudo apt-get install -y openjdk-7-jdk
sudo apt-get install -y openjdk-7-jre-headless
sudo apt-get install -y --force-yes hadoop-hdfs-namenode
sudo apt-get install -y --force-yes hadoop-hdfs-datanode
sudo apt-get install -y --force-yes hadoop-yarn-resourcemanager
sudo apt-get install -y --force-yes hadoop-yarn-nodemanager
sudo apt-get install -y --force-yes hadoop-mapreduce-historyserver
sudo apt-get install -y --force-yes hadoop-yarn-proxyserver

echo "JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64

echo "**************************************"
echo "Create Hadoop disk /hadoop"
echo "**************************************"

sudo mkdir -p /hadoop/dfs/{nn,dn}
sudo chown -R hdfs:hdfs /hadoop/dfs
sudo chmod 700 /hadoop/dfs
sudo mkdir -p /hadoop/yarn/{local,logs}
sudo chown -R yarn:yarn /hadoop/yarn

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

echo ${VAGRANT_ETH1_IP} > /etc/hadoop/conf/slaves

cp /vagrant/tmpl/core-site.xml /etc/hadoop/conf/core-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/core-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/core-site.xml
cat /etc/hadoop/conf/core-site.xml

cp /vagrant/tmpl/hdfs-site.xml /etc/hadoop/conf/hdfs-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/hdfs-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/hdfs-site.xml
cat /etc/hadoop/conf/hdfs-site.xml

cp /vagrant/tmpl/mapred-site.xml /etc/hadoop/conf/mapred-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/mapred-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/mapred-site.xml
cat /etc/hadoop/conf/mapred-site.xml

cp /vagrant/tmpl/yarn-site.xml /etc/hadoop/conf/yarn-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/yarn-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/yarn-site.xml
cat /etc/hadoop/conf/yarn-site.xml

echo "**************************************"
echo "Format HDFS"
echo "**************************************"

sudo -u hdfs hdfs namenode -format

echo "**************************************"
echo "Starting HDFS"
echo "**************************************"

sudo service hadoop-hdfs-namenode start
sudo service hadoop-hdfs-datanode start

echo "**************************************"
echo "Creating HDFS structure"
echo "**************************************"

sudo -u hdfs hadoop fs -mkdir /tmp 
sudo -u hdfs hadoop fs -mkdir /user
sudo -u hdfs hadoop fs -mkdir /var
sudo -u hdfs hadoop fs -mkdir /user/vagrant
sudo -u hdfs hadoop fs -mkdir /user/history
sudo -u hdfs hadoop fs -mkdir /var/log
sudo -u hdfs hadoop fs -mkdir /var/log/hadoop-yarn

sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -chmod -R 1777 /user/history
sudo -u hdfs hadoop fs -chown -R yarn:mapred /var/log/hadoop-yarn
sudo -u hdfs hadoop fs -chown -R vagrant /user/vagrant
sudo -u hdfs hadoop fs -chown -R yarn /user/history

echo "**************************************"
echo "Starting MapReduce"
echo "**************************************"

echo "HADOOP_MAPRED_HOME=/usr/lib/hadoop-mapreduce" >> /etc/environment
echo "YARN_HOME=/usr/lib/hadoop-yarn" >> /etc/environment
echo "HADOOP_HDFS_HOME=/usr/lib/hadoop-hdfs" >> /etc/environment
echo "HADOOP_COMMON_HOME=/usr/lib/hadoop" >> /etc/environment
echo "HADOOP_CONF_DIR=/etc/hadoop/conf" >> /etc/environment
echo "YARN_CONF_DIR=/etc/hadoop/conf" >> /etc/environment

export HADOOP_MAPRED_HOME=/usr/lib/hadoop-mapreduce
export YARN_HOME=/usr/lib/hadoop-yarn
export HADOOP_HDFS_HOME=/usr/lib/hadoop-hdfs
export HADOOP_COMMON_HOME=/usr/lib/hadoop
export HADOOP_CONF_DIR=/etc/hadoop/conf
export YARN_CONF_DIR=/etc/hadoop/conf

sudo service hadoop-yarn-resourcemanager start
sudo service hadoop-yarn-nodemanager start
sudo service hadoop-mapreduce-historyserver start

echo "**************************************"
echo "Installing Hadoop ecosystem"
echo "**************************************"

sudo apt-get install -y --force-yes sqoop
sudo apt-get install -y --force-yes pig
sudo apt-get install -y --force-yes hive

echo "**************************************"
echo "Install MySQL"
echo "**************************************"

debconf-set-selections << EOF
mysql-server-5.5 mysql-server/root_password password root
EOF

debconf-set-selections << EOF
mysql-server-5.5 mysql-server/root_password_again password root
EOF

sudo apt-get install -y --force-yes mysql-server-5.5
sudo apt-get install -y --force-yes mysql-client-core-5.5
sudo chkconfig mysql on

# Bind to external address
sed -i 's/127\.0\.0\.1/'${VAGRANT_ETH1_IP}'/' /etc/mysql/my.cnf
sudo service mysql restart

echo "**************************************"
echo "Create Hive Metastore Schema"
echo "**************************************"

mysql -uroot -proot << EOF
CREATE USER 'hive'@'${VAGRANT_ETH1_IP}' IDENTIFIED BY 'hive';
CREATE DATABASE metastore;
GRANT ALL ON metastore.* TO 'hive'@'${VAGRANT_ETH1_IP}';
FLUSH PRIVILEGES;
USE metastore;
SOURCE /usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.13.0.mysql.sql;
EOF

echo "**************************************"
echo "Download / Install MySQL Driver"
echo "**************************************"

wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.31.tar.gz
gunzip mysql-connector-java-5.1.31.tar.gz
tar xf mysql-connector-java-5.1.31.tar
JAR=mysql-connector-java-5.1.31/mysql-connector-java-5.1.31-bin.jar
cp $JAR /usr/lib/sqoop/lib/mysql-connector-java.jar
cp $JAR /usr/lib/hive/lib/mysql-connector-java.jar
rm -rf mysql-connector-java-5.1.31*

echo "**************************************"
echo "Set Hive configuration"
echo "**************************************"

cp /vagrant/tmpl/hive-site.xml /etc/hive/conf/hive-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hive/conf/hive-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hive/conf/hive-site.xml
cat /etc/hive/conf/hive-site.xml

echo "**************************************"
echo "Creating Hive HDFS structure"
echo "**************************************"

sudo -u hdfs hadoop fs -mkdir /user/hive
sudo -u hdfs hadoop fs -mkdir /user/hive/warehouse

sudo -u hdfs hadoop fs -chown hive /user/hive/warehouse
sudo -u hdfs hadoop fs -chmod -R 1777 /user/hive/warehouse

echo "**************************************"
echo "Install Hive Server + Metastore"
echo "**************************************"

sudo apt-get install -y --force-yes hive-metastore
sudo apt-get install -y --force-yes hive-server2

echo "**************************************"
echo "Install Hbase / Zookeeper packages"
echo "**************************************"

sudo apt-get install -y --force-yes zookeeper
sudo apt-get install -y --force-yes zookeeper-server
sudo apt-get install -y --force-yes hbase-master
sudo apt-get install -y --force-yes hbase-regionserver
sudo apt-get install -y --force-yes hbase-thrift
sudo apt-get install -y --force-yes hbase-rest

echo "**************************************"
echo "Set HBase configuration"
echo "**************************************"

cp /vagrant/tmpl/hbase-site.xml /etc/hbase/conf/hbase-site.xml
sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hbase/conf/hbase-site.xml
sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hbase/conf/hbase-site.xml

echo "ZOO_LOG_DIR=/var/log/zookeeper" >> /etc/environment
export ZOO_LOG_DIR=/var/log/zookeeper

sudo service zookeeper-server init --myid=1
sudo service zookeeper-server start

# Issue with variable overridden by zookeeper env
mv /etc/zookeeper/conf/zookeeper-env.sh /etc/zookeeper/conf/zookeeper-env.sh.bak

echo "**************************************"
echo "Creating HBase HDFS structure"
echo "**************************************"

sudo -u hdfs hadoop fs -mkdir -p /user/hbase
sudo -u hdfs hadoop fs -chown hbase /user/hbase
sudo service hbase-master restart
sudo service hbase-regionserver restart

echo "**************************************"
echo "Installing scala / spark"
echo "**************************************"

wget http://www.scala-lang.org/files/archive/scala-2.10.1.tgz
tar xvf scala-2.10.1.tgz
mv scala-2.10.1 /usr/lib
rm scala-2.10.1.tgz
ln -s /usr/lib/scala-2.10.1/ /usr/lib/scala

wget http://d3kbcqa49mib13.cloudfront.net/spark-1.1.0-bin-hadoop2.4.tgz
tar -zxf spark-1.1.0-bin-hadoop2.4.tgz
mv spark-1.1.0-bin-hadoop2.4 /usr/lib
rm spark-1.1.0-bin-hadoop2.4.tgz
ln -s /usr/lib/spark-1.1.0-bin-hadoop2.4 /usr/lib/spark

CPU=`cat /proc/cpuinfo | grep processor | wc -l`

touch /usr/lib/spark/conf/spark-env.sh
chmod +x /usr/lib/spark/conf/spark-env.sh
cat > /usr/lib/spark/conf/spark-env.sh <<EOF
#!/usr/bin/env bash

SPARK_WORKER_INSTANCES=1
SPARK_WORKER_CORES=$CPU
EOF

cat > /usr/lib/spark/conf/spark-defaults.conf <<EOF
spark.master			spark://vagrant:7077
spark.eventLog.enabled		true
spark.eventLog.dir		file:///tmp/spark-logs
spark.serializer		org.apache.spark.serializer.KryoSerializer
EOF

echo 'PATH=${PATH}:/usr/lib/spark/bin >> /etc/environment'
echo 'SCALA_HOME=/usr/lib/scala' >> /etc/environment
export SCALA_HOME=/usr/lib/scala

echo "**************************************"
echo "Start Spark daemons"
echo "**************************************"

/usr/lib/spark/sbin/start-master.sh
/usr/lib/spark/sbin/start-slaves.sh

echo "**************************************"
echo "Installing ElasticSearch"
echo "**************************************"

wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.1.deb
dpkg -i elasticsearch-1.1.1.deb
rm elasticsearch-1.1.1.deb
service elasticsearch start
update-rc.d elasticsearch defaults 95 10

echo "**************************************"
echo "Installing Kibana"
echo "**************************************"

sudo apt-get install apache2 -y --force-yes
cp /etc/apache2/sites-available/default /etc/apache2/sites-available/kibana
mkdir -p /var/www/kibana
wget http://download.elasticsearch.org/kibana/kibana/kibana-latest.zip
unzip kibana-latest.zip
rm kibana-latest.zip
mv kibana-latest/* /var/www/kibana
rm -r kibana-latest
a2ensite kibana
/etc/init.d/apache2 restart

echo "**************************************"
echo "All done !"
echo "**************************************"


