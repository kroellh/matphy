% PHYtest.m - This is a test script for bringing the L1 Controller and
% phydev into the "synched to any cell". Acts as a L2 procedure.
%
% Copyright (C) 2013 Integrated System Laboratory ETHZ (SharperEDGE Team)
%
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation, either version 3 of the License, or (at your
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
% Public License for more details.
%
% You should have received a copy of the GNU General Public License along
% with this program.  If not, see <http://www.gnu.org/licenses/>.

clc;
fprintf('PHYtest: Copyright (C) 2013 Integrated Systems Laboratory ETHZ (SharperEDGE Team)\n');
fprintf('This is free software, and you are welcome to redistribute it\n');
fprintf('under certain conditions; type "help PHYtest" for details.\n');
fprintf('Documentation: http://matphy.osmocom.org\n\n');

%% add paths
addpath('./auxi/');
addpath('./classes/');
 
%% intantiate PhyConnect class
phyconnect = PhyConnect;

%% intantiate GsmTap class
gsmtap = GsmTap;

%% handshake
fprintf('Tell phydev that phyconnect is ready\n');
phyconnect.setPhyconnectReady(1);
fprintf('Wait for phydev to be ready\n');
while 1
    if phyconnect.getPhydevReady
        fprintf('phydev is ready\n');
        break;
    end
end

%% (1) send RESET_REQ to PHY
ResetType = 1;
phyconnect.setRESET_REQ(ResetType);
fprintf('RESET_REQ sent\n');


%% wait for RESET_CONF messsage
while true
    if phyconnect.getSynFromL1()
        break;
    end
end
fprintf('L1CTL msg of type %s received\n',phyconnect.getMsgTypeFromL1(true));
phyconnect.setAckToL1
        

%% (2) send PM_REQ
PmReqType = 1;
PmMsg.type = PmReqType;
% OpenBTS ARFCN: 61
% generated ARFCN: 13;
PmMsg.arfcn_start = 61;
PmMsg.arfcn_stop = 61;
phyconnect.setPM_REQ(PmMsg);
fprintf('PM_REQ sent\n');


%% wait for PM_CONF messsage
while true
    if phyconnect.getSynFromL1()
        break;
    end
end
fprintf('L1CTL msg of type %s received\n',phyconnect.getMsgTypeFromL1(true));
phyconnect.setAckToL1


%% (3) send FBSB_REQ
FBSBMsg.band_arfcn = 61;
FBSBMsg.timeout = 100; % as in OsmocomBB's bcch_scan
FBSBMsg.freq_err_thresh1 = 0;
FBSBMsg.freq_err_thresh2 = 0;
FBSBMsg.num_freqerr_avg = 0;
FBSBMsg.flags = 0;
FBSBMsg.sync_infor_idx = 0;
FBSBMsg.ccch_mode = 0;
FBSBMsg.rxlev_exp = 0;

phyconnect.setFBSB_REQ(FBSBMsg);
fprintf('FBSB_REQ sent\n');

%% wait for FBSB_CONF message
while true
    if phyconnect.getSynFromL1()
        break;
    end
end
fprintf('L1CTL msg of type %s received\n',phyconnect.getMsgTypeFromL1(true));
fbsbconf = phyconnect.getFBSB_CONF();
fprintf('FB_est() primitive result: %u Hz\n',fbsbconf.initial_freq_err);
phyconnect.setAckToL1;

%% (4) wait for radio blocks the L1 controller receives on BCCH
while 1
    while true
        if phyconnect.getSynFromL1()
            break;
        end
    end
    fprintf('L1CTL msg of type %s received\n',phyconnect.getMsgTypeFromL1(true));
    if phyconnect.getMsgTypeFromL1() == phyconnect.DATA_IND;
        msg = phyconnect.getDATA();
        gsmtap.osmo(msg);
    end
    phyconnect.setAckToL1;
end
