#!/bin/sh

########################
# Author : Antoine Amend
# Date : 2014-08-09
# Vagrant script to provision Hadoop Hortonworks distribution without Ambari
########################

VAGRANT_ETH1_IP=`ifconfig eth1 | grep 'inet' | grep -v '127.0.0.1' | grep -v 'inet6' | cut -d: -f2 | awk '{print $1}'`
VAGRANT_HOST=`hostname`

if [ ! -e /hadoop ] ; then
  sudo mkdir /hadoop
fi

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
echo "Install Cloudera repository (for Java)"
echo "**************************************"

cat > /etc/apt/sources.list.d/cloudera-cm.list << EOF
deb [arch=amd64] http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib
deb-src http://archive.cloudera.com/cm4/ubuntu/precise/amd64/cm precise-cm4 contrib
EOF
curl -s http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh/archive.key | sudo apt-key add -

echo "**************************************"
echo "Install Hortonworks repository"
echo "**************************************"

wget http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/hdp.list -O /etc/apt/sources.list.d/hdp.list
gpg --keyserver pgp.mit.edu --recv-keys B9733A7A07513CAD
gpg -a --export 07513CAD | apt-key add -

echo "**************************************"
echo "Install Hadoop packages"
echo "**************************************"

wget http://www.magnatempusgroup.net/ftphost/releases/MTG-0.3.1/ubuntu/pool/contrib/b/bigtop-utils/bigtop-utils_0.3.1.MTG-1_all.deb
sudo dpkg -i bigtop-utils_0.3.1.MTG-1_all.deb
sudo rm bigtop-utils_0.3.1.MTG-1_all.deb

sudo apt-get update
sudo apt-get install -y oracle-j2sdk1.6
sudo apt-get install -y hadoop-hdfs-namenode
sudo apt-get install -y hadoop-hdfs-datanode
sudo apt-get install -y hadoop-yarn-resourcemanager
sudo apt-get install -y hadoop-yarn-nodemanager
sudo apt-get install -y hadoop-mapreduce-historyserver
sudo apt-get install -y hadoop-yarn-proxyserver

VARIABLE_SET=`cat /etc/environment | grep JAVA_HOME | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "JAVA_HOME=/usr/lib/jvm/j2sdk1.6-oracle" >> /etc/environment
fi
export JAVA_HOME=/usr/lib/jvm/j2sdk1.6-oracle

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

VARIABLE_SET=`cat /etc/environment | grep HADOOP_CONF_DIR | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "HADOOP_CONF_DIR=/etc/hadoop/conf" >> /etc/environment
fi

VARIABLE_SET=`cat /etc/environment | grep YARN_CONF_DIR | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "YARN_CONF_DIR=/etc/hadoop/conf" >> /etc/environment
fi


sudo service hadoop-yarn-resourcemanager start
sudo service hadoop-yarn-nodemanager start
sudo service hadoop-mapreduce-historyserver start

echo "**************************************"
echo "Install Hbase / Zookeeper packages"
echo "**************************************"

sudo apt-get install -y zookeeper
sudo apt-get install -y zookeeper-server
sudo apt-get install -y hbase-master
sudo apt-get install -y hbase-regionserver
sudo apt-get install -y hbase-thrift
sudo apt-get install -y hbase-rest

echo "**************************************"
echo "Set HBase configuration"
echo "**************************************"

sudo cp /vagrant/tmpl/hbase-site.xml /etc/hbase/conf/hbase-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hbase/conf/hbase-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hbase/conf/hbase-site.xml
cat /etc/hbase/conf/hbase-site.xml

VARIABLE_SET=`cat /etc/environment | grep ZOO_LOG_DIR | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "ZOO_LOG_DIR=/var/log/zookeeper" >> /etc/environment
fi

sudo service zookeeper-server init --myid=1
sudo service zookeeper-server start

# Issue with variable overridden by zookeeper env
sudo mv /etc/zookeeper/conf/zookeeper-env.sh /etc/zookeeper/conf/zookeeper-env.sh.bak

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
sudo tar xvf scala-2.10.1.tgz
sudo mv scala-2.10.1 /usr/lib
sudo rm scala-2.10.1.tgz
sudo ln -s /usr/lib/scala-2.10.1/ /usr/lib/scala

wget wget http://public-repo-1.hortonworks.com/spark/centos6/tar/spark-1.0.1.2.1.3.0-563-bin-2.4.0.2.1.3.0-563.tgz
sudo tar -zxf spark-1.0.1.2.1.3.0-563-bin-2.4.0.2.1.3.0-563.tgz
sudo mv spark-1.0.1.2.1.3.0-563-bin-2.4.0.2.1.3.0-563 /usr/lib
sudo rm spark-1.0.1.2.1.3.0-563-bin-2.4.0.2.1.3.0-563.tgz
sudo ln -s /usr/lib/spark-1.0.1.2.1.3.0-563-bin-2.4.0.2.1.3.0-563 /usr/lib/spark

VARIABLE_SET=`cat /etc/environment | grep SCALA_HOME | grep -v PATH | wc -l`
if [ $VARIABLE_SET -eq 0 ] ; then
  echo "SCALA_HOME=/usr/lib/scala" >> /etc/environment
fi

echo "**************************************"
echo "Installing ElasticSearch"
echo "**************************************"

sudo apt-get install openjdk-7-jre-headless -y
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.1.1.deb
sudo dpkg -i elasticsearch-1.1.1.deb
sudo rm elasticsearch-1.1.1.deb
sudo service elasticsearch start
sudo update-rc.d elasticsearch defaults 95 10

echo "**************************************"
echo "Installing Kibana"
echo "**************************************"

sudo apt-get install apache2 -y
sudo cp /etc/apache2/sites-available/default /etc/apache2/sites-available/kibana
sudo mkdir -p /var/www/kibana
wget http://download.elasticsearch.org/kibana/kibana/kibana-latest.zip
unzip kibana-latest.zip
sudo rm kibana-latest.zip
sudo mv kibana-latest/* /var/www/kibana
sudo rm -r kibana-latest
sudo a2ensite kibana
sudo /etc/init.d/apache2 restart

echo "**************************************"
echo "All done !"
echo "**************************************"

