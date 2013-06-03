% GsmPhy.m - Parent class for MatPHY containing the necessary constants
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

classdef GsmPhy < handle
    properties
        %% GSM specific timing constants relevant for all PHY units
        QN_P = 1e-6*12/13;              % absolut duration of quarter symbol
        BN_P = 4*1e-6*12/13;            % absolut duration of symbol
        TN_P = 625*4*1e-6*12/13;        % absolut duration of time slot
        FN_P = 8*625*4*1e-6*12/13;      % absolut duration of frame
        BURST_DUR_QN = 625;             % QN samples per burst
        BURST_DUR_BN = 156.25;          % BN samples per burst
        FN_DUR_TN = 8;                  % timeslots per frame
        MF_DUR_FN = 51;                 % frames per multiframe
        QN_MAX = 624;                   % maximum value of QN
        BN_MAX = 156;                   % maximum value of BN
        TN_MAX = 7;                     % maximum value of TN
        FN_MAX = 2715647;               % maximum value of FN
        
        %% BCCH carrier settings
        ARFCN_vec           = [50 61 87];     % ARFCN of the recorded BCCH carrier samples
        N_MF = 8;                       % number of multiframes in bcch samples
        
    end
    methods
    end
end