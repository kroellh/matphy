% DFE.m - DFE class
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

classdef DFE < GsmPhy
    properties
        DFEconf; % Digital front end configuration struct
    end
    
    methods
        %% constructor
        function obj = DFE(config)
            if nargin < 1 % default DFE parameters
                tc.foe.osr = 1;
                tc.foe.festbufsize = 45;  % buffer size in samples for coarse freq. est.
                tc.foe.th_cnt_limit = 3;    % variances to be consecutively under the threshold
                % symbols to calculate the variance over
                tc.foe.varbufsize = floor(tc.foe.festbufsize/tc.foe.th_cnt_limit);     
                tc.foe.var_th = 0.05;
                tc.L_rxpwr = 100; % samples to measure RX power over
                obj.DFEconf = tc;
            else
                obj.DFEconf = config;
            end
        end
        
        
        %% DFE controller
        % Command types:
        %   RXPWR
        %   FSYNCH_FB
        %   RX_NB
        %   RX_SB
        %   arfcn: (Note: only necesary in Software, since otherwise the frequency is set by the DCXO)
        %
        % Reports:
        %  fb
        %  rxpwr
        function rpt = Controller(obj,cmd,tpu)
            
            rpt = [];
            
            switch cmd.type
                
                case 'RXPWR'
                    N = tpu.indexBN;
                    rpt.rxpwr = obj.PM_meas(N,cmd.arfcn); % (dBm)
                    
                case 'FSYNCH_FB'
                    
                    rpt.fb = 0; % default report
                    rpt.fbsbconf.initial_freq_err = 0;
                    bn_cur = 0; % bn counter
                    
                    % set the timeout in BN, cmd.fbsbreq.timeout is in frames
                    bn_max = cmd.fbsbreq.timeout*obj.BURST_DUR_BN*8;
                    
                    fprintf('Performing FBSB on ARFCN %u\n',cmd.fbsbreq.band_arfcn);
                    
                    % send FBSB error back for those ARFCN's without BCCH samples
                    if ~any (obj.ARFCN_vec == cmd.fbsbreq.band_arfcn)
                        fprintf('FBSB detection unsuccessful\n');
                        fprintf('Sending report to phyconnect\n');
                        tpu.jumpBN(bn_max);
                        fbsb.result = 255;
                        return;
                    end
                    
                    % global variable with bcch samples
                    global bcch_samples;
                    global bcch;
                    bcch = bcch_samples{cmd.fbsbreq.band_arfcn};                    
                    
                    % compute symbol index where to perform frequency
                    % synchronization
                    N = tpu.indexBN;
                    
                    %% FBdet
                    % TODO: timeout
                    fb_det = 0;
                    while 1
                        if bn_cur >= bn_max
                            fbsb.result = 255;
                            break;
                        end
                        
                        N = tpu.indexBN;
                        
                        [fb_det fb_pos] = obj.FB_det(N,obj.DFEconf.foe.festbufsize);
                        
                        bn_cur = bn_cur + obj.DFEconf.foe.festbufsize;
                        
                        if fb_det
                            break;
                        end
                        
                        % increment TPU
                        tpu.jumpBN(obj.DFEconf.foe.festbufsize);
                    end
                    %%
                    
                    if fb_det % describe states according to paper
                        fprintf('FB detected\n');
                        fbsb.result = 0;
                        
                        % frequency offset estimation
                        rpt.fbsbconf.initial_freq_err = obj.FB_est(N,obj.DFEconf.foe.festbufsize)-1/obj.BN_P/4;
                        
                        % correct estimated frequency offset
                        fprintf('Correcting frequency offset\n');
                        obj.AFC(rpt.fbsbconf.initial_freq_err);
                        
                        fprintf('Synchronized in frequency to ARFCN %u with initial frequency error %g Hz\n',...
                            cmd.fbsbreq.band_arfcn, rpt.fbsbconf.initial_freq_err);
                        rpt.fb = 1;
                        
                        % synch TPU coarse
                        % count 8 TN before performing SB
                        tpu.jumpBN(8*obj.BURST_DUR_BN);
                        
                        % not enough samples for a SB available
                        if bn_cur + 8*obj.BURST_DUR_BN >= bn_max
                            fbsb.result = 255;
                        end
                    else
                        fprintf('no FB detected\n');
                    end
                case 'RX_NB'
                case 'RX_SB'
                otherwise
                    error('DFE cmd not supported')
            end
        end
        
        %% correct frequency offset (AFC)
        function AFC(obj,freq_offset)
            
            global bcch;
            
            % compute angle step between samples
            angle_step = -freq_offset*2*pi*obj.BN_P;
            
            % create rotation vector
            angle_vec = exp(1i*[0:length(bcch)-1]*angle_step);
            
            bcch = bcch.*angle_vec;
            
        end
        
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % signal processing primitives for the DFE
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %% FB_det() primitive
        function [fb_det, fb_pos] = FB_det(obj,N,L)
            % [fb_det, fb_pos] = FB_det(N,L,tc)
            %
            % Phase Variance based detection algorithm (ex. PhaseVar)
            % used for frequency burst detection
            
            DEBUG = 0;
            global bcch
            
            y = bcch(N:N+L);
            p = angle(y)./pi;
            p_diff = zeros(1,length(y));
            fb_det = 0;
            %fb_pos = inf;
            
            p_u_size = L;
            p_u_buffer = zeros(1,p_u_size); % buffer of the unwrapped phases
            
            var_buf_size = obj.DFEconf.foe.varbufsize*obj.DFEconf.foe.osr; % variance buffer
            var_th = obj.DFEconf.foe.var_th;
            th_cnt_limit = obj.DFEconf.foe.th_cnt_limit;
            
            th_cnt = 0;
            seq_flag = 1; % flag for continuity detection of variances below th.
            
            
            fb_pos = inf;
            
            for i = 2:length(y)
                % calculate the phase difference
                delta = mod(p(i)-p(i-1)+1,2)-1;
                
                p_diff(i-1) = delta;
                p_u_buffer = [p_u_buffer(2:p_u_size) delta+p_u_buffer(p_u_size)];
                
                if ~th_cnt
                    seq_flag = 1;
                end
                
                if i > var_buf_size
                    p_diff_var(i-1) = var(p_diff(i-var_buf_size:i-1));
                    
                    if ~mod(i-1,obj.DFEconf.foe.osr*var_buf_size)
                        if (p_diff_var(i-1) < var_th) && seq_flag
                            th_cnt = th_cnt + 1;
                            % fprintf('\n i: %g, th_cnt: %g \n',i,th_cnt)
                        else
                            seq_flag = 0;
                            th_cnt = 0;
                        end
                    end
                    
                    if th_cnt == th_cnt_limit
                        fb_det = 1;
                        fb_pos = i-var_buf_size*(th_cnt_limit+1);
                        if ~DEBUG
                            break;
                        end
                    end
                else
                    p_diff_var(i-1) = var(p_diff(1:i-1));
                end
            end
            
            
            if DEBUG
                figure(211);
                hold off;
                subplot(3,1,1); plot(p,'+-'); grid on;
                %title(sprintf('SNR: %g dB, varblocksize: %g, OSR %g, fb: %g',...
                %    tc.snr,tc.tx_freqoffset,var_buf_size,fb_det))
                subplot(3,1,2); stem(p_diff); title('phase differences'); grid on;
                subplot(3,1,3); stem(p_diff_var,':'); hold on; grid on;
                stem(var_buf_size:var_buf_size:length(y),p_diff_var(var_buf_size:var_buf_size:end),...
                    'r','LineWidth',2);
                line([0 length(y)],[var_th var_th]);
                title('variance of phase differences')
                grid on;
            end
            
        end
        
        
        
        %% FB_est() primitive
        function freq = FB_est(obj,N,L)
            % [freq] = FB_est(N,L,tc)
            %
            % coarse freq. est. based on lin. reg. using unwrapped phase [Tretter]
            
            global bcch
            
            y = bcch(N:N+L);
            
            OSR = obj.DFEconf.foe.osr;
            %T_sym = tc.tsym;
            T_samp = obj.BN_P/OSR;
            
            p_u_size = L;
            p_u_buffer = zeros(1,p_u_size); % buffer of the unwrapped phases
            p = angle(y)./pi;
            n = -(p_u_size-1)/2:(p_u_size-1)/2;
            
            for i = 2:length(y)
                delta = mod(p(i)-p(i-1)+1,2)-1;
                p_u_buffer = [p_u_buffer(2:p_u_size) delta+p_u_buffer(p_u_size)];
            end
            
            freq = 6/T_samp/(p_u_size*(p_u_size^2-1))*(n*p_u_buffer');
            
            return
        end
        
        
        %% PM_meas() - Signal Power Measurement primitive
        function dBm = PM_meas(obj,N,ARFCN)
            
            DEBUG = 0;
            MULTIPLIER = 1; % multiplier for the power computation out of the samples
            L = obj.DFEconf.L_rxpwr;
            
            % global variable with bcch samples
            global bcch_samples;
            
            % length of bcch samples
            mf_length = length(bcch_samples{ARFCN});
            
            % measure
            rms = 0;
            for i=N:1:N+L
                ind = mod(i,mf_length) + mf_length*(i==mf_length);
                
                if DEBUG
                    fprintf('N %u,L %u, MF_LENGTH %u, ind%u\n',N,L,mf_length,ind);
                end
                
                 % to the power of 4, because we first need to get some kind of power 
                 % and then compute the RMS thereof
                rms = rms + MULTIPLIER*abs(bcch_samples{ARFCN}(ind))^4;
            end
            rms = sqrt(rms/L);
            
            % convert to dBm, assume samples are in mV
            dBm = round(10*log10(rms));
            
            % only measure between -110 dBm and -48 dBm according to 3GPP TS 45.008
            if dBm < -110
                dBm = -110;
            elseif dBm > -48
                dBm = -48;
            end
            
        end
    end
    
end