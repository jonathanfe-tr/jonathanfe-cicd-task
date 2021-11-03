#!/bin/bash

apt update
wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
echo deb https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install jenkins -y
systemctl start jenkins -y
systemctl enable jenkins -y
cat /var/lib/jenkins/secrets/initialAdminPassword

