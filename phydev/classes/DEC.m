% DEC.m - DEC class
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

classdef DEC < GsmPhy
    
    properties
        DECconf; % Decoder configuration struct
        DECdata;
        DECstate;
        DECmem;
    end
    
    methods
        
        %% constructor
        function obj = DEC(config)
            
            % DECstate
            obj.DECstate.burstCnt = 0;
            
            % DECmem
            obj.DECmem.demultMem = [];
            
            if nargin < 1
                
                % DECconf
                obj.DECconf.codeGenerator = [23 33];
                obj.DECconf.constraintLength = 5;
                obj.DECconf.tracebackLength = 5*obj.DECconf.constraintLength;
                obj.DECconf.trellis = poly2trellis(obj.DECconf.constraintLength,obj.DECconf.codeGenerator);
            else
                obj.DECconf = config;
            end
        end
        
        %% setData
        function [] = setData(obj,data)
            obj.DECdata = data;
        end
        
        %% reset
        % TODO
        
        %% Controller
        function rpt = Controller(obj,cmd)
            rpt = [];
            
            switch cmd.type
                case 'SB_DEC'
                    
                    % ChanDec
                    cmdChanDec.MCS = 'SCH';
                    
                    cmdChanDec.input = obj.DECdata;
                    cmdChanDec.ib = 25;
                    cmdChanDec.pb = 10;
                    cmdChanDec.gd = [1,0,1,0,1,1,1,0,1,0,1];
                    rptChanDec = obj.ChanDec(cmdChanDec);
                    
                    % report
                    rpt.userdata = rptChanDec.output;
                    rpt.parityd = rptChanDec.crc;
                    
                case 'NB_DEC'
                    
                    % increment burst counter
                    obj.DECstate.burstCnt = obj.DECstate.burstCnt + 1;
                    
                    % demultiplex
                    cmdDemult = [];
                    rptDemult = obj.Demult(cmdDemult);
                    
                    % radio block is complete
                    if obj.DECstate.burstCnt == 4;
                        
                        % Deswap/Demap
                        cmdDeswapDemap.MCS = 'SACCH';
                        rptDeswapDemap = obj.DemapDeswap(cmdDeswapDemap);
                        
                        % Deint
                        cmdDeint.MCS = 'SACCH';
                        cmdDeint.input = rptDeswapDemap.output;
                        rptDeint = obj.Deint(cmdDeint);
                        
                        % ChanDec
                        cmdChanDec.MCS = 'SACCH';
                        
                        cmdChanDec.input = rptDeint.output;
                        cmdChanDec.ib = 184;
                        cmdChanDec.pb = 40;
                        cmdChanDec.gd = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                        rptChanDec = obj.ChanDec(cmdChanDec);
                        
                        % Report
                        rpt.userdata = rptChanDec.output;
                        rpt.parityd = rptChanDec.crc;
                        
                        % clear
                        obj.DECstate.burstCnt = 0;
                        obj.DECmem.demultMem = [];
                    end
                otherwise
                    error('Decoder command type unknown')
            end
            
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % signal processing primitives for DEC
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %% Demultiplexer
        function rpt = Demult(obj,cmd)
            
            % demultiplex
            obj.DECmem.demultMem = [ obj.DECmem.demultMem; obj.DECdata ];
            
            % report
            rpt = [];
            
        end
        
        %% Demapper/Deswapper
        function rpt = DemapDeswap(obj,cmd)
            
            % initialize
            sf = []; % stealing flag
            data = []; % interleaved data
            
            % demap/deswap
            switch cmd.MCS
                case 'SACCH'
                    % demapping (no deswapping for this mode)
                    sf(1:2:8) = obj.DECmem.demultMem(:,58);
                    sf(2:2:8) = obj.DECmem.demultMem(:,59);
                    data = [obj.DECmem.demultMem(:,1:57),obj.DECmem.demultMem(:,60:116)];
                otherwise
                    error('Invalid MCS in DemapDeswap primitive!');
            end
            
            % report
            rpt.sf = sf;
            rpt.output = data;
        end
        
        %% Deinterleaver
        function rpt = Deint(obj,cmd)
            
            % initialize
            output = []; % encoded data
            
            % deinterleave
            switch cmd.MCS
                case 'SACCH'
                    output = zeros(1,456);
                    for k=0:455
                        B = mod(k,4);
                        j = 2*mod(49*k,57)+floor(mod(k,8)/4);
                        output(k+1) = cmd.input(B+1,j+1);
                    end
                otherwise
                    error('Invalid MCS in Deint primitive!');
            end
            
            % report
            rpt.output = output;
        end
        
        %% Depuncturing Unit
        function rpt = Depunc(obj,cmd)
            
            % report
            rpt = [];
            
        end
        
        %% Incremental Redundancy
        function rpt = IR(obj,cmd)
            
            % report
            rpt = [];
            
        end
        
        %% Channel Decoder
        function rpt = ChanDec(obj,cmd)
            
            % decode
            decoded = vitdec(cmd.input,obj.DECconf.trellis,obj.DECconf.tracebackLength,'trunc','unquant');
            
            % CRC check
            % TODO: get gfdeconv to work or remove it form the code
            if false
                [~, remd] = gfdeconv(fliplr(decoded(1:cmd.ib+cmd.pb)),cmd.gd);
            else
                remd = decoded(1:cmd.pb);
                for k=1:cmd.ib
                    remd = xor([remd(2:end) decoded(cmd.pb+k)], cmd.gd(2:end)*remd(1));
                end
            end
            remd = ~remd;
            
            % report
            rpt.output = decoded(1:cmd.ib);
            rpt.crc = sum(remd);
            
        end
    end
end