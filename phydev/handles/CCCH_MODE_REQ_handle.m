% CCCH_MODE_REQ_handle.m - process CCCH_MODE_REQ
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

function CCCH_MODE_REQ_handle(interface,tpu)

MatPhyConfig;

% check for type of CCCH_MODE_REQ
switch interface.Data(121)
    case CCCH_MODE_NONE
        fprintf('CCCH_MODE type: CCCH_MODE_NONE\n');
        % TODO: set some variable
        send_CCCH_MODE_CONF(interface,CCCH_MODE_NONE,tpu);
    case CCCH_MODE_NON_COMBINED
        fprintf('CCCH_MODE type: CCCH_MODE_NON_COMBINED\n');
        % TODO: set some variable
        send_CCCH_MODE_CONF(interface,CCCH_MODE_NON_COMBINED,tpu);
    case CCCH_MODE_COMBINED
        fprintf('CCCH_MODE type: CCCH_MODE_COMBINED\n');
        % TODO: set some variable
        send_CCCH_MODE_CONF(interface,CCCH_MODE_COMBINED,tpu);
    otherwise
        fprintf('Unknown CCCH_MODE request\n');
end

end

%% send CCCH_MODE_CONF to phyconnect
function send_CCCH_MODE_CONF(interface,type)

constants;

% wait for phyconnect to be ready
while 1
    if interface.Data(3) == 0
        break;
    end
end

% send message
tpu.display;
interface.Data(17) = 0; % msg done flag
fprintf('Sending CCCH_MODE_CONF\n');
interface.Data(19) = CCCH_MODE_CONF;
interface.Data(21) = type;

% set message flag
interface.Data(3) = 1;

end
