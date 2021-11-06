#!/bin/bash

sudo apt-get update 2>/dev/null
sudo apt-get install openjdk-8-jre-headless -y 2>/dev/null
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add - 2>/dev/null
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list' 2>/dev/null
sudo apt update -y && sudo apt install jenkins -y 2>/dev/null
sudo mkdir /var/lib/jenkins/IaC 2>/dev/null
sudo chown jenkins:jenkins /var/lib/jenkins/IaC 2>/dev/null
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null

