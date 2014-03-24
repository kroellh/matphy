% PM_REQ_handle.m - process PM_REQ
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

function PM_REQ_handle(phyconnect,gsmphy,dfe,det,dec,tpu)

MatPhyConfig;

pmreq = phyconnect.getPM_REQ;
% check type of pm request
switch pmreq.type
    case PM_T_ONE
        fprintf('PM type: PM_T_ONE\n');
        exec_PM(phyconnect,gsmphy,dfe,det,dec,tpu,pmreq);
    otherwise
        fprintf('Unknown PM request\n');
end
end


%% execute PM
function exec_PM(phyconnect,gsmphy,dfe,det,dec,tpu,pmreq)

MatPhyConfig;

fprintf('Performing PM from ARFCN %4u to ARFCN %4u\n',pmreq.band_arfcn_from,pmreq.band_arfcn_to);
% adjust state of FSM
switch phyconnect.getPhyFsmState
    case S_NULL
        phyconnect.setPhyFsmState(S_SYNCING);
    case S_SYNCING
        % TODO
    case S_SYNCED
        % TODO
    otherwise
        % TODO
end

% do the measurements according to 3GPP TS 45.008 (PM_NUM measurements per ARFCN)
dBm = zeros(pmreq.band_arfcn_to-pmreq.band_arfcn_from,PM_NUM);
% BN samples per measurement
L = 100; % according to 3GPP TS 45.008, measurements need to be performed over all frequencies, 5 times per frequency evenly spread over 3 to 5 seconds. 100 is more than half a burst and complies with these restrictions
for j=1:PM_NUM
    for arfcn = 1:(pmreq.band_arfcn_to-pmreq.band_arfcn_from+1)
        if PM_DEBUG
            if tpu.TpuDisplay % TODO
                fprintf('Measuring ARFCN %4u at ',arfcn+pmreq.band_arfcn_from-1);
            end
            tpu.display;
            
            if PM_WAIT
                pause(.05);
            end
        end
        % compute current position in 51 multiframe in terms of BN
        N = tpu.indexBN;
        % take measurements
        if any (gsmphy.ARFCN_vec == arfcn+pmreq.band_arfcn_from-1) % measurements from samples
            
            % NEW
            cmdDFE.type = 'RXPWR';
            cmdDFE.arfcn = arfcn+pmreq.band_arfcn_from-1;
            rpt = dfe.Controller(cmdDFE,tpu);
            dBm(arfcn,j) = rpt.rxpwr;
            
        elseif j == 1 % random measurement values
            dBm(arfcn,1:PM_NUM) = randi(PM_RANGE); % stay between PM_RANGE
        end
        % jump tpu
        tpu.jumpBN(L);
    end
end

% send the measurments to phyconnect
fprintf('Sending PMs to phyconnect\n');
for arfcn = 1:(pmreq.band_arfcn_to-pmreq.band_arfcn_from+1)
    flag = arfcn == (pmreq.band_arfcn_to-pmreq.band_arfcn_from+1);
    RX_LEV = pm_process(dBm(arfcn,1:PM_NUM));
    phyconnect.setPM_CONF(arfcn+pmreq.band_arfcn_from-1,RX_LEV,flag);
end
end

%% pm process, average and compute RX_LEV
function rx_lev = pm_process(dBm)

% average measurements
mean_dBm = round(mean(dBm));

% only measure between -110 dBm and -48 dBm according to 3GPP TS 45.008
if mean_dBm < -110
    mean_dBm = -110;
elseif mean_dBm > -48
	mean_dBm = -48;
end

% note that according to 3GPP TS 45.008 there is a SCALE, this is ignored
% here as we do not consider measurement reports
rx_lev = mean_dBm + 110;

end
