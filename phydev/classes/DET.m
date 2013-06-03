% DET.m - DET class
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

classdef DET < GsmPhy
    properties
        DETconf; % Detector configuration struct
        DETdata;
    end
    methods
        %% constructor
        function obj = DET(config)
            % default Detector configuration
            if nargin < 1
                
                obj.DETconf.mod = 'GMSK';
                obj.DETconf.modorder = 1;
                obj.DETconf.bursttype = 'SB';
                
                % Prefilter Settings
                obj.DETconf.prefilter = 'MINPHI'; % types: 'NONE', 'MINPHI', 'MMSE-DFE'
                obj.DETconf.p_order = 32; % number of prefilter taps
                
                % RSSE settings
                % process one block (incl. training sequence) in RSSE (1), process two data
                % blocks (2), process two data blocks and training block separately (3)
                obj.DETconf.rsse_ntrell = 1;
                % branch metric calculation in RSSE: 0 = MAX-, 1 = L1-, 2 = L2-norm
                obj.DETconf.rsse_metric = 2;
                % number of subsets into which the signal set is partitioned:
                % dim 1: modulation order
                % dim 2: time (idx=1, most recent symbol, idx=7, oldest symbol)
                % number of trellis states = prod(tc.rsse_nsets(modorder,:))
                obj.DETconf.rsse_nsets = ...
                    [2, 2, 2, 1, 1, 1, 1; ...
                    4, 4, 1, 1, 1, 1, 1; ...
                    8, 1, 1, 1, 1, 1, 1; ...
                    16, 1, 1, 1, 1, 1, 1; ...
                    8, 2, 1, 1, 1, 1, 1];
                
            else
                obj.DETconf = config;
            end
        end
        
        %% Controller
        function rpt = Controller(obj,cmd,tpu)
            
            switch cmd.type
                case 'TSYNCH_SB'
                    global bcch;
                    
                    N = tpu.indexBN;
                    sb_offset = obj.SB_synch(N);
                    N = N+sb_offset;
                    
                    % constants
                    N_TSSB = 64;
                    N_DATASB = 39;
                    N_TAIL = 3;
                    
                    rx = bcch(N:N+2*N_TAIL+2*N_DATASB+N_TSSB-1);
                    
                    % adapt config for TSYNCH_SB
                    obj.DETconf.bursttype = 'SB';
                    obj.DETconf.tsc = 0;
                    
                    % channel estimation
                    chantaps_est = obj.Chan_est(rx,1);
                    
                    % pre-filtering
                    if strcmp(obj.DETconf.prefilter,'NONE')
                        rx_prefilter = rx;
                        chantaps_filtered = chantaps_est;
                    elseif strcmp(obj.DETconf.prefilter,'MINPHI')
                        [rx_prefilter, chantaps_filtered] = obj.Prefilter_minphi(rx,chantaps_est);
                    elseif strcmp(obj.DETconf.prefilter,'MMSEDFE')
                        [rx_prefilter, chantaps_filtered] = obj.Prefilter_mmsedfe(rx,chantaps_est);
                    else
                        error('Prefilter type unknown')
                    end
                    
                    
                    % channel equalization and demodulation
                    rx_rsseall = obj.RSSE(rx_prefilter,chantaps_filtered);
                    
                    % extract information symbols
                    rx_rsse = [rx_rsseall(:,1:39) rx_rsseall(:,104:142)];
                    obj.DETdata = rx_rsse;
                    
                    % report SB offset
                    rpt.sb_offset = sb_offset;
                    
                case 'RX_NB'
                    global bcch
                    
                    % constants
                    N_TSNB = 26;
                    N_DATANB = 58;
                    N_TAIL = 3;
                    
                    N = tpu.indexBN;
                    N = N+cmd.burst_idx*8*obj.BURST_DUR_BN;
                    rx = bcch(N:N+2*N_TAIL+2*N_DATANB+N_TSNB-1);
                    
                    % adapt config for RX_NB
                    obj.DETconf.mcs = 'SACCH';
                    obj.DETconf.ib=184;
                    obj.DETconf.bursttype = 'NB';
                    obj.DETconf.tsc = 5; % TODO

                    % channel estimation
                    chantaps_est = obj.Chan_est(rx,1);
                    
                    % pre-filtering / channel-shortening
                    [rx_prefilter, chantaps_filtered] = obj.Prefilter_minphi(rx,chantaps_est);
                    
                    % channel equalization and demodulation
                    rx_rsseall = obj.RSSE(rx_prefilter,chantaps_filtered);
                    
                    % extract information symbols
                    rx_rsse = [rx_rsseall(:,1:58) rx_rsseall(:,85:142)];
                    
                    obj.DETdata = rx_rsse;
                    
                    % compute errors in training sequence
                    ts = obj.Training_sequences('GMSK','NB',obj.DETconf.tsc);
                    errors26 = sum(rx_rsseall(:,59:84) ~= -2*ts+1);
                    % interpolate
                    errors = round(errors26*156/26);
                    
                    % report errors
                    rpt.errorsNB = errors;
                    
                otherwise
                    error('Detector command type unknown')
            end
        end
        
        %% detData - return detected Data
        function data =  getData(obj)
            data =  obj.DETdata;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % signal processing primitives for DET
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %% SB_synch - synchronization in time
        function SB_offset = SB_synch(obj,N)
            
            global bcch
            
            % constants
            N_TSSB = 64;
            N_DATASB = 39;
            N_TAIL = 3;
            
            SB_PRERANGE = 30;
            SB_POSTRANGE = 30;
            
            % generate TS
            training_symb = obj.Training_sequences('GMSK','SB',[]);
            
            ts_map = obj.Symbol_mapping(training_symb,'GMSK',1,1,64,3);
            [ts_mod groupdelay glen] = obj.Pulse_GMSK(ts_map,1,64,obj.BN_P,1);
            ts_mod = -ts_mod(:,groupdelay+1:end-groupdelay);
            
            corr_in = bcch(N-SB_PRERANGE:N+N_TSSB+SB_POSTRANGE);
            
            cross_corr = conv(fliplr(conj(ts_mod)),corr_in);
            [~,pos_reg] = max(abs(cross_corr));
            
            SB_offset = pos_reg-N_TSSB-N_DATASB-N_TAIL-SB_PRERANGE;
            
            return
        end
        
        
        %% Chan_est - Channel Estimation
        function taps_est = Chan_est(obj,input,OSR)
            
            % number of symbol-spaced channel taps estimated
            len_chanest = 8;
            
            tsym = obj.BN_P;
            nobursts = size(input,1); % number of bursts
            bursttype = obj.DETconf.bursttype;
            modtype = obj.DETconf.mod;
            modorder = obj.DETconf.modorder;
            tsc = obj.DETconf.tsc; % training sequence code
            
            if modorder == 1
              chest_overall = 0;
            else
              chest_overall = 1;
            end
            
            switch bursttype
                case 'SB'
                    % extract received training sequence
                    ts_rec = input(:,42*OSR+1:106*OSR);
                case 'NB'
                    % extract received training sequence
                    ts_rec = input(:,61*OSR+1:87*OSR);
                case 'HB'
                    % extract received training sequence
                    ts_rec = input(:,73*OSR+1:104*OSR);
            end
            
            % Generation of Training Sequence
            % one row of training sequence
            ts1 = obj.Training_sequences(modtype,bursttype,tsc);
            % nobursts rows of training sequence
            ts = ts1(ones(1,nobursts),:);
            nosymbs = size(ts,2)/modorder;
            nodummysymbs = 0;
            
            % symbol mapping
            ts_map = obj.Symbol_mapping(ts,modtype,modorder,nobursts,nosymbs,nodummysymbs);
            
            % pulse shaping
            switch modtype
                case 'GMSK'
                    [ts_mod groupdelay glen] = obj.Pulse_GMSK(ts_map,nobursts,nosymbs,tsym,OSR);
                    ts_mod = ts_mod(:,groupdelay*OSR+1:end-groupdelay*OSR);
                    if ~strcmp('SB',bursttype)
                        % the phase shift between the first symbol of ts_mod and the first
                        % symbol of the received burst is -pi/2, so we have to rotate
                        % ts_mod by pi/2 (there is no phaseshift in the case of a SB with
                        % less data symbols)
                        ts_mod = ts_mod.*exp(pi/2*1i);
                    else
                        ts_mod = -ts_mod;
                    end
                case {'8PSK'}
                    % the phase shift between the first symbol of each burst and the
                    % first TS symbol is always 3*1i*3pi/8. Therefore, an additional
                    % rotation of -3*3pi/8 is necessary.
                    ts_map = ts_map .* exp(7*pi/8*1i);
                    ts_mod = Pulse_linGMSK(ts_map,nobursts,nosymbs,OSR,bursttype,tsym);
                case {'16QAM'}
                    % the phase shift between the first symbol of each burst and the
                    % first TS symbol is always 3*1i*pi/4. Therefore, an additional
                    % rotation of -3*pi/4 is necessary.
                    ts_map = ts_map .* exp(-3*1i*pi/4);
                    ts_mod = Pulse_linGMSK(ts_map,nobursts,nosymbs,OSR,bursttype,tsym);
                case {'32QAM'}
                    % the phase shift between the first symbol of each burst and the
                    % first TS symbol is always -3*1i*pi/4. Therefore, an additional
                    % rotation of 3*pi/4 is necessary.
                    ts_map = ts_map .* exp(3*1i*pi/4);
                    ts_mod = Pulse_linGMSK(ts_map,nobursts,nosymbs,OSR,bursttype,tsym);
            end
            
            if chest_overall == 0
                ts_cmp = ts_mod;
            else
                ts_cmp = ts_map;
            end
            
            % Channel estimation
            taps_est = [obj.Channel_estimator(ts_rec,ts_cmp,len_chanest,OSR) zeros(nobursts,(8-len_chanest)*OSR)];
            
        end
        
        %% LS Channel_estimator
        function taps_est = Channel_estimator(obj,ts_rec,ts_cmp,len_chanest,OSR)
            nobursts = size(ts_rec,1); % number of bursts
            tslen = size(ts_rec,2);
            
            % number of taps before main tap to be considered
            offset = 1;
            
            N = 0; % additional taps before actual estiamte
            L = len_chanest+N;
            ign = 0; % ignore bits
            for k=1:nobursts
                C = toeplitz(ts_cmp(k,OSR*(L+ign):tslen*OSR),fliplr(ts_cmp(k,1+ign*OSR:OSR*(L+ign))));
                Ci = (C'*C)^-1*C';
                temp = (Ci*ts_rec(k,(L+ign)*OSR-offset-N:tslen*OSR-offset-N).').';
                taps_est(k,:) = temp(N+1:end);
            end
        end
        
        %% Prefilter MINPHI - Channel Shortener
        % according to: W. Gerstacker:
        % 'An Efficient Method for Prefilter Computation for Reduced-State Equalization', 2000
        % Principle:
        % WHITENING MATCHED FILTER = MATCHED FILTER (A1) + NOISE WHITENING FILTER (A2=P)
        function [bursts_filtered, chantaps_filtered] = Prefilter_minphi(obj,input,chantaps)
            
            nobursts = size(input,1);
            p_order = obj.DETconf.p_order; % pre-filter order
            
            A1 = fliplr(conj(chantaps));  % matched filter
            hlen = size(chantaps,2);
            chantaps_filtered = zeros(size(chantaps));
            bursts_filtered = zeros(size(input));
            
                for k=1:nobursts
                    phi2sided = conv(chantaps(k,:), fliplr(conj(chantaps(k,:))));
                    phi = phi2sided(hlen:end);
                    L = size(phi,2); % = hlen
                    H=toeplitz([phi zeros(1,p_order-L)], [phi(1) conj(phi(2:end)) zeros(1,p_order-L)]);
                    Hinv = inv(H);
                    P = [-phi(2:end) zeros(1,p_order-L+1)] * conj(Hinv);
                    A2 = [fliplr(conj(P)) 1];
                    filtertaps = conv(A1(k,:), A2); % impulse response of prefilter
                    max_filter = max(abs(filtertaps));
                    shift = floor(log2(max_filter^(-1)));
                    filtertaps = filtertaps*2^shift;
                    filtertaps = filtertaps(1+hlen:end);
                    filtchan = conv(filtertaps,chantaps(k,:)); % impulse response of channel + prefilter
                    flen = length(filtertaps);
                    h_filt = filtchan(flen:end);
                    NBurstPre1 = conv(filtertaps,input(k,:));
                    NBurst_filt = NBurstPre1(flen:end);
                    
                    chantaps_filtered(k,:) = h_filt;
                    bursts_filtered(k,:) = NBurst_filt;
                end
        end
        
        
        %% Prefilter MMSE-DFE - Channel Shortener
        % MMSE-DFE-type according to: N.Al-Dhahir:
        % 'Fast Computation of Channel-Estimate Based Equalizers
        % in Packet Data Transmission' 1995
        function [bursts_filtered, chantaps_filtered] = Prefilter_mmsedfe(obj,input,chantaps)
            p_order = obj.DETconf.p_order;
            kf = p_order;
            for k=1:nobursts
                % generate H
                H = zeros(hlen-1+kf,kf);
                H(:) = [repmat([chantaps(k,:) zeros(1,kf)],1,kf-1) chantaps(k,:)];
                H = H.';
                % compute Cholesky matrix and its lower triangular matrix (Diagonal
                % form A = LDL')
                R = nu * eye(kf+hlen-1) + H'*H;
                L = ldl(R);
                % evaluate bopt and wopt
                b = L(:,kf);
                w = b'*inv(R)*H';
                % compute filter taps
                chantaps_f = conv(w,chantaps(k,:));
                chantaps_filtered(k,:) = chantaps_f(end-hlen+1:end);
                % filter bursts
                bursts_f = conv(w,input(k,:));
                bursts_filtered(k,:) = bursts_f(end-size(input,2)+1:end);
            end
        end
        
        
        %% Equalizer - Reduced-State Sequence Estimator
        function bit_sequence = RSSE(obj,rx_symbols,chantaps_filtered)
            
            tc = obj.DETconf;
            
            switch tc.bursttype
                case 'NB'
                    nTailSymb = 3;
                    nInfoSymb = 58;
                    nTrainingSymb = 26;
                    switch tc.mod
                        case 'GMSK'
                            tailSymb = zeros(1,3);
                        case '8PSK'
                            tailSymb = 7*ones(1,3);
                        case '16QAM'
                            tailSymb = [1,6,6];
                        case '32QAM'
                            tailSymb = [30,14,14];
                    end
                case 'HB'
                    nTailSymb = 4;
                    nInfoSymb = 69;
                    nTrainingSymb = 31;
                    switch tc.mod
                        case 'QPSK'
                            tailSymb = [0,1,3,2];
                        case '16QAM'
                            tailSymb = [1,6,6,13];
                        case '32QAM'
                            tailSymb = [30,30,14,14];
                    end
                case 'SB'
                    nTailSymb = 3;
                    nInfoSymb = 39;
                    nTrainingSymb = 64;
                    tailSymb = zeros(1,3);
                otherwise
                    error('Bursttype not supported')
            end
            
            switch tc.mod
             case 'GMSK'
              phaseIncr = -pi/2;
              symbOrd = [0;1];
             case 'QPSK'
              phaseIncr = 3*pi/4;
              symbOrd = [0;3;1;2];
             case '8PSK'
              phaseIncr = 3*pi/8;
              symbOrd = [0;6;3;5;1;7;2;4];
             case '16QAM'
              phaseIncr = pi/4;
              symbOrd = [0;15;5;10;6;9;3;12;4;11;1;14;7;8;2;13];
             case '32QAM'
              phaseIncr = -pi/4;
              symbOrd = [0;22;14;25; ...
                         13;21;17;26;...
                         4;18;28;11;...
                         3;8;7;31;...
                         1;10;5;29;...
                         6;16;30;9;...
                         2;20;12;27;...
                         15;23;19;24];
            end
            
            % number of subsets into which the signal set is partitioned.
            nSets = tc.rsse_nsets(tc.modorder,:);
            
            % offset of main tap in channel estimate
            chEstOffset = 1;
            
            % get training sequence to use it as tail symbols if received symbols are
            % not processed in one single trellis
            if tc.rsse_ntrell > 1
                tsBin = obj.Training_sequences(tc.mod,tc.bursttype,tc.tsc);
                ts = my_bi2de_lmsb(reshape(tsBin,tc.modorder,[]).').';
            end
            
            % total number of symbols
            nSymbolsTotal = 2*nTailSymb + 2*nInfoSymb + nTrainingSymb;
            % number of trellis states
            nStates = prod(nSets);
            % number of trellis edges
            nEdges = nSets(1);
            % number of symbols contained in the symbol history of a state
            L = length(nSets);
            % number of symbols contained in one subset
            nSymbPerSubset = 2^tc.modorder./nSets;
            % number of parallel branches (one edge has nParEdges parallel branches,
            % corresponding to different symbols of the same subset)
            nParEdges = nSymbPerSubset(1);
            % get symbol look-up table of current modulation order
            LUT = obj.getLUT(tc.modorder,obj.BN_P,L+1);
            % number of bursts
            nBursts = size(rx_symbols,1);
            % initialize output
            bit_sequence = zeros(nBursts,tc.modorder*(nSymbolsTotal-2*nTailSymb));
            
            % some checks
            if any(nSets ~= 2.^floor(log2(nSets)))
                error('Number of sets must be a power of 2.')
            end
            if L > nTailSymb && nSets(nTailSymb+1) > 1
                % there is more than one start state
                error('Current implementation does not support more than one starting state')
            end
            if size(chantaps_filtered,2) < (L+1)
                error('Not enough channel taps for this RSSE configuration.')
            end
            
            
            %--------------------------------------------------------------------------
            % Construction of trellis
            %--------------------------------------------------------------------------
            
            % portion (bits) of previous state which remains part of present state
            % (subsets are merged -> bits are omitted)
            states = 0:(nStates-1);
            tmp = zeros(1,nStates);
            for k = 2:L
                tmp2 = prod(nSets(1:(k-1)));
                tmp = tmp + tmp2*mod(floor(states/tmp2*nSets(k)), nSets(k));
            end
            % construct subset trellis: 1. dim = current states, 2. dim = prev. states
            % with connection to present state
            trellis = zeros(nStates,nEdges);
            for k = 1:nStates
                trellis(k,:) = find(tmp==floor((k-1)/nSets(1))*nSets(1))-1;
            end
            
            %--------------------------------------------------------------------------
            % Loop over bursts
            %--------------------------------------------------------------------------
            for burst = 1:nBursts
                % initialize vector for estimated symbol sequence
                symbSequence = zeros(1,nSymbolsTotal);
                if tc.modorder ~= 1
                    % precalculation of direct term (first channel tap * symbol
                    % corresponding to edge), only possible for non-GMSK modulation
                    directTermPre = LUT(symbOrd+1).'*chantaps_filtered(burst,1);
                end
                
                %----------------------------------------------------------------------
                % Loop over separate trellises
                %----------------------------------------------------------------------
                for t = 1:tc.rsse_ntrell
                    if t == 1
                        % first trellis, start from beginning of burst
                        startSymb = tailSymb;
                        nStartSymb = nTailSymb;
                        rxSymbOffset = 0;
                        if tc.rsse_ntrell > 1
                            % first portion of information symbols
                            stopSymb = ts(1:L);
                            nStopSymb = L;
                            nSymbols = nStartSymb + nStopSymb + nInfoSymb;
                        else
                            % only one trellis, do complete burst
                            stopSymb = tailSymb;
                            nStopSymb = nTailSymb;
                            nSymbols = nSymbolsTotal;
                        end
                    elseif t == 2
                        % second portion of information symbols
                        startSymb = ts((end-L+1):end);
                        nStartSymb = L;
                        stopSymb = tailSymb;
                        nStopSymb = nTailSymb;
                        rxSymbOffset = nTailSymb + nInfoSymb + nTrainingSymb - nStartSymb;
                        nSymbols = nStartSymb + nStopSymb + nInfoSymb;
                    else
                        % training symbols, use previously estimated information
                        % symbols as start and stop symbols
                        startSymb = symbSequence((1:L)+nTailSymb+nInfoSymb-L);
                        nStartSymb = L;
                        stopSymb = symbSequence((1:L)+nTailSymb+nInfoSymb+nTrainingSymb-L);
                        nStopSymb = L;
                        rxSymbOffset = nTailSymb+nInfoSymb-nStartSymb;
                        nSymbols = nStartSymb + nStopSymb + nTrainingSymb;
                    end
                    % extract received symbols which are used for current trellis
                    rxSymbs = rx_symbols(burst,rxSymbOffset+(1:nSymbols));
                    % initialize symbol path with start symbols
                    symbPath = zeros(nStates,nSymbols);
                    symbPath(:,1:nStartSymb) = startSymb(ones(1,nStates),:);
                    % find start/stop state, based on start/stop symbols
                    startState = 0;
                    for k = 1:nStartSymb
                        startSymbIdx = find(symbOrd == startSymb(nStartSymb+1-k))-1;
                        startSubsetIdx = floor(startSymbIdx/nSymbPerSubset(k));
                        startState = startState + startSubsetIdx*prod(nSets(1:(k-1)));
                    end
                    stopState = 0;
                    for k = 1:nStopSymb
                        stopSymbIdx = find(symbOrd == stopSymb(nStopSymb+1-k))-1;
                        stopSubsetIdx = floor(stopSymbIdx/nSymbPerSubset(k));
                        stopState = stopState + stopSubsetIdx*prod(nSets(1:(k-1)));
                    end
                    % initialize state metric
                    stateMetric = inf*ones(nStates,1);
                    stateMetric(startState+1) = 0;
                    
                    %------------------------------------------------------------------
                    % Loop over symbols / trellis stages
                    %------------------------------------------------------------------
                    for k = (nStartSymb+1):nSymbols
                        % keep a copy of old state metric and symbol path
                        stateMetricOld = stateMetric;
                        symbPathOld = symbPath;
                        % indices of symbols in symbol path which are considered
                        if k <= L
                            idx = 1:(k-1);
                        else
                            idx = (k-L):(k-1);
                        end
                        if tc.modorder ~= 1
                            % calculation of ISI term, based on symbol path, only
                            % possible for non-GMSK modulation
                            symbPathMod = LUT(symbPathOld(:,idx)+1);
                            % apply phase rotation
                            phaseArray = exp(1i.*(idx-1+rxSymbOffset).*phaseIncr);
                            symbPathMod = symbPathMod.*phaseArray(ones(1,nStates),:);
                            isiTerm = sum(symbPathMod.*fliplr(chantaps_filtered(burst*ones(1,nStates),2:(length(idx)+1))),2);
                            % use precalculated direct term and apply phase rotation
                            directTerm = directTermPre.*exp(1i*(k-1+rxSymbOffset)*phaseIncr);
                        end
                        %------------------------------------------------------------------
                        % Loop over trellis states
                        %------------------------------------------------------------------
                        for state = 1:nStates
                            % find subset to which the current state belongs
                            currentSubset = mod((state-1),nSets(1));
                            % find previous states that have a connection to the current state
                            prevStates = trellis(state,:);
                            % find indices of the symbols corresponding to the parallel edges connected to current state
                            parEdges = currentSubset*nParEdges+(0:(nParEdges-1));
                            % replicate previous states depending on number of parallel edges
                            prevStatesRep = prevStates(floor((0:(nParEdges*nEdges-1))/nParEdges).'+1);
                            % replicate parallel edges depending on number of previous states
                            parEdgesRep = parEdges(mod(0:(nParEdges*nEdges-1),nParEdges).'+1);
                            % calculate branch metric
                            if tc.modorder == 1
                                % construct refernece sequence: index (1): oldest
                                % symbol in history, index (end): newest symbol
                                refSeq = [symbPathOld(prevStatesRep+1,idx) ...
                                    symbOrd(parEdgesRep+1)];
                                % Get GMSK modulated sequence. The sequence is
                                % 'left-aligned' to have the same initial state of the
                                % modulator as thte data burst.
                                gmskSeq = LUT(obj.my_bi2de_lmsb(refSeq)*2^(L-length(idx))+1, ...
                                    1:(length(idx)+1));
                                if L ~= length(idx)
                                    % the extract of the complete LUT sequence is
                                    % 'left-aligned'. We have to rotate according
                                    % to the number of symbols which have been
                                    % omitted at the 'right end'.
                                    gmskSeq = gmskSeq*exp(-1i*phaseIncr*(L-length(idx)));
                                end
                                % Convolution with channel to get the reference symbol.
                                % The last symbol of the reference sequence is omitted
                                % if the channel is estimated without offset.
                                refSymb = sum(gmskSeq(:,1:(length(idx)+chEstOffset)) ...
                                    .*fliplr(chantaps_filtered(burst*ones(1,nParEdges*nEdges), ...
                                    1:(length(idx)+chEstOffset))),2);
                                % apply phase rotation to received symbol
                                rxSymbol = rxSymbs(k-1)* ...
                                    exp(1i*phaseIncr*(k-1+rxSymbOffset));
                            else
                                % combine ISI term and direct term to get the reference
                                % symbol
                                refSymb = isiTerm(prevStatesRep+1) + directTerm(parEdgesRep+1);
                                rxSymbol = rxSymbs(k-chEstOffset);
                            end
                            % difference of reference and received symbol
                            diffSymb = refSymb - rxSymbol;
                            % branch metric
                            if tc.rsse_metric == 0 % L-infinity norm
                                branchMetrics = max(abs(real(diffSymb)),abs(imag(diffSymb)));
                            elseif tc.rsse_metric == 1 % L1 norm
                                branchMetrics = abs(real(diffSymb)) + abs(imag(diffSymb));
                            elseif tc.rsse_metric == 2 % L2 norm
                                branchMetrics = abs(diffSymb).^2;
                            else
                                error('tc.rsse_metric not supported.')
                            end
                            
                            % candidates for next state metric
                            tempMetric = branchMetrics + stateMetricOld(prevStatesRep+1);
                            
                            if k > (nSymbols - nStopSymb)
                                % The transmitted symbol corresponding to the incoming
                                % branches is known. Set branch metric to infinity if
                                % the symbols do not match
                                tempMetric(symbOrd(parEdgesRep+1) ~= stopSymb(k-nSymbols+nStopSymb)) = inf;
                            end
                            
                            % select the branch with minimal metric
                            [stateMetric(state) bestIdx] = min(tempMetric);
                            
                            % previous state corresponding to the winning edge
                            bestPrevState = prevStatesRep(bestIdx);
                            % index of best edge within array of all parallel edges
                            bestEdgeIdx = mod(bestIdx-1,nParEdges)+1;
                            % update symbol path
                            symbPath(state,1:k) = [symbPathOld(bestPrevState+1,1:(k-1)), ...
                                symbOrd(currentSubset*nParEdges+bestEdgeIdx)];
                            
                        end % end of state loop
                        
                    end % end of symbol loop
                    
                    % Back-trace is done by selecting the symbol path of the
                    % stop-state. This is equivalent to choose the  state with minimal
                    % metric (there should be just one state with metric < inf)
                    bestPath = symbPath(stopState+1,:);
                    
                    % discard tail symbols
                    symbSequence((1:nSymbols)+rxSymbOffset) = bestPath;
                    
                end % end of trellis loop
                
                % convert best path to NRZ binary sequence
                bit_sequence(burst,:) = obj.bin2nrz(reshape(obj.my_de2bi_lmsb( ...
                    symbSequence(nTailSymb+1:end-nTailSymb).',tc.modorder).',1,[]));
                
            end % end of burst loop
            
        end
        
        
        %% LUT for Equalizer
        function LUT = getLUT(obj,modOrder,tsymb,gmskL)
            switch modOrder
                case 1
                    GMSKSeq = zeros(2^gmskL,gmskL);
                    for i = 1:2^gmskL
                        seq =  obj.my_de2bi_lmsb((i-1),gmskL);
                        d(1) = mod(seq(1)+1,2);
                        d(2:gmskL) = mod(seq(2:gmskL)+seq(1:gmskL-1),2);
                        sihat = 1-2*d;
                        [seqMod groupdelay] = obj.Pulse_GMSK(sihat,1,gmskL,tsymb,1);
                        GMSKSeq(i,:) = seqMod((groupdelay+1):(end-groupdelay));
                    end
                    % shift phase to align with second last symbol (position of main
                    % channel tap)
                    LUT = GMSKSeq.*exp(-pi/2*7*1i);
                case 2
                    tab4 = [1+1i 1-1i -1+1i -1-1i];
                    LUT = tab4./sqrt(2);
                case 3
                    tab8 = [3 4 2 1 6 5 7 0];
                    LUT = exp(1i.*tab8.*pi./4);
                case 4
                    tab16 = [1+1i 1+3*1i 3+1i 3+3*1i 1-1i 1-3*1i 3-1i 3-3*1i ...
                        -1+1i -1+3*1i -3+1i -3+3*1i -1-1i -1-3*1i -3-1i -3-3*1i];
                    LUT = tab16./sqrt(10);
                case 5
                    tab32 = [-3-5*1i -1-5*1i -3+5*1i -1+5*1i -5-3*1i -5-1*1i -5+3*1i -5+1*1i ...
                        -1-3*1i -1-1*1i -1+3*1i -1+1*1i -3-3*1i -3-1*1i -3+3*1i -3+1*1i ...
                        3-5*1i 1-5*1i 3+5*1i 1+5*1i 5-3*1i 5-1*1i 5+3*1i 5+1*1i ...
                        1-3*1i 1-1*1i 1+3*1i 1+1*1i 3-3*1i 3-1*1i 3+3*1i 3+1*1i];
                    LUT = tab32/sqrt(20);
                otherwise
                    error('Modulation order not implemented yet.')
            end
        end
        
    end
    
    methods(Static)
        
    
        %% my_bi2de_lmsb
        function d = my_bi2de_lmsb(b)
            d = b*2.^((size(b,2)-1):-1:0).';
        end
        
        
        %% my_de2bi_lmsb
        function b = my_de2bi_lmsb(d,n)
            b = zeros(size(d,1),n);
            for k = 1:n
                step = 2^(n-k);
                tmp = (d >= step);
                b(:,k) = tmp;
                d = d - step*tmp;
            end
        end
        
        
        %% Training sequences
        function training = Training_sequences(modtype,bursttype,tsc)
            
            tsc_set=1;
            
            % training sequence
            switch bursttype
                case 'NB'
                    if tsc_set == 1
                        switch tsc
                            case 0
                                tseq=[0,0,1,0,0,1,0,1,1,1,0,0,0,0,1,0,0,0,1,0,0,1,0,1,1,1];
                            case 1
                                tseq=[0,0,1,0,1,1,0,1,1,1,0,1,1,1,1,0,0,0,1,0,1,1,0,1,1,1];
                            case 2
                                tseq=[0,1,0,0,0,0,1,1,1,0,1,1,1,0,1,0,0,1,0,0,0,0,1,1,1,0];
                            case 3
                                tseq=[0,1,0,0,0,1,1,1,1,0,1,1,0,1,0,0,0,1,0,0,0,1,1,1,1,0];
                            case 4
                                tseq=[0,0,0,1,1,0,1,0,1,1,1,0,0,1,0,0,0,0,0,1,1,0,1,0,1,1];
                            case 5
                                tseq=[0,1,0,0,1,1,1,0,1,0,1,1,0,0,0,0,0,1,0,0,1,1,1,0,1,0];
                            case 6
                                tseq=[1,0,1,0,0,1,1,1,1,1,0,1,1,0,0,0,1,0,1,0,0,1,1,1,1,1];
                            case 7
                                tseq=[1,1,1,0,1,1,1,1,0,0,0,1,0,0,1,0,1,1,1,0,1,1,1,1,0,0];
                            otherwise
                                error('TSC not allowed!')
                        end
                    else
                        switch tsc
                            case 0
                                tseq=[0,1,1,0,0,0,1,0,0,0,1,0,0,1,0,0,1,1,1,1,0,1,0,1,1,1];
                            case 1
                                tseq=[0,1,0,1,1,1,1,0,1,0,0,1,1,0,1,1,1,0,1,1,1,0,0,0,0,1];
                            case 2
                                tseq=[0,1,0,0,0,0,0,1,0,1,1,0,0,0,1,1,1,0,1,1,1,0,1,1,0,0];
                            case 3
                                tseq=[0,0,1,0,1,1,0,1,1,1,0,1,1,1,0,0,1,1,1,1,0,1,0,0,0,0];
                            case 4
                                tseq=[0,1,1,1,0,1,0,0,1,1,1,1,0,1,0,0,1,1,1,0,1,1,1,1,1,0];
                            case 5
                                tseq=[0,1,0,0,0,0,0,1,0,0,1,1,0,1,0,1,0,0,1,1,1,1,0,0,1,1];
                            case 6
                                tseq=[0,0,0,1,0,0,0,0,1,1,0,1,0,0,0,0,1,1,0,1,1,1,0,1,0,1];
                            case 7
                                tseq=[0,1,0,0,0,1,0,1,1,1,0,0,1,1,1,1,1,1,0,0,1,0,1,0,0,1];
                            otherwise
                                error('TSC not allowed!')
                        end
                    end
                    if strcmp(modtype,'GMSK')
                        training = tseq;
                    else
                        switch modtype
                            case '8PSK'
                                tsymb1 = [1 1 1];
                                tsymb2 = [0 0 1];
                            case '16QAM'
                                tsymb1 = [1 1 1 1];
                                tsymb2 = [0 0 1 1];
                            case '32QAM'
                                tsymb1 = [0 0 0 0 0];
                                tsymb2 = [1 0 0 1 0];
                            otherwise
                                error('Wrong modulation!')
                        end
                        training = [];
                        for k=1:size(tseq,2)
                            if tseq(k) == 0
                                training = [training tsymb1];
                            else
                                training = [training tsymb2];
                            end
                        end
                    end
                case 'SB'
                    % extended training sequence used for SCH
                    tseq=[1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1];
                    training = tseq;
                case 'HB'
                    switch tsc
                        case 0
                            tseq=[0,1,0,0,1,0,0,0,1,0,1,1,1,1,1,1,1,0,0,1,0,1,1,1,1,0,0,1,1,1,0];
                        case 1
                            tseq=[1,1,1,0,0,1,1,0,0,0,1,1,1,1,1,0,1,0,1,1,0,1,0,0,0,1,0,0,1,0,0];
                        case 2
                            tseq=[1,0,0,1,1,1,0,1,1,1,0,0,1,0,1,1,0,1,1,1,1,1,0,0,0,1,0,1,0,0,0];
                        case 3
                            tseq=[0,0,0,0,1,1,1,0,0,0,0,0,0,1,0,0,1,1,1,0,1,0,1,1,0,0,1,0,1,0,0];
                        case 4
                            tseq=[1,0,1,0,0,1,1,1,0,0,0,1,1,0,1,1,0,0,1,0,1,1,1,1,1,1,1,0,1,0,0];
                        case 5
                            tseq=[0,0,1,0,1,0,0,1,1,0,1,0,1,1,1,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0];
                        case 6
                            tseq=[1,0,1,1,1,1,1,1,0,1,1,0,1,0,0,0,1,1,1,0,1,1,0,0,0,1,1,1,0,1,0];
                        case 7
                            tseq=[1,0,1,1,1,1,1,0,1,1,0,1,0,1,1,1,0,0,0,0,1,1,0,1,1,1,0,1,1,0,0];
                        otherwise
                            error('TSC not allowed!')
                    end
                    switch modtype
                        case 'QPSK'
                            tsymb1 = [0 0];
                            tsymb2 = [1 1];
                        case '16QAM'
                            tsymb1 = [0 0 1 1];
                            tsymb2 = [1 1 1 1];
                        case '32QAM'
                            tsymb1 = [1 0 0 1 0];
                            tsymb2 = [0 0 0 0 0];
                        otherwise
                            error('Wrong modulation!')
                    end
                    training = [];
                    for k=1:size(tseq,2)
                        if tseq(k) == 0
                            training = [training tsymb1];
                        else
                            training = [training tsymb2];
                        end
                    end
                otherwise
                    error('Bursttype not allowed!')
            end
        end
        
        
        %% Symbol_mapping
        function output = Symbol_mapping(input,modtype,modorder,nobursts,nosymbs,nodummysymbs)
            
            % modulation
            switch modtype
                case 'GMSK'
                    % differential encoding:
                    d(1:nobursts,1) = mod(input(1:nobursts,1)+1,2);
                    d(1:nobursts,2:nosymbs) = mod(input(1:nobursts,2:nosymbs)+input(1:nobursts,1:nosymbs-1),2);
                    sihat = 1-2*d;
                case 'QPSK'
                    % symbol mapping
                    pairs = reshape(input,nobursts,modorder,nosymbs);
                    tab4 = [1+1i 1-1i -1+1i -1-1i];
                    l = zeros(nobursts,nosymbs);
                    for k = 1:nobursts
                        idx = bi2de(squeeze(pairs(k,:,:))');
                        l(k,:) = tab4(idx+1);
                    end
                    si = l./sqrt(2);
                    
                    % symbol rotation
                    sihat = zeros(nobursts,nosymbs);
                    phaseinc = 3*pi/4;
                    for k = 1:nobursts
                        sihat(k,:) = si(k,:).*exp(((0:nosymbs-1)-nodummysymbs)*phaseinc*1i);
                    end
                case '8PSK'
                    % symbol mapping
                    triples = reshape(input,nobursts,modorder,nosymbs);
                    tab8 = [3 6 2 7 4 5 1 0];
                    l = zeros(nobursts,nosymbs);
                    for k = 1:nobursts
                        idx = bi2de(squeeze(triples(k,:,:))');
                        l(k,:) = tab8(idx+1);
                    end
                    si = exp(1i*2*pi*l/8);
                    
                    % symbol rotation
                    sihat = zeros(nobursts,nosymbs);
                    phaseinc = 3*pi/8;
                    for k = 1:nobursts
                        sihat(k,:) = si(k,:).*exp(((0:nosymbs-1)-nodummysymbs)*phaseinc*1i);
                    end
                case '16QAM'
                    % symbol mapping
                    quadruples = reshape(input,nobursts,modorder,nosymbs);
                    tab16 = [1+1i 1+3*1i 3+1i 3+3*1i 1-1i 1-3*1i 3-1i 3-3*1i -1+1i -1+3*1i -3+1i -3+3*1i -1-1i -1-3*1i -3-1i -3-3*1i];
                    l = zeros(nobursts,nosymbs);
                    for k = 1:nobursts
                        idx = bi2de(fliplr(squeeze(quadruples(k,:,:))'));
                        l(k,:) = tab16(idx+1);
                    end
                    si = l./sqrt(10);
                    
                    % symbol rotation
                    sihat = zeros(nobursts,nosymbs);
                    phaseinc = pi/4;
                    for k = 1:nobursts
                        sihat(k,:) = si(k,:).*exp(((0:nosymbs-1)-nodummysymbs)*phaseinc*1i);
                    end
                case '32QAM'
                    % symbol mapping
                    quintuples = reshape(input,nobursts,modorder,nosymbs);
                    tab32 = [-3-5*1i -1-5*1i -3+5*1i -1+5*1i -5-3*1i -5-1*1i -5+3*1i -5+1*1i -1-3*1i -1-1*1i -1+3*1i -1+1*1i -3-3*1i -3-1*1i -3+3*1i -3+1*1i 3-5*1i 1-5*1i 3+5*1i 1+5*1i 5-3*1i 5-1*1i 5+3*1i 5+1*1i 1-3*1i 1-1*1i 1+3*1i 1+1*1i 3-3*1i 3-1*1i 3+3*1i 3+1*1i];
                    l = zeros(nobursts,nosymbs);
                    for k = 1:nobursts
                        idx = bi2de(fliplr(squeeze(quintuples(k,:,:))'));
                        l(k,:) = tab32(idx+1);
                    end
                    si = l./sqrt(20);
                    
                    % symbol rotation
                    sihat = zeros(nobursts,nosymbs);
                    phaseinc = -pi/4;
                    for k = 1:nobursts
                        sihat(k,:) = si(k,:).*exp(((0:nosymbs-1)-nodummysymbs)*phaseinc*1i);
                    end
            end
            
            output = sihat;
        end

        
        %% Pulse shaping GMSK
        function [output groupdelay glen] = Pulse_GMSK(input,nobursts,nosymbs,T,OSR)
            
            % pulse shaping
            % parameters to define GMSK pulse
            BT = 0.3;           % Product of 3dB bandwidth and symbol duration
            
            B = BT/T;           % 3 dB bandwidth of the filter
            groupdelay = 3;     % Group delay in number of symbol durations
                                % a group delay of 2.5 also leads to a pulse with
                                % almost all signal energy compared to the ideal one
                                % (groupdelay = inf)
            fs=OSR/T;           % Sampling frequency [Hz]
            
            % create Gaussian pulse
            t = -(groupdelay*T):1/fs:(groupdelay*T);
            g = 1/(2*T) * ( erfc(sqrt(2/log(2))*pi*B*(t-T/2)) - erfc(sqrt(2/log(2))*pi*B*(t+T/2)) );
            
            % oversample (with zero filling)
            alphaup = zeros(nobursts,OSR*nosymbs);
            alphaup(1:nobursts,1:OSR:end) = input;
            
            % filter the data
            % alphagauss = 1/fs*filter(g,1,alphaup')'*pi/2;
            for k=1:nobursts
                alphagauss(k,:) = 1/fs*conv(g,alphaup(k,:))*pi/2;
            end
            
            % phase integration
            cumphi = cumsum(alphagauss')';
            
            % Construct the complex signal
            modulated = cos(cumphi)+1i*sin(cumphi);
            
            output = modulated;
            
            glen = size(g,2);
        end
        
        %% bin2nrz
        function nrz = bin2nrz(binN)
            % binN:     Binary Data Sequence
            nrz=-2*binN+1;
        end
        
    end
end
