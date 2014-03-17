% GsmTap.m - Sends GSMTAP packets over UDP/IP
%
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

classdef GsmTap < handle
    properties (Constant,Hidden)
        
        DefaultIp = '127.0.0.1';
        Port = 4729;
        Type = 'uint8';
        
    end
    properties (Hidden)
        
        Ip;
        UdpSocket;
        
    end
    properties (Constant)
        
        GsmTapVersion = 1;
        GsmTapHeaderLength = 4; % in terms of 32-bit words
        
    end
    methods
        
        %% contructor
        function obj = GsmTap(varargin)
            
            error(nargchk(0,1,nargin));
            
            obj.Ip = obj.DefaultIp;
            
            for i = 1:length(varargin)
                
                if ~ischar(varargin{i})
                    error ('Invalid IP');
                end
                
                obj.Ip = varargin{i};
                
            end
            
            % create udp socket
            obj.UdpSocket = udp(obj.Ip,obj.Port);
            fopen(obj.UdpSocket);
            
        end
        
        %% osmo style data
        function osmo(obj,msg)
            header = obj.emptyHeader();
            header.type = 1; % UM
            header.arfcn = msg.info_dl.band_arfcn;
            header.signal_dbm = msg.info_dl.rx_level;
            header.snr_db = msg.info_dl.snr;
            header.frame_number = msg.info_dl.frame_nr;
            chan_nr_cbits = dec2bin(msg.info_dl.chan_nr,8);
            chan_nr_cbits = chan_nr_cbits(1:5);
            switch chan_nr_cbits
                case '10000' % BCCH
                    header.sub_type = 1;
                case '10010' % CCCH
                    header.sub_type = 2;
                otherwise % unknown
                    header.sub_type = 0;
            end
            header = obj.castHeader(header);
            data = obj.castData(msg.data);
            obj.send([header data]);
        end
        
    end
    methods (Hidden)
        
        %% send udp packet
        function send(obj,msg)
            fwrite(obj.UdpSocket,msg,obj.Type);
        end
        
        %% create empty GSMTAP header struct
        function header = emptyHeader(obj)
            header.version = obj.GsmTapVersion;
            header.hdr_len = obj.GsmTapHeaderLength;
            header.type = 0;
            header.timeslot = 0;
            header.arfcn = 0;
            header.signal_dbm = 0;
            header.snr_db = 0;
            header.frame_number = 0;
            header.sub_type = 0;
            header.antenna_nr = 0;
            header.sub_slot = 0;
            header.res = 0;
        end
        
        %% cast header struct to obj.Type vector
        % needs to be adapted for different obj.Type
        function headerCast = castHeader(obj,header)
            switch obj.Type
                case 'uint8'
                    headerCast = cast(zeros(1,header.hdr_len*4),obj.Type);
                    headerCast(1) = cast(header.version,obj.Type);
                    headerCast(2) = cast(header.hdr_len,obj.Type);
                    headerCast(3) = cast(header.type,obj.Type);
                    headerCast(4) = cast(header.timeslot,obj.Type);
                    headerCast(5) = cast(bitand(bitshift(header.arfcn,-8),2^8-1),obj.Type);
                    headerCast(6) = cast(bitand(bitshift(header.arfcn,0),2^8-1),obj.Type);
                    headerCast(7) = cast(header.signal_dbm,obj.Type);
                    headerCast(8) = cast(header.snr_db,obj.Type);
                    headerCast(9) = cast(bitand(bitshift(header.frame_number,-24),2^8-1),obj.Type);
                    headerCast(10) = cast(bitand(bitshift(header.frame_number,-16),2^8-1),obj.Type);
                    headerCast(11) = cast(bitand(bitshift(header.frame_number,-8),2^8-1),obj.Type);
                    headerCast(12) = cast(bitand(bitshift(header.frame_number,0),2^8-1),obj.Type);
                    headerCast(13) = cast(header.sub_type,obj.Type);
                    headerCast(14) = cast(header.antenna_nr,obj.Type);
                    headerCast(15) = cast(header.sub_slot,obj.Type);
                    headerCast(16) = cast(header.res,obj.Type);
                otherwise
                    error('headerCast not implemented for %s',obj.Type)
            end
        end
        
        %% cast data vector to obj.Type vector
        % needs to be adapted for different obj.Type
        function dataCast = castData(obj,data)
            switch obj.Type
                case 'uint8'
                    dataCast = cast(data,obj.Type);
                otherwise
                    error('dataCast not implemented for %s',obj.Type)
            end
        end
        
    end
    
end
