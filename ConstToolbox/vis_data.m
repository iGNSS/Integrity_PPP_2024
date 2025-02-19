function [visible_data, I_pass] = vis_data(mask, all_data, obscure_info, ...
                                    obscure_altitude)

% [visible_data, I_pass] = vis_data(mask, all_data, obscure_info, ...
%                             obscure_altitude);
%
% Finds azimuth/elevation pairs passing the masking tests described 
% in the mask variable. Returns only that data that passes the masking
% tests. 
%
% Input:
%   mask  - masking information (rad) (1x1, nx3, or nx4), default = 0;  
%        1x1 form is minimum elevation only [min_el]
%        nx3 form is min elevation and azimuth bounds [min_el start_az stop_az]
%        nx4 form is elevation and azimuth bounds [min_el max_el start_az stop_az]
%        Azimuth start and stop are assumed to be clockwise.
%        Examples:
%         minimum elevation mask of 5 degrees (rad) (1x1) 
%              mask = .0873   
%         minimum elevation and azimuth bound triples (nx3)
%              mask = [.0873   pi/2   pi;       % 5 deg min el, 90->180 azimuth
%                      .1745   pi    pi/4]      % 10 deg min el, 180->90 azimuth
%                                               % wraps through 0
%         elevation and azimuth bound quadruples
%              mask = [.0873  .5236  0    pi;    % 5->30 deg el, 0->180 azimuth
%                      .1745  pi/4   pi  2*pi]   % 10->45 deg el, 180->360 azimuth  
%        Note: Set mask = -pi/2 to exclude data behind the earth
%   all_data - raw observation data [azimuth (rad), elevation (rad), 
%                                    other corresponding data (optional)]
%              minimum size (nx2) up to (nxm)
%              valid values for azimuth are -2*pi to +2*pi
%              valid values for elevation are -pi/2 to +pi/2     
%              Note: The corresponding data is optional and can be any data 
%                    corresponding to the az/el pairs (nxk) where k is the number
%                    of other data type included. Units are parameter dependent 
%                    and are not used within this function. Examples of data that
%                    might be included would be time, range, satellite number, etc.
%   obscure_info - contains information needed to determine whether the earth
%                  obscures the line-of-sight (nx3) [tangent_radius, alpha, beta].
%                  (meters, radians). Not used for visibility from a ground-based
%                  site. (Optional)
%                  Alpha is the angle between the x1 and x2 vectors sent to LOS. 
%                  Beta is the angle between the x1 vectors and the radius to the
%                  tangent point of the los vectors.
%                  An observation is obscured if the tangent radius is below the 
%                  users tolerance, and alpha is greater than beta. 
%   obscure_altitude - Altitude above earth to include in earth obscuration 
%                      (meters) (nx1). Default = 0 meters. Not used for visibility
%                      from a ground-based site. (Optional)
% Output:
%   visible_data - all_data that passed the masking test and is not obscured by the
%                  Earth (jxm)
%   I_pass       - index to data that passed the masking test (jx1)
%

% Written by: Maria Evans, April 1998
% Copyright (c) 1998 by Constell, Inc.

% functions called: ERR_CHK

%%%%% BEGIN VARIABLE CHECKING CODE %%%%%
% declare the global debug mode
global DEBUG_MODE

RADIUS_EARTH = 6378137.0;   % mean radius of the Earth WGS-84 value

% Initialize the output variables
visible_data=[];

% Check the number of input arguments and issues a message if invalid
msg = nargchk(2,5,nargin);
if ~isempty(msg)
  fprintf('%s  See help on VIS_DATA for details.\n',msg);
  fprintf('Returning with empty outputs.\n\n');
  return
end

if nargin < 4,
  obscure_altitude = 0.0;
end;

% Get the current Matlab version
matlab_version = version;
matlab_version = str2num(matlab_version(1));

