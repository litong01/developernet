DeveloperNet
============

This is the vagrant project to install openstack onto physical servers.

The project uses vagrant plugin ManagedServers Provider, detailed information
can be found here::

    https://github.com/tknerr/vagrant-managed-servers

Before you start kicking off the vagrant scripts, there are few things you
need to do to make it a successful OpenStack install. You will find few files
in directory provisioning off of the root directory of the project::

    provisioning/nodes.conf.yml
    provisioning/nodes.dev.conf.yml
    provisioning/sample.ids.yml

This project uses these files to allow you to install OpenStack cloud onto
various physical nodes. It also uses these files to allow one to deploy
OpenStack into different environment. If you are planning to deploy OpenStack
to a development environment, then make changes to nodes.dev.conf.yml and
create an ids.dev.conf.yml file by copy sample.ids.yml. If you are
planning to deploy to a production environment, then make changes to
nodes.conf.yml and create ids.conf.yml file by copy sample.ids.yml. To switch
from one environment to another, simply use the following command::

    export LEAP=DEVELOPMENT   or
    export LEAP=PRODUCTION

Files come with the project in directory provisioning are the setting from
an example environment. If you use the project to setup your own cloud, then
you will need to make changes to these files accordingly to reflect your own
development or production environment.


Sample id file is provided so that you can easily make one for your
environment. You should copy the sample id file to make your own ids.conf.yml
or ids.dev.conf.yml file. The ids.conf.yml will be used for production
environment, the ids.dev.conf.yml file will be used for development
environment. The purposes of varilables in the file are explained below::

    username - the user id to access server to run OS, normally root
    password - the password for the user
    sys_password - the password used for all OpenStack services.

Follow the configurations in nodes.conf.yml or nodes.dev.conf.yml file to
configure your environment.


Run the scripts to create OpenStack cloud
=========================================

Once all the settings look good, you can run the following command to set
things up::

    export VAGRANT_VAGRANTFILE=Vagrantfile
    export VAGRANT_DEFAULT_PROVIDER=managed
    export LEAP=DEVELOPMENT

    vagrant up
    vagrant provision

If everything works as expected, you should have your OpenStack cloud
up running. It is very important to remember this project assumes two network
interface cards in each server and further assume that one nic is connected
to a public network and the other nic is connected to a physical switch using
the private IP address. This private network do not need to be routed.


Setup a local ubuntu apt repository
===================================

1. Install apt-mirror::

        apt-get install apt-mirror apache2

2. Create a directory named /apt-mirror to mirror the repository::

        mkdir /apt-mirror

3. Config apt-mirror to use /apt-mirror directory by changing
/etc/apt/mirror.list file::

        set base_path    /apt-mirror

4. Also make sure in /etc/apt/mirror.list file, there are sections like the
following::

        deb http://archive.ubuntu.com/ubuntu trusty main restricted universe multiverse
        deb http://archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse
        deb http://archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse

        deb-src http://archive.ubuntu.com/ubuntu trusty main restricted universe multiverse
        deb-src http://archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse
        deb-src http://archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse

        deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/liberty main

        clean http://archive.ubuntu.com/ubuntu

5. Run apt-mirror which will take a day or two depends on your network
   speed. For a trusty ubuntu release, there will be around 150GB needed::

        apt-mirror

6. After all the packages have been downloaded, create links in /var/www/html
   directory and point to /apt-mirror subdirectories according to your
   settings, for example::

        ln -s /apt-mirror/mirror/archive.ubuntu.com/ubuntu ubuntu
        ln -s /apt-mirror/mirror/ubuntu-cloud.archive.canonical.com/ubuntu/ cubuntu

   The second one was to support openstack liberty packages.

7. For the machines which want to use this local apt repository, change the
   /etc/apt/source.list like the following::

        deb http://repoIP/ubuntu trusty main restricted universe multiverse
        deb http://repoIP/ubuntu trusty-security main restricted universe multiverse
        deb http://repoIP/ubuntu trusty-updates main restricted universe multiverse

        deb-src http://repoIP/ubuntu trusty main restricted universe multiverse
        deb-src http://repoIP/ubuntu trusty-security main restricted universe multiverse
        deb-src http://repoIP/ubuntu trusty-updates main restricted universe multiverse

        deb http://repoIP/cubuntu trusty-updates/liberty main

   Use your local apt repository server IP to replace repoIP in the above
   strings, or setup repoIP in your /etc/hosts. 
   Do apt-get update, then you can install OpenStack as usual.

By default, ubuntu servers will have multiarchitecture enabled. To remove
these annoying apt-get update messages for i386 packages, do the following::

        dpkg --remove-architecture i386
