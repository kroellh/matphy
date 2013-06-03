Readme.txt


-------------------
General Description
-------------------

The code of the PHY controller is subdivided into handles. Each
handle deals with an incoming L1CTL message from L2.

TPU: the TPU is implemented in a persistent way via a memory mapped file
but there is no information exchange done via the TPU entries in 
the memory mapped file



Classes in MatPHY:

BTS.m
PhyUnit.m (or MatPhyUnit)
  DFE.m
  DET.m
  DEC.m
TPU.m
PhyConnect.m < mmap


----------------
Feature Requests
----------------

BTS class for generating/loading custom BCCH carriers
e.g.

mybcch = BTS.genBCCH(ARFCN)
mybcch = BTS.loadBCCH(ARFCN) from bursts directory
