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
wget http://mirrors.ukfast.co.uk/sites/ftp.apache.org/hadoop/common/hadoop-1.2.1/hadoop_1.2.1-1_x86_64.deb
sudo dpkg -i hadoop_1.2.1-1_x86_64.deb
sudo rm hadoop_1.2.1-1_x86_64.deb

echo "**************************************"
echo "Create Hadoop disk /hadoop"
echo "**************************************"

sudo mkdir -p /hadoop/dfs/{nn,dn}
sudo chown -R hdfs:hdfs /hadoop/dfs
sudo chmod 700 /hadoop/dfs
sudo mkdir -p /hadoop/mapred/local
sudo chown -R mapred:hadoop /hadoop/mapred/local

sudo usermod -d /home/hdfs hdfs
sudo mkdir /home/hdfs
sudo cp -r /home/vagrant/.ssh /home/hdfs
sudo mv /home/hdfs/.ssh/vagrant /home/hdfs/.ssh/id_rsa
sudo cp /home/hdfs/.ssh/authorized_keys /home/hdfs/.ssh/id_rsa.pub
sudo chown -R hdfs:hdfs /home/hdfs

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

echo ${VAGRANT_ETH1_IP} > /etc/hadoop/slaves

sudo cp /vagrant/tmpl/core-site.xml /etc/hadoop/core-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/core-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/core-site.xml
cat /etc/hadoop/core-site.xml

sudo cp /vagrant/tmpl/hdfs-site.xml /etc/hadoop/hdfs-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/hdfs-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/hdfs-site.xml
cat /etc/hadoop/hdfs-site.xml

sudo cp /vagrant/tmpl/mapred-site.xml /etc/hadoop/mapred-site.xml
sudo sed -i 's/VAGRANT_ETH1_IP/'${VAGRANT_ETH1_IP}'/g' /etc/hadoop/mapred-site.xml
sudo sed -i 's/VAGRANT_HOST/'${VAGRANT_HOST}'/g' /etc/hadoop/mapred-site.xml
cat /etc/hadoop/mapred-site.xml

sudo cp /vagrant/tmpl/hadoop-env.sh /etc/hadoop/hadoop-env.sh
cat /etc/hadoop/hadoop-env.sh

#if [ ! -e /hadoop/setup-hdfs ] ; then

  echo "**************************************"
  echo "Format HDFS"
  echo "**************************************"

  sudo -u hdfs hadoop namenode -format
  touch /hadoop/setup-hdfs
#fi