% If the Matlab version is 5.x and the DEBUG_MODE flag is not set
% then set up the error checking structure and call the error routine.
if matlab_version >= 5.0                        
  estruct.func_name = 'VIS_DATA';

  % Develop the error checking structure with required dimension, matching
  % dimension flags, and input dimensions.
  estruct.variable(1).name = 'mask';
  estruct.variable(1).req_dim = [1 1; 902 3; 902 4];
  estruct.variable(1).var = mask;
  
  estruct.variable(2).name = 'all_data(:,1)-Azimuth';
  estruct.variable(2).req_dim = [901 1];
  estruct.variable(2).var = all_data(:,1);
  estruct.variable(2).type = 'ANGLE_RAD';

  estruct.variable(3).name = 'all_data(:,2)-Elevation';
  estruct.variable(3).req_dim = [901 1];
  estruct.variable(3).var = all_data(:,2);
  estruct.variable(3).type = 'ELEVATION_RAD';
 
  estruct.variable(4).name = 'obscure_altitude';
  estruct.variable(4).req_dim = [1 1];
  estruct.variable(4).var = obscure_altitude;

  if nargin >= 3,
    estruct.variable(5).name = 'obscure_info';
    estruct.variable(5).req_dim = [901 3];
    estruct.variable(5).var = obscure_info;
  end;
 
  % Call the error checking function
  stop_flag = err_chk(estruct);
  
  if stop_flag == 1           
    fprintf('Invalid inputs to %s.  Returning with empty outputs.\n\n', ...
             estruct.func_name);
    return
  end % if stop_flag == 1
end % if matlab_version >= 5.0 

%%%%% END VARIABLE CHECKING CODE %%%%%

%%%%% BEGIN ALGORITHM CODE %%%%%

az = all_data(:,1);
el = all_data(:,2);
% define the return matrix of passing pairs as null ([])
I_pass = [];

% Verify that all azimuth definitions are from 0 -> 360 (not -180 -> 180)
I_az_negative = find(az < 0);                      % find all negative azimuths
az(I_az_negative) = az(I_az_negative) + 2 * pi;    % and convert to positive

if size(mask,2) == 1         % only an elevation mask is used
  I_pass = find(el >= mask); % find all the elevations above the elevation mask

% else if we have an elevation and azimuth range to evaluate
elseif size(mask,2) == 3                   
  num_mask_pairs = size(mask,1);    % find out how many el/az pairs we have
  
  for i = 1:num_mask_pairs 
  
    if mask(i,2) > mask(i,3)
      I_pass_new = find(el >= mask(i,1) & (az >= mask(i,2) | az <= mask(i,3)));    
    else  
      I_pass_new = find(el >= mask(i,1) & az >= mask(i,2) & az <= mask(i,3));
    end % if mask(i,2) > mask(i,3)
    
    I_pass = [I_pass; I_pass_new];
  end % for i = 1:num_mask_pairs  
  
  % sort back to the original ordering
  I_pass = sort(I_pass);

elseif size(mask,2) == 4                   
  num_mask_pairs = size(mask,1);    % find out how many el/az pairs we have
  
  for i = 1:num_mask_pairs 
  
    if mask(i,3) > mask(i,4)
      I_pass_new = find(el >= mask(i,1) & el <= mask(i,2) & ...
                        (az >= mask(i,3) | az <= mask(i,4)));    
    else  
      I_pass_new = find(el >= mask(i,1) & el <= mask(i,2) & ...
                        az >= mask(i,3) & az <= mask(i,4));    
    end % if mask(i,3) > mask(i,4)
    
    I_pass = [I_pass; I_pass_new];
  end % for i = 1:num_mask_pairs  
  
  % sort back to the original ordering
  I_pass = sort(I_pass);

else
  fprintf('Unknown mask input format.  See help on vis_data for details.\n');
  
end % if size(mask,2) == 1  

% Check for whether observation is obscured by Earth
% Observation is obscured if the tangent altitude is below altitude threshold
% and alpha > beta
if nargin >= 3,
  i_vis = find(obscure_info(I_pass,1) >= obscure_altitude ...
               | obscure_info(I_pass,2) <= obscure_info(I_pass,3));

  if any(i_vis),
    I_pass = I_pass(i_vis);
    I_pass = sort(I_pass);
  end;
end;

% sort out the visible data and indices
visible_data = all_data(I_pass,:);

%%%% END ALGORITHM CODE %%%%%

% end VIS_DATA
