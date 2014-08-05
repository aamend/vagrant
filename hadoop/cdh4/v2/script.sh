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
sudo apt-get install -y vim
sudo apt-get install -y python-software-properties
sudo apt-get install -y curl
sudo apt-get install -y wget

echo "**************************************"
echo "Install Cloudera repository"
echo "**************************************"

cat > /etc/apt/sources.list.d/cloudera-cdh4.list << EOF
deb [arch=amd64] http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4 contrib
deb-src http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4 contrib
EOF
cat > /etc/apt/sources.list.d/cloudera-cm.list << EOF
deb [arch=amd64] http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib
deb-src http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib
EOF
curl -s http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh/archive.key | sudo apt-key add -
sudo apt-get update

echo "**************************************"
echo "Install Hadoop packages"
echo "**************************************"

sudo apt-get install -y oracle-j2sdk1.6
sudo apt-get install -y hadoop-hdfs-namenode
sudo apt-get install -y hadoop-hdfs-datanode
sudo apt-get install -y hadoop-yarn-resourcemanager
sudo apt-get install -y hadoop-yarn-nodemanager
sudo apt-get install -y hadoop-mapreduce-historyserver
sudo apt-get install -y hadoop-yarn-proxyserver

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

sudo cp /vagrant/tmpl/core-site.xml /etc/hadoop/conf/core-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/core-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/core-site.xml
cat /etc/hadoop/conf/core-site.xml

sudo cp /vagrant/tmpl/hdfs-site.xml /etc/hadoop/conf/hdfs-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/hdfs-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/hdfs-site.xml
cat /etc/hadoop/conf/hdfs-site.xml

sudo cp /vagrant/tmpl/mapred-site.xml /etc/hadoop/conf/mapred-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/mapred-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/mapred-site.xml
cat /etc/hadoop/conf/mapred-site.xml

sudo cp /vagrant/tmpl/yarn-site.xml /etc/hadoop/conf/yarn-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/conf/yarn-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/conf/yarn-site.xml
cat /etc/hadoop/conf/yarn-site.xml

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
sudo -u hdfs hadoop fs -mkdir /user
sudo -u hdfs hadoop fs -mkdir /user/vagrant
sudo -u hdfs hadoop fs -mkdir /user/history
sudo -u hdfs hadoop fs -mkdir /var/log/hadoop-yarn
sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -chmod -R 1777 /user/history
sudo -u hdfs hadoop fs -chown yarn:mapred /var/log/hadoop-yarn
sudo -u hdfs hadoop fs -chown vagrant /user/vagrant
sudo -u hdfs hadoop fs -chown yarn /user/history
sudo -u hdfs hadoop fs -ls -R /

echo "**************************************"
echo "Starting MapReduce"
echo "**************************************"

VARIABLE_SET=`cat /etc/environment | grep HADOOP_MAPRED_HOME | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "HADOOP_MAPRED_HOME=/usr/lib/hadoop-mapreduce" >> /etc/environment
fi

VARIABLE_SET=`cat /etc/environment | grep YARN_HOME | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "YARN_HOME=/usr/lib/hadoop-yarn" >> /etc/environment
fi

VARIABLE_SET=`cat /etc/environment | grep HADOOP_HDFS_HOME | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "HADOOP_HDFS_HOME=/usr/lib/hadoop-hdfs" >> /etc/environment
fi

VARIABLE_SET=`cat /etc/environment | grep HADOOP_COMMON_HOME | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "HADOOP_COMMON_HOME=/usr/lib/hadoop" >> /etc/environment
fi

sudo service hadoop-yarn-resourcemanager start
sudo service hadoop-yarn-nodemanager start
sudo service hadoop-mapreduce-historyserver start

echo "**************************************"
echo "All done !"
echo "**************************************"

