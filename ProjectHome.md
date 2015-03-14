## Introduction ##

MatPHY is an open source Matlab framework to simulate GSM/EDGE baseband implementations.
It allows access to GSM/EDGE baseband signal processing which is usually hidden in a baseband chipset and not the focus of open source projects. As a second motivation it allows researchers and engineers to test and develop baseband algorithms in conjunction
with higher protocol layers. It allows you to write your own baseband algorithms und run them in conjunction with OsmocomBB.

It natively provides a physical layer (PHY) implementation for GSM/EDGE modems in Matlab with interface to L2/L3 of the OsmocomBB project.

More Info in the Publication section e.g.:
[MatPHY paper SDR 2012](http://link.springer.com/article/10.1007%2Fs11265-013-0762-2)

The following quickstart guide explains how to install and run MatPHY.
The most intuitive way is to use 3 terminals, one for Matlab and phydev,
one for the interface and one for OsmocomBB's bcch\_scan.

## Quickstart Guide ##

open a terminal

download MatPHY
```
$ wget -m -np -nH --cut-dir=2 --reject="index.html" -P matphy
http://matphy.googlecode.com/svn/trunk/
$ chmod u+x matphy/installOBB.sh
```
alternative: `$ svn checkout http://matphy.googlecode.com/svn/trunk/ matphy`

```
$ cd matphy
$ ./installOBB.sh
$ cd phyconnect
$ make
$ ./phyconnect
```

open 2nd terminal

```
$ cd matphy/phydev
$ matlab -nodisplay -r PHY
```

open 3rd terminal

```
$ cd matphy
$ ./osmocom-bb/src/host/layer23/src/misc/bcch_scan -i 127.0.0.1
```

In order to capture GSMTAP packets start Wireshark (in a terminal)
```
$ sudo wireshark
```


## How to develop your baseband algorithm using MatPHY? - An Example ##
In case you want to write your own channel shortening prefilter,
open the detector class (classes/DET.m) place a method with your
algorithm and select your method in the Controller method:

```
[...]
% pre-filtering
if strcmp(obj.DETconf.prefilter,'NONE')
  rx_prefilter = rx;
  chantaps_filtered = chantaps_est;
  elseif strcmp(obj.DETconf.prefilter,'MINPHI')
  [rx_prefilter, chantaps_filtered] = obj.Prefilter_minphi(rx,chantaps_est);
elseif strcmp(obj.DETconf.prefilter,'MMSEDFE')
  [rx_prefilter, chantaps_filtered] = obj.Prefilter_mmsedfe(rx,chantaps_est);
elseif strcmp(obj.DETconf.prefilter,'MyPrefilter')
  [rx_prefilter, chantaps_filtered] = obj.MyPrefilter(rx,chantaps_est);
else
  error('Prefilter type unknown')
end
[...]
```



## Matlab-only mode ##
In addition to the conventional setup with bcch\_scan and phyconnect,
the framework can be run in Matlab only. The script PHYtest.m acts
as L2 in order to run the physical layer (PHY.m).

### Instructions: ###
1st terminal:
```
$ matlab -nodisplay
>>PHYtest
```

2nd terminal:
```
$ matlab -nodisplay
>>PHY
```

The output looks as follows:

1st terminal (PHYtest.m):
```
PHYtest: Copyright (C) 2013 Integrated Systems Laboratory ETHZ (SharperEDGE Team)
This is free software, and you are welcome to redistribute it
under certain conditions; type "help PHYtest" for details.
Documentation: http://matphy.googlecode.com

Mapping file into memory
Tell phydev that phyconnect is ready
Wait for phydev to be ready
phydev is ready
RESET_REQ sent
L1CTL msg of type RESET_CONF received
PM_REQ sent
L1CTL msg of type PM_CONF received
FBSB_REQ sent
L1CTL msg of type FBSB_CONF received
L1CTL msg of type DATA_IND received
L1CTL msg of type DATA_IND received
L1CTL msg of type DATA_IND received
L1CTL msg of type DATA_IND received
L1CTL msg of type DATA_IND received
[...]
```

2nd terminal (PHY.m):
```
PHY: Copyright (C) 2013 Integrated Systems Laboratory ETHZ (SharperEDGE Team)
This is free software, and you are welcome to redistribute it
under certain conditions; type "help PHY" for details.
Documentation: http://matphy.googlecode.com

Mapping file into memory
-------------------------------
-- PHY/L1 Controller started --
-------------------------------

Wait for phyconnect to be ready
phyconnect is ready
Tell phyconnect that phydev is ready
Receiving RESET_REQ
reset type: RES_T_FULL
performing reset
sending RESET_CONF
Receiving PM_REQ
PM type: PM_T_ONE
Performing PM from ARFCN   61 to ARFCN   61
Sending PMs to phyconnect
sending PM_CONF, ARFCN   61, RX_LEV  62
Receiving FBSB_REQ
Performing FBSB on ARFCN 61
FB detected
Correcting frequency offset
Synchronized in frequency to ARFCN 61 with initial frequency error -109.054 Hz
SB detected
Synchronized in time to ARFCN 61, FN 710431, BSIC 5
Sending FBSB_CONF, ARFCN   61 
Sending DATA_IND, ARFCN   61 
Sending DATA_IND, ARFCN   61 
Sending DATA_IND, ARFCN   61 
Sending DATA_IND, ARFCN   61 
[...]
```

DATA\_IND messages are continuously received from the BCCH channel and the output continues until you hit CTRL+C

## Notes ##

It was tested successfully on the following setup
```
Linux ubuntu 2.6.32-40-generic #87-Ubuntu SMP Mon Mar 5 20:26:31 UTC 2012 i686 GNU/Linux

Matlab version: R2009b - 7.9.0.529
```
PHY.m requires a _Communication Toolbox_ license.
PHYTest.m uses the class GsmTap which creates UDP GSMTAP messages. This requires an _Instrument Control Toolbox_ license.

A more detailed guide can be found in the README.txt in the svn trunk

## Related Publications ##
  * _Physical Layer Development Framework for OsmocomBB_ Harald Kröll, Stefan Zwicky, Benjamin Weber, Christian Benkeser, Qiuting Huang

http://link.springer.com/article/10.1007/s11265-013-0762-2

  * _An Efficient Incremental Redundancy Implementation for 2.75 G Evolved EDGE_ Benjamin Weber, Harald Kröll, Christian Benkeser, Qiuting Huang

http://www.benkeser.com/ir_arch.pdf

  * _Baseband Signal Processing Framework for the OsmocomBB GSM Protocol Stack_ Harald Kröll, Christian Benkeser, Stefan Zwicky, Benjamin Weber, Qiuting Huang

http://www.benkeser.com/obbphy.pdf

  * _Efficient Channel Shortening for Higher Order Modulation: Algorithm and Architecture_
Christian Benkeser, Stefan Zwicky, Harald Kröll, Johannes Widmer, Qiuting Huang

http://www.benkeser.com/Homomorphic_Prefilter.pdf

  * _Low-complexity frequency synchronization for GSM systems: Algorithms and implementation_ H Kroll, S Zwicky, C Benkeser, Q Huang, A Burg

http://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=6459659