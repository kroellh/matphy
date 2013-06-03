% receive_radio_block_handle.m - Receive a radio block and process it
% accordingly. TYPE is DATA_IND, DATA_CONF, or VOICE_IND.
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

function receive_radio_block_handle(phyconnect,TYPE,ARFCN,det,dec,tpu)

% initialization
MatPhyConfig;

info_dl = create_info_dl;
info_dl.band_arfcn = ARFCN;
info_dl.frame_nr = tpu.FN;

% set channel number and link identifier according to 3GPP TS 48.058
% TODO: clean up
fn = tpu.FN;
tn = tpu.TN;
tn = dec2bin(tn,3);
% default values
chan_nr = 0;
link_id = 0;
if ARFCN == phyconnect.getARFCN % receiving radio block on the BCCH carrier, TODO: there are other cases
    if mod(fn,51) == 2 % listening on the BCCH channel, TODO there are other fn for BCCH data
        chan_nr = [ '10000' tn ];
        chan_nr = bin2dec(chan_nr);
        link_id = '00000000'; % TODO: why not 00100000 ???
        link_id = bin2dec(link_id);
    end
end
info_dl.chan_nr = chan_nr;
info_dl.link_id = link_id;
info_dl.snr = 20; % TODO: measure this
info_dl.rx_level = 62; % TODO: measure this

% check whether there exist bcch samples for ARFCN
if ~any (ARFCN_vec == info_dl.band_arfcn)
    % TODO
    return;
end

% global variable with bcch samples
global bcch_samples;
global bcch;
bcch = bcch_samples{info_dl.band_arfcn};

% settings
% Base_params_bcch;

% make sure to use the correct TS as described in 3GPP TS 45.002 and 23.003
if (ARFCN == phyconnect.getARFCN) && (TYPE == phyconnect.DATA_IND) % we are on the bcch carrier and are listening on BCCH or CCCH
    BSIC = phyconnect.getBSIC;
    tmp = dec2bin(BSIC,6);
    tc.tsc = bin2dec(tmp(4:6)); % TS number is BCC, which are the last 3 bits of the BSIC
else
    % TODO, 0 might not always be right
    tc.tsc = 0;
end

% apparantly, this is necessary (see Chan_est.m line 20)
% TODO
tmp = size(bcch);
if tmp(1) > tmp(2)
    bcch = transpose(bcch);
end

%% receiving
% burst-wise
errorsNB = zeros(1,4);
for k = 0:3
    cmdDET.type = 'RX_NB';
    cmdDET.burst_idx = k;
    rptDET = det.Controller(cmdDET,tpu);
    errorsNB(k+1) = rptDET.errorsNB;
    dataDET = det.getData();
    setData(dec,dataDET)
    cmdDEC.type = 'NB_DEC';
    rptDEC = dec.Controller(cmdDEC);
end

if rptDEC.parityd == 0
    info_dl.num_biterr = sum(errorsNB);
    info_dl.fire_crc = 0;
    
    payload = Um2byte(rptDEC.userdata);
    
    phyconnect.putDATA(info_dl,payload,TYPE);
    
else
    fprintf('Unable to decode radio block\n');
end

%% jump counters
tpu.jumpFN(4);

end
