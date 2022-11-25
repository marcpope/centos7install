echo "Install Interworx"
#sh <((curl -sL updates.interworx.com/interworx/7/install.sh)) -l

echo "Installing Xen Guest Tools..."
yum -y install xe-guest-utilities-latest
systemctl enable xe-linux-distribution
systemctl start xe-linux-distribution

echo "Download Lasso 8.6"
wget http://www.lassosoft.com/_downloads/public/Lasso_Server/BETA/Lasso-Professional-8.6.3-3b1.el7.x86_64.rpm
wget http://www.lassosoft.com/_downloads/public/Lasso_Server/BETA/Lasso-Professional-Apache2-8.6.3-3b1.el7.x86_64.rpm

echo "Download ImageMagick and other libraries necessary.."
yum -y install ImageMagick java-openjdk libicu unixODBC ImageMagick6-libs ImageMagick6-perl ImageMagick6-devel

echo "Force Install Lasso 8.6"
rpm --force -ivh *.rpm

echo "Install new image tag"
wget -O ~lasso/LassoStartup/image.lasso https://raw.githubusercontent.com/marcpope/centos7install/main/image.lasso
chown root:wheel ~lasso/LassoStartup/image.lasso 

echo "Install OS Process"
cp ~lasso/Extensions/OS_Process/OS_Process.so ~lasso/LassoModules/

echo "Restart Lasso"
lasso8ctl restart

echo "Install Synology Active Backup"
wget https://global.download.synology.com/download/Utility/ActiveBackupBusinessAgent/2.4.2-2341/Linux/x86_64/Synology%20Active%20Backup%20for%20Business%20Agent-2.4.2-2341-x64-rpm.zip
unzip Synology\ Active\ Backup\ for\ Business\ Agent-2.4.2-2341-x64-rpm.zip
./install.run

echo "Now run abb-cli -c to connect to Synology Backup Server, Initialize Lasso and Initialize Interworx."
