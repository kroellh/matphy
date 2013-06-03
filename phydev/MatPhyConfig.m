% MatPhyConfig.m - Constants and Settings
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

%% message flags
F_DONE = uint32(1);

%% reset types
RES_T_BOOT  = uint32(0);
RES_T_FULL  = uint32(1);
RES_T_SCHED = uint32(2);

%% FBSB flags
FBSB_F_FB0      = uint32(1);
FBSB_F_FB1      = uint32(2);
FBSB_F_SB       = uint32(4);
FBSB_F_FB01SB   = uint32(7);

%% CCCH mode
CCCH_MODE_NONE          = uint32(0);
CCCH_MODE_NON_COMBINED  = uint32(1);
CCCH_MODE_COMBINED      = uint32(2);

%% PM types
PM_T_ONE    = uint32(1);

%% PHY FSM states
S_NULL      = uint32(0);
S_SYNCING   = uint32(1);
S_SYNCED    = uint32(2);

%% Receiver design parameters
QN_DUR          = 0;            % duration of QN in seconds, for demo only, 0: as fast as phydev can
PM_T_MAX        = 3;            % max time in seconds for PM per ARFCN, must be between 3 and 5s
PM_NUM          = 5;            % number of measurements per ARFCN for averaging
PM_RANGE        = [-110, -55];  % dBm range for random PM, stay between -110 and -48 dBm
FBSB_DUR        = .5;           % max FBSB duration, max .5s
L_FB            = 45;           % window in terms of BN samples used for FB detection
% no longer needed L_SB            = 157;          % SB duration in BN (one timeslot): TODO what about 156.25???
PM_SKIP         = 1;            % only perform PMs on ARFCN 0 through 124 (only works with bcch_scan)

%% BCCH carrier settings
ARFCN_vec           = [50 61 87];     % ARFCN of the recorded BCCH carrier samples
       
%% DEBUG flags
PM_DEBUG    = 1;
FBSB_DEBUG  = 0;
SYNC_WAIT   = 1;
PM_WAIT     = 0;

% TODO: used in FBSB_REQ_handle
BURST_DUR           = 156.25;

QN_P = 1e-6*12/13;  % absolut duration of quarter symbol
BN_P = 4*1e-6*12/13;      % absolut duration of symbol
TN_P = 625*4*1e-6*12/13;  % absolut duration of time slot
FN_P = 8*625*4*1e-6*12/13;      % absolut duration of frame

N_MF            = 8;            % number of multiframes in bcch samples
