------
README
------

Further documentation including a quickstart guide can be found on the
project website: http://code.google.com/p/matphy/

1. Skip this step if you already have the latest version of libosmocore
   installed on your system. Otherwise, download, compile and install
   libosmocore as described here:
   http://bb.osmocom.org/trac/wiki/libosmocore

2. Skip this step if you already have the latest version of OsmocomBB on your
   system. Otherwise you have 2 options of which the first is faster.

   a) Make sure to have all dependencies installed, on debian or ubuntu
      execute in a terminal
      sudo aptitude install libtool shtool autoconf git-core pkg-config make gcc
      Now execute installOBB.sh. in a terminal by typing
      cd <path-to-matphy>
      ./installOBB.sh
      This will download the latest version of OsmocomBB and compile the
      layer 2/3 software only.

   b) Download and compile OsmocomBB as described here:
      http://bb.osmocom.org/trac/wiki/Software/GettingStarted
      Note: This will compile layer 1 firmware which is not required for
      MatPHY to work properly.
   
3. Switch to the phyconnect folder and compile the phyconnect software by
   typing in in a terminal
   cd <path-to-matphy>/phyconnect
   make

4. MatPHY can be run either with a simple layer 2/3 emulator written in Matlab.
   This way, OsmocomBB layer 2/3 software is not required. The necessary steps
   are described in 4a. Alternatively, MatPHY can be run with layer 2/3
   software from the OsmocomBB project. See 4b for a HowTo.

4a.In order to run MatPHY with a simple layer 2/3 emulator you need 2 Matlab
   sessions (start Matlab twice):
   a) In the first session, switch to the phydev folder and run PHYtest (layer
      2/3 emulation) by typing in the Matlab terminal
      cd <path-to-matphy>/phydev
      PHYtest
    
   b) In the second session, switch to the phydev folder an run PHY (layer 1)
      by typing in the Matlab terminal
      cd <path-to-matphy>/phydev
      PHY

4b.In order to run MatPHY with OsmocomBB layer 2/3 software follow these steps:
   a) Open a terminal and switch to the phyconnect folder and execute
      phyconnect by typing
      cd <path-to-matphy>/phyconnect
      ./phyconnect

   b) Open Matlab and switch to the phydev folder and run PHY (layer 1) by
      typing in the Matlab terminal
      cd <path-to-matphy>/phydev
      PHY

   c) Open a terminal and switch to the OsmocomBB folder and execute
      bcch_scan. If you used step 2a) to download and compile OsmocomBB type
      cd <path-to-matphy>/osmocom-bb/src/host/layer23/src/misc
      ./bcch_scan -i 127.0.0.1
      If you did not use step 2a) execute bcch_scan from the corresponding
      directory. The option -i <IP> will send GSMTAB UDP packets to <IP>.
      See http://bb.osmocom.org/trac/wiki/GSMTAP for more information.

5. In order to record BCCH packets in Wireshark follow the steps described in
   http://bb.osmocom.org/trac/wiki/WiresharkIntegration
