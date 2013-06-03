% TPU.m - Software implementation of TPU according to 3GPP TS 45.010
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

classdef TPU < GsmPhy
    properties
        QN;
        BN;
        TN;
        FN;
        OffsetQN;
        OffsetBN;
        TpuDisplay;
    end
    methods
        
        %% contructor
        function obj = TPU(config)
            
            obj.QN = 0;
            obj.BN = 0;
            obj.TN = 0;
            obj.FN = 0;
            obj.OffsetQN = 0;
            obj.OffsetBN = 0;
            obj.TpuDisplay = 0;
            
            if nargin == 1
                if isfield(config,'QN')
                    obj.QN = config.QN;
                end
                if isfield(config,'BN')
                    obj.BN = config.BN;
                end
                if isfield(config,'TN')
                    obj.TN = config.TN;
                end
                if isfield(config,'FN')
                    obj.FN = config.FN;
                end
                if isfield(config,'TpuDisplay')
                    obj.TpuDisplay = config.TpuDisplay;
                end
            end
           
            obj.displayTpuInit();
            
        end
        
        %% reset
        function reset(obj)
            
            obj.QN = 0;
            obj.BN = 0;
            obj.TN = 0;
            obj.FN = 0;
            obj.OffsetQN = 0;
            obj.OffsetBN = 0;
            
        end
        
        %% display counters
        function display(obj)          
            
            if obj.TpuDisplay
                fprintf('QN %3u, BN %3u, TN %1u, FN %7u\n', ...
                    obj.QN, ...
                    obj.BN, ...
                    obj.TN, ...
                    obj.FN);
            end
            
        end
        
        %% display TPU init
        function displayTpuInit(obj)
           
            if obj.TpuDisplay
                fprintf('starting TPU at ');
            end
            
        end
        
        %% increment QN
        function incQN(obj)
            
            % increment QN
            if obj.QN ~= obj.QN_MAX
                obj.QN = obj.QN+1;
            else
                obj.QN = 0;
                % increment TN
                if obj.TN ~= obj.TN_MAX
                    obj.TN = obj.TN+1;
                else
                    obj.TN = 0;
                    % increment FN
                    obj.FN = mod(obj.FN+1,2715648);
                end
            end
            
            % increment BN
            obj.BN = floor(obj.QN/4);
            
        end
        
        %% increment BN
        function incBN(obj)
            
            % increment BN
            if obj.BN ~= 156
                obj.BN = obj.BN+1;
            else
                obj.BN = 0;
                % increment TN
                if obj.TN ~= obj.TN_MAX
                    obj.TN = obj.TN+1;
                else
                    obj.TN = 0;
                    % increment FN
                    obj.FN = mod(obj.FN+1,2715648);
                end
            end
            
            % increment QN
            obj.QN = obj.BN*4;
            
        end        
        
        %% increment TN
        function incTN(obj)
            
            obj.QN = 0;
            obj.BN = 0;
            % increment TN
            if obj.TN ~= obj.TN_MAX
                obj.TN = obj.TN+1;
            else
                obj.TN = 0;
                % increment FN
                obj.FN = mod(obj.FN+1,2715648);
            end
            
        end
        
        %% increment FN
        function incFN(obj)
            
            obj.QN = 0;
            obj.BN = 0;
            obj.TN = 0;
            % increment FN
            obj.FN = mod(obj.FN+1,2715648);
            
        end
        
        %% jumb QN
        function jumpQN(obj,deltaQN)
            
            if sign(deltaQN) == -1
                error('Negativ QN jump is not possible!');
            end
            
            obj.QN = obj.QN + deltaQN;
            
            % check QN
            if obj.QN > obj.QN_MAX
                overfl = floor(obj.QN/obj.BURST_DUR_QN);
                obj.QN = mod(obj.QN,obj.BURST_DUR_QN);
                obj.TN = obj.TN + overfl;
                
                % check TN
                if obj.TN > obj.TN_MAX
                    overfl = floor(obj.TN/8);
                    obj.TN = mod(obj.TN,8);
                    obj.FN = obj.FN + overfl;
                    % check FN
                    obj.FN = mod(obj.FN,2715648);
                end
                
            end
            
            % check BN
            obj.BN = floor(obj.QN/4);
            
        end
        
        %% jumb BN
        function jumpBN(obj,deltaBN)
            
            if sign(deltaBN) == -1
                error('Negativ BN jump is not possible!');
            end
            
            obj.jumpQN(deltaBN*4);
            
            % check QN
            obj.QN = obj.BN*4;
            
        end
        
        %% jumb TN
        function jumpTN(obj,deltaTN)
            
            if sign(deltaTN) == -1
                error('Negativ TN jump is not possible!');
            end
            
            obj.QN = 0;
            obj.BN = 0;
            obj.jumpQN(deltaTN*obj.BURST_DUR_QN);
            
        end
        
        %% jumb FN
        function jumpFN(obj,deltaFN)
            
            if sign(deltaFN) == -1
                error('Negativ FN jump is not possible!');
            end
            
            obj.QN = 0;
            obj.BN = 0;
            obj.TN = 0;
            obj.jumpQN(deltaFN*obj.BURST_DUR_QN*8);
            
        end
        
        %% compute index in terms of QN
        % TODO
        
        %% compute index in terms of BN
        function N = indexBN(obj)
            
            N = mod(obj.FN,obj.MF_DUR_FN*obj.N_MF)*obj.BURST_DUR_BN*8 + obj.TN*obj.BURST_DUR_BN + obj.BN + 1;
            N = N + obj.OffsetBN;
            N = mod(N,obj.N_MF*obj.MF_DUR_FN*8*obj.BURST_DUR_BN);
            N = round(N);

        end
        
    end
    
end
