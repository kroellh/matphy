% PhyConnect.m - Manages memory mapped file and communication to phydev
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

classdef PhyConnect < handle
    properties (Constant,Hidden)
        
        DefaultFileName = '/tmp/mmfile.dat';
        DefaultFileSize = 220;
        DefaultFileCreate = true;
        Type = 'uint32';
        
        % PHY = phydev
        % PCT = phyconnect
        
        % L1CTL interface
        PCT_RDY_IDX = 1;        % phyconnect ready
        PHY_RDY_IDX = 2;        % phydev ready
        MSG_PCT_IDX = 3;        % message for phyconnect is ready (set by phydev)
        MSG_PHY_IDX = 4;        % message for phydev is ready (set by phyconnect)
        MSG_FLAG_IDX = 17;      % flag of the message towards phyconnect
        TYP_PCT_IDX = 19;       % L1CTL message type towards phyconnect
        TYP_PHY_IDX = 20;       % L1CTL message type towards phydev
        PCT_START_IDX = 21;     % start of message for phyconnect
        PHY_START_IDX = 121;    % start of message for phydev
        
        % additional information stored in memory mapped file
        PHY_STA_IDX = 5;        % PHY state
        ARFCN_CUR_IDX = 10;     % ARFCN of the currently synched cell
        BSIC_CUR_IDX = 11;      % BSIC of the currently synched cell
        
        INFO_DL_LE = 8; % info_dl length in memory mapped file (words)
        
    end
    properties (Hidden)
        mmfile;
        FileName;
        FileSize;
        FileCreate;
        
    end
    properties (Constant)
        %% L1CTL message types
        FBSB_REQ        = 1;
        FBSB_CONF       = 2;
        DATA_IND        = 3;
        RACH_REQ        = 4;
        DM_EST_REQ      = 5;
        DATA_REQ        = 6;
        RESET_IND       = 7;
        PM_REQ          = 8;
        PM_CONF         = 9;
        ECHO_REQ        = 10;
        ECHO_CONF       = 11;
        RACH_CONF       = 12;
        RESET_REQ       = 13;
        RESET_CONF      = 14;
        DATA_CONF       = 15;
        CCCH_MODE_REQ   = 16;
        CCCH_MODE_CONF  = 17;
        DM_REL_REQ      = 18;
        PARAM_REQ       = 19;
        DM_FREQ_REQ     = 20;
        CRYPTO_REQ      = 21;
        SIM_REQ         = 22;
        SIM_CONF        = 23;
        TCH_MODE_REQ    = 24;
        TCH_MODE_CONF   = 25;
        VOICE_REQ       = 26;
        VOICE_CONF      = 27;
        VOICE_IND       = 28;
        MEAS_REQ        = 29;
        MEAS_IND        = 30;
    end
    methods
        
        %% contructor
        function obj = PhyConnect(varargin)
            
            error(nargchk(0,6,nargin));
            if rem(length(varargin), 2) ~= 0
                error('Unpaired properties');
            end
            
            obj.FileName = obj.DefaultFileName;
            obj.FileSize = obj.DefaultFileSize;
            obj.FileCreate = obj.DefaultFileCreate;
            
            for i = 1:2:length(varargin)
                
                if ~ischar(varargin{i})
                    error ('Invalid property');
                end
                switch varargin{i}
                    case 'FileName'
                        if ~ischar(varargin{i+1})
                            error('Invalid FileName');
                        end
                        obj.FileName = varargin{i+1};
                    case 'FileSize'
                        if ~isnumeric(varargin{i+1}) || rem(varargin{i+1}) ~= 0
                            error('Invalid FileSize');
                        end
                        obj.FileSize = ceil(varargin{i+1});
                    case 'FileCreate'
                        if ~islogical(varargin{i+1})
                            error('Invalid FileCreate');
                        end
                        obj.FileCreate = varargin{i+1};
                    otherwise
                        error('Invalid property');
                end
            end
            
            % create file
            if obj.FileCreate
                data = cast(zeros(obj.FileSize,1),obj.Type);
                fid = fopen(obj.FileName,'w');
                fwrite(fid,data,obj.Type);
                fclose(fid);
            end
            
            % map to memory
            
            while true
                if ~exist(obj.FileName,'file')
                    fprintf('File to map does not yet exist, waiting...\n');
                    pause(2);
                else
                    fprintf('Mapping file into memory\n');
                    obj.mmfile = memmapfile(obj.FileName,'Format',obj.Type,'Writable',true);
                    break;
                end
            end
            
        end
        
        %% get phyconnect ready
        function state = getPhyconnectReady(obj)
            state = obj.get(obj.PCT_RDY_IDX);
        end
        
        %% set phyconnect ready
        function setPhyconnectReady(obj,state)
            obj.put(obj.PCT_RDY_IDX,state);
        end
        
        %% get phydev ready
        function state = getPhydevReady(obj)
            state = obj.get(obj.PHY_RDY_IDX);
        end
        
        %% set phydev ready
        function setPhydevReady(obj,state)
            obj.put(obj.PHY_RDY_IDX,state);
        end
        
        %% set FSM PHY state
        function setPhyFsmState(obj,state)
            obj.put(obj.PHY_STA_IDX,state);
        end
        
        %% get FSM PHY state
        function state = getPhyFsmState(obj)
            state = obj.get(obj.PHY_STA_IDX);
        end
        
        %% set ARFCN
        function setARFCN(obj,arfcn)
            obj.put(obj.ARFCN_CUR_IDX,arfcn);
        end
        
        %% get ARFCN
        function arfcn = getARFCN(obj)
            arfcn = obj.get(obj.ARFCN_CUR_IDX);
        end
        
        %% set BSIC
        function setBSIC(obj,bsic)
            obj.put(obj.BSIC_CUR_IDX,bsic);
        end
        
        %% get BSIC
        function bsic = getBSIC(obj)
            bsic = obj.get(obj.BSIC_CUR_IDX);
        end
        
        %% get SYN from phyconnect/L2
        function status = getSynFromL2(obj)
            status = obj.get(obj.MSG_PHY_IDX);
        end
        
        %% get SYN from phydev/L1
        function status = getSynFromL1(obj)
            status = obj.get(obj.MSG_PCT_IDX);
        end
        
        %% set ACK to phyconnect
        function setAckToL2(obj)
            obj.put(obj.MSG_PHY_IDX,0);
        end
        
        %% set ACK to phydev
        function setAckToL1(obj)
            obj.put(obj.MSG_PCT_IDX,0);
        end
        
        %% get message type for phydev
        function type = getMsgTypeFromL2(obj)
            type = obj.get(obj.TYP_PHY_IDX);
        end
        
        %% get message type for phyconnect/L2
        function type = getMsgTypeFromL1(obj)
            type = obj.get(obj.TYP_PCT_IDX);
        end
        
        %% get RESET_REQ
        function msg = getRESET_REQ(obj)
            msg.type = obj.get(obj.PHY_START_IDX);
        end
        
        %% set RESET_REQ
        function setRESET_REQ(obj,type)
            obj.waitForPhydev();
            obj.put(obj.TYP_PHY_IDX,obj.RESET_REQ)
            obj.put(obj.PHY_START_IDX,type);
            obj.setSynToL1();
        end
        
        %% set RESET_CONF (called by phydev)
        function putRESET_CONF(obj,type)
            
            % wait for phyconnect to be ready
            obj.waitForPhyConnect();
            
            % send message
            fprintf('sending RESET_CONF\n');
            obj.put(obj.MSG_FLAG_IDX,0);
            obj.put(obj.TYP_PCT_IDX,obj.RESET_CONF);
            obj.put(obj.PCT_START_IDX,type);
            
            % set SYN
            obj.setSynToL2();
            
        end

        %% get RESET_CONF (called by phyconnect)
        %         function msg = getRESET_CONF(obj)
        %             msg.type = obj.get(obj.PHY_START_IDX);
        %             msg.    = obj.get(obj.MSG_FLAG_IDX,0);
        %             msg. = obj.get(obj.TYP_PCT_IDX,obj.RESET_CONF);
        %             msg. obj.get(obj.PCT_START_IDX,type);
        %         end

        
        %% set RESET_IND
        % TODO
        
        %% get PM_REQ (from L2 to PHY)
        function msg = getPM_REQ(obj)
            msg.type = obj.get(obj.PHY_START_IDX); % PM type
            msg.band_arfcn_from = obj.get(obj.PHY_START_IDX+1);
            msg.band_arfcn_to = obj.get(obj.PHY_START_IDX+2);
        end
        
        %% set PM_REQ (from L2 to PHY, in case Matlab implements L2)
        function msg = setPM_REQ(obj,msg)
            % wait for phyconnect to be ready
            obj.waitForPhydev();

            obj.put(obj.TYP_PHY_IDX,obj.PM_REQ); % message type

            % payload
            obj.put(obj.PHY_START_IDX,msg.type); % power measurement type
            obj.put(obj.PHY_START_IDX+1,msg.arfcn_start);
            obj.put(obj.PHY_START_IDX+2,msg.arfcn_stop);

            obj.setSynToL1();
        end
        
        %% set PM_CONF
        function setPM_CONF(obj,arfcn,rx_lev,flag)
            
            % wait for phyconnect to be ready
            obj.waitForPhyConnect();
            
            % send message
            fprintf('sending PM_CONF, ARFCN %4u, RX_LEV %3i\n',arfcn,rx_lev);
            obj.put(obj.MSG_FLAG_IDX,flag);
            obj.put(obj.TYP_PCT_IDX,obj.PM_CONF);
            obj.put(obj.PCT_START_IDX,arfcn);
            obj.put(obj.PCT_START_IDX+1,rx_lev);
            
            % set SYN
            obj.setSynToL2();
            
        end
        
        %% get FBSB_REQ
        function fbsbreq = getFBSB_REQ(obj)
            
            fbsbreq.band_arfcn         = obj.get(obj.PHY_START_IDX);
            fbsbreq.timeout            = obj.get(obj.PHY_START_IDX+1);
            fbsbreq.freq_err_thresh1   = obj.get(obj.PHY_START_IDX+2);
            fbsbreq.freq_err_thresh2   = obj.get(obj.PHY_START_IDX+3);
            fbsbreq.num_freqerr_avg    = obj.get(obj.PHY_START_IDX+4);
            fbsbreq.flags              = obj.get(obj.PHY_START_IDX+5);
            fbsbreq.sync_infor_idx     = obj.get(obj.PHY_START_IDX+6);
            fbsbreq.ccch_mode          = obj.get(obj.PHY_START_IDX+7);
            fbsbreq.rxlev_exp          = obj.get(obj.PHY_START_IDX+8);
            
        end
        
        
        %% set FBSB_REQ (from L2 to PHY, in case Matlab implements L2)
        function setFBSB_REQ(obj,msg)
            
            % wait for phydev to be ready
            obj.waitForPhydev();
            
            obj.put(obj.TYP_PHY_IDX,obj.FBSB_REQ); % message type
            
            % payload
            obj.put(obj.PHY_START_IDX,msg.band_arfcn);
            obj.put(obj.PHY_START_IDX+1,msg.timeout);
            obj.put(obj.PHY_START_IDX+2,msg.freq_err_thresh1);
            obj.put(obj.PHY_START_IDX+3,msg.freq_err_thresh2);
            obj.put(obj.PHY_START_IDX+4,msg.num_freqerr_avg);
            obj.put(obj.PHY_START_IDX+5,msg.flags);
            obj.put(obj.PHY_START_IDX+6,msg.sync_infor_idx);
            obj.put(obj.PHY_START_IDX+7,msg.ccch_mode);
            obj.put(obj.PHY_START_IDX+8,msg.rxlev_exp);

            obj.setSynToL1();
            
        end
        
        %% set FBSB_CONF
        function setFBSB_CONF(obj,info_dl,fbsbconf)
            
            % wait for phyconnect to be ready
            obj.waitForPhyConnect();
            
            % send message
            fprintf('Sending FBSB_CONF, ARFCN %4u \n',info_dl.band_arfcn);
            obj.put(obj.MSG_FLAG_IDX,0);
            obj.put(obj.TYP_PCT_IDX,obj.FBSB_CONF);
            obj.put_info_dl(info_dl);
            obj.put(obj.PCT_START_IDX+obj.INFO_DL_LE,fbsbconf.initial_freq_err);
            obj.put(obj.PCT_START_IDX+obj.INFO_DL_LE+1,fbsbconf.result);
            obj.put(obj.PCT_START_IDX+obj.INFO_DL_LE+2,fbsbconf.bsic);
            
            % set SYN
            obj.setSynToL2();
            
        end
        
        %% put DATA_IND, DATA_CONF, VOICE_IND
        function putDATA(obj,info_dl,data,type)
            
            % wait for phyconnect to be ready
            obj.waitForPhyConnect();
            
            % send message
            switch type
                case obj.DATA_IND
                    fprintf('Sending DATA_IND, ARFCN %4u \n',info_dl.band_arfcn);
                case obj.DATA_CONF
                    fprintf('Sending DATA_CONF, ARFCN %4u \n',info_dl.band_arfcn);
                case obj.VOICE_IND
                    fprintf('Sending VOICE_IND, ARFCN %4u \n',info_dl.band_arfcn);
                otherwise
                    error('Invalid type\n');
            end
            obj.put(obj.MSG_FLAG_IDX,0);
            obj.put(obj.TYP_PCT_IDX,type);
            obj.put_info_dl(info_dl);
            for i=1:length(data)
                obj.put(obj.PCT_START_IDX+obj.INFO_DL_LE+i-1,data(i));
            end
            
            % set SYN
            obj.setSynToL2();
            
        end
        
    end
    methods (Hidden)
        
        %% get and cast
        function output = get(obj,index)
            output = cast(obj.mmfile.Data(index),'double');
        end
        
        %% cast and put
        function put(obj,index,input)
            % abs only necessary if obj.Type is unsigned
            % as negative number would cast to zero
            obj.mmfile.Data(index) = cast(abs(input),obj.Type);
        end
        
        %% wait for phyconnect to be ready to receive a message
        function waitForPhyConnect(obj)
            while true
                if ~obj.get(obj.MSG_PCT_IDX)
                    break;
                end
            end
        end
        
        
        %% wait for phydev to be ready to receive a message
        function waitForPhydev(obj)
            while true
                if ~obj.get(obj.MSG_PHY_IDX)
                    break;
                end
            end
        end
        
        %% set SYN towards phyconnect/L2
        function setSynToL2(obj)
            obj.put(obj.MSG_PCT_IDX,1);
        end
        
        %% set SYN towards phydev/L1
        function setSynToL1(obj)
            obj.put(obj.MSG_PHY_IDX,1);
        end
        
        %% put info_dl
        function put_info_dl(obj,info_dl)
            obj.put(obj.PCT_START_IDX,info_dl.chan_nr);
            obj.put(obj.PCT_START_IDX+1,info_dl.link_id);
            obj.put(obj.PCT_START_IDX+2,info_dl.band_arfcn);
            obj.put(obj.PCT_START_IDX+3,info_dl.frame_nr);
            obj.put(obj.PCT_START_IDX+4,info_dl.rx_level);
            obj.put(obj.PCT_START_IDX+5,info_dl.snr);
            obj.put(obj.PCT_START_IDX+6,info_dl.num_biterr);
            obj.put(obj.PCT_START_IDX+7,info_dl.fire_crc);
        end
        
    end
    
end
