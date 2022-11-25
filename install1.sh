echo "Installing nano, curl and	wget.."
yum -y install curl wget nano                       

echo "Installing Xen Guest Tools..."
yum -y install xe-guest-utilities-latest
systemctl enable xe-linux-distribution
systemctl start xe-linux-distribution

echo "Fixing Quotas..."

echo "modify grub..."
cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.orig
mv /etc/default/grub /etc/default/grub.old
wget -O	/etc/default/grub https://raw.githubusercontent.com/marcpope/centos7install/main/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

echo "updating all current packages"
yum -y update

echo "now reboot and go	to next step"
