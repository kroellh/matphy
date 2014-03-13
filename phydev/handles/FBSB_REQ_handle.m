% FBSB_REQ_handle.m - process FBSB_REQ
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

function FBSB_REQ_handle(phyconnect,gsmphy,dfe,det,dec,tpu)

MatPhyConfig;

% initialize/load fbsb struct
fbsbreq = phyconnect.getFBSB_REQ;

% report
info_dl = create_info_dl;
info_dl.band_arfcn = fbsbreq.band_arfcn;

fbsbconf.initial_freq_err   = 0;
fbsbconf.result             = 255;
fbsbconf.bsic               = 0;

cmdDFE.type = 'FSYNCH_FB';
cmdDFE.fbsbreq = fbsbreq;
rptDFE = dfe.Controller(cmdDFE,tpu);

if rptDFE.fb == 1 % FB found
    
    fbsbconf.initial_freq_err = rptDFE.fbsbconf.initial_freq_err;
    cmdDET.type = 'TSYNCH_SB';
    rptDET = det.Controller(cmdDET,tpu);
    dataDET = det.getData();
    dec.setData(dataDET);
    cmdDEC.type = 'SB_DEC';
    rptDEC = dec.Controller(cmdDEC);
    
    if rptDEC.parityd == 0
        
        [info_dl.frame_nr fbsbconf.bsic] = SB_ext(rptDEC.userdata); % extract SB information
        % fbsb.num_biterr = errors;           % number of errors on SB's training sequence
        info_dl.fire_crc = rptDEC.parityd;    % parity check zero is successfull
        fbsbconf.result = 0;                  % result successfull
        
        info_dl.rx_level = 62; % TODO: measure this value
        info_dl.snr = 20;      % TODO: measure this value
        
        % set counters according to SB
        % jump to next frame taking into account sb_offset
        tpu.jumpBN(8*BURST_DUR+rptDET.sb_offset);
        
        old_idx = tpu.indexBN;
        tpu.reset;
        tpu.FN = info_dl.frame_nr+1;  % set FN + 1 (plus 1 because we already jumped to next frame
        new_idx = tpu.indexBN;
        tpu.OffsetBN = old_idx - new_idx; % set offset
        
        % set state of physical layer
        phyconnect.setPhyFsmState(S_SYNCED);
        
        % remember ARFCN of serving BTS
        phyconnect.setARFCN(fbsbreq.band_arfcn);
        % remember BSIC of serving BTS
        phyconnect.setBSIC(fbsbconf.bsic);
        
        % print SB payload info
        fprintf('SB detected\n');
        fprintf('Synchronized in time to ARFCN %u, FN %u, BSIC %u\n',...
            info_dl.band_arfcn,info_dl.frame_nr,fbsbconf.bsic);
        if FBSB_DEBUG
            pause(5);
        end
    else % no SB detected
        fbsbconf.result = 255;
        fprintf('Unable to detect SB after FB');
        %if bn_cur + L_FB + L_SB <= bn_max
        %    fprintf(', waiting for next FB\n');
        %else
            fprintf('\n');
        %end
        if FBSB_DEBUG
            pause(2);
        end
        
        tpu.incTN;
        %bn_cur = bn_cur + obj.BURST_DUR_BN;
    end
else
    tpu.jumpBN(L_FB);
    %bn_cur = bn_cur + L_FB;
end

if fbsbconf.result == 255
    fprintf('FBSB detection unsuccessful\n');
    if FBSB_DEBUG
        pause(5);
    end
end

% send CONF to phyconnect
phyconnect.setFBSB_CONF(info_dl,fbsbconf);

end