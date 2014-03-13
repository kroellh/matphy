% PHY.m - Main layer 1 code
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
fprintf('PHY: Copyright (C) 2013 Integrated Systems Laboratory ETHZ (SharperEDGE Team)\n');
fprintf('This is free software, and you are welcome to redistribute it\n');
fprintf('under certain conditions; type "help PHY" for details.\n');
fprintf('Documentation: http://matphy.osmocom.org\n\n');

%% add paths
addpath('./auxi/');
addpath('./handles/');
addpath('./classes/');

%% instantiate GsmPhy class
gsmphy = GsmPhy;
% TODO: don't use MatPhyConfig anymore
MatPhyConfig;

%% instantiate PhyConnect class
phyconnect = PhyConnect('FileCreate',false);

%% instantiate DFE class
dfe = DFE;

%% instantiate DET class
det = DET;           

%% instantiate DEC class
dec = DEC;

%% load BCCH samples
global bcch_samples;
for i=1:length(gsmphy.ARFCN_vec)
    load(['BCCH_samples/' num2str(gsmphy.ARFCN_vec(i))]);
    % do some scaling
    % TODO: why do we scale???
    bcch_i = (real(bb_data)-mean(real(bb_data)))./max(real(bb_data));
    bcch_q = (imag(bb_data)-mean(imag(bb_data)))./max(imag(bb_data));
    bcch_iq = bcch_i + 1j*bcch_q;
    bcch_samples{gsmphy.ARFCN_vec(i)} = bcch_iq;
end

%% tell phyconnect that phydev is ready and wait for phyconnect to be ready
fprintf('-------------------------------\n');
fprintf('-- PHY/L1 Controller started --\n');
fprintf('-------------------------------\n');
fprintf('\n');

fprintf('Wait for phyconnect to be ready\n');
while 1
    if phyconnect.getPhyconnectReady
        fprintf('phyconnect is ready\n');
        break;
    end
end

fprintf('Tell phyconnect that phydev is ready\n');
phyconnect.setPhydevReady(1); % set phyconnect ready

% Where to decode radio blocks
% FN counter modulo 51
fire = 2; % 2 is the first BCCH frame inside a multiframe

%% PHY/L1 Controller
% implements the PHY FSM

% start TPU
tpuConfig.TpuDisplay = 0;
tpu = TPU(tpuConfig);

%tpu.display;

while 1
    % check whether we are synced to a base station
    if phyconnect.getPhyFsmState == S_SYNCED
        
        % receive a NB when the corresponding frame arrives
        %   NBs are constantly received without waiting
        %   for a L1CTL message. They are sent to the phyconnect
        %   in form of a L1CTL_DATA_IND message.
        %
        %   see  "BCCH Reading" pp32
        if any(mod(tpu.FN,51) == fire)
            receive_radio_block_handle(phyconnect,gsmphy,dfe,det,dec,tpu,phyconnect.getARFCN);
        end
        
        % check for new L1CTL messages from memory mapped file
        if phyconnect.getSynFromL2()
            L1CTLproc; % process L1CTL message
        end
        
        % run tpu
        tpu.display;
        tpu.incFN;
        if SYNC_WAIT
            pause(.1);
        end

    else % not synced
        % check for new messages form phyconnect
        if phyconnect.getSynFromL2()
            L1CTLproc; % process L1CTL message
        end
        % run tpu
        tpu.display;
        tpu.incQN;
    end
end
