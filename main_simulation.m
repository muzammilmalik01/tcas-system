clear; close all; clc;

%% Parameters
dt = 0.1;           % Time step (seconds)
t_sim = 60;         % Total simulation time (seconds)
time = 0:dt:t_sim;

% TCAS Thresholds - Based on FAA Table
TAU_TA = 48;        % Traffic Advisory threshold (seconds)
DMOD_TA = 2407;     % Traffic Advisory distance threshold (meters) 20000-42000 1.30nm
TAU_RA = 35;        % Resolution Advisory threshold (seconds)
DMOD_RA = 2037;     % Resolution Advisory distance threshold (meters) 20000-42000 1.10nm

% % Aircraft IDs (for parity check)
% ac1_id = 333;      % Own aircraft ID (even)
% ac2_id = 4268;       % Intruder ID (odd)

% =====================
% Aircraft Initial Conditions
% =====================
% Uncomment the scenario you want to simulate:


% % --- Head-on-Head Collision Scenario (Different Parity) ---
%ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 120;   ac1_vy = 0;   ac1_id = 1234;      % Own aircraft
%ac2_x0 = 15000;     ac2_y0 = 36000;     ac2_vx = -120;  ac2_vy = 0;   ac2_id = 5679;      % Intruder

% % --- Head-on-Head Collision Scenario (Same Parity) ---
% ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 120;   ac1_vy = 0;   ac1_id = 1234;      % Own aircraft
% ac2_x0 = 15000;     ac2_y0 = 36000;     ac2_vx = -120;  ac2_vy = 0;   ac2_id = 5678;      % Intruder

% % --- Head-on-Head Collision Scenario (Same ID) ---
 % ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 120;   ac1_vy = 0;   ac1_id = 1234;      % Own aircraft
 % ac2_x0 = 15000;     ac2_y0 = 36000;     ac2_vx = -120;  ac2_vy = 0;   ac2_id = 1234;      % Intruder

 % % --- Head-on-Head Collision Scenario (Odd ID - Descend Case) ---
 % ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 120;   ac1_vy = 0;   ac1_id = 5679;      % Own aircraft
 % ac2_x0 = 15000;     ac2_y0 = 36000;     ac2_vx = -120;  ac2_vy = 0;   ac2_id = 1234;      % Intruder

% % --- Overtaking Scenario (Different Parity)---
  %ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 250;   ac1_vy = 0;  ac1_id = 1234;     % Own aircraft (faster, behind)
  %ac2_x0 = 8500;      ac2_y0 = 36000;     ac2_vx = 100;   ac2_vy = 0;  ac2_id = 5679;     % Intruder (slower, ahead)

% % --- Overtaking Scenario (Same Parity)--- 
%  ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 250;   ac1_vy = 0;  ac1_id = 1234;     % Own aircraft (faster, behind)
%  ac2_x0 = 8500;      ac2_y0 = 36000;     ac2_vx = 100;   ac2_vy = 0;  ac2_id = 5678;     % Intruder (slower, ahead)

% % --- Overtaking Scenario (Same ID)---
ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 250;   ac1_vy = 0;  ac1_id = 1234;     % Own aircraft (faster, behind)
ac2_x0 = 8500;      ac2_y0 = 36000;     ac2_vx = 100;   ac2_vy = 0;  ac2_id = 1234;     % Intruder (slower, ahead)

% % --- Overtaking Scenario (Odd ID)---
%  ac1_x0 = 0;         ac1_y0 = 36000;     ac1_vx = 250;   ac1_vy = 0;  ac1_id = 333;     % Own aircraft (faster, behind)
%  ac2_x0 = 8500;      ac2_y0 = 36000;     ac2_vx = 100;   ac2_vy = 0;  ac2_id = 444;     % Intruder (slower, ahead)

% Initialize storage
n_steps = length(time);
ac1_pos = zeros(n_steps, 2);
ac2_pos = zeros(n_steps, 2);
range_data = zeros(n_steps, 1);
advisory_data = zeros(n_steps, 1);  % 0=No Alert, 1=TA, 2=RA
ra_issued = false;
ra_time = 0;
ra_advice = struct('ac1', 'NONE', 'ac2', 'NONE');

%% Setup Figures
fig1 = figure('Name', '2D Aircraft Plot', 'Position', [100, 100, 800, 600]);
fig2 = figure('Name', 'Pilot Radar', 'Position', [950, 100, 600, 600]);

%% Main Simulation Loop
for i = 1:n_steps
    t = time(i);
    
    % Check if RA was issued and time to execute
    if ra_issued && (t - ra_time) >= 1.5 % Execute after 1.5 seconds
        % Apply altitude changes based on RA logic
        if strcmp(ra_advice.ac1, 'CLIMB')
            ac1_vy = 10; % Climb rate (m/s)
        elseif strcmp(ra_advice.ac1, 'DESCEND')
            ac1_vy = -10; % Descend rate (m/s)
        end
        
        if strcmp(ra_advice.ac2, 'CLIMB')
            ac2_vy = 10; % Climb rate (m/s)
        elseif strcmp(ra_advice.ac2, 'DESCEND')
            ac2_vy = -10; % Descend rate (m/s)
        end
    end
    
    % Update aircraft positions
    ac1_pos(i,:) = [ac1_x0 + ac1_vx * t, ac1_y0 + ac1_vy * t];
    ac2_pos(i,:) = [ac2_x0 + ac2_vx * t, ac2_y0 + ac2_vy * t];
    
    % TCAS Functions
    [is_tracked, range] = identify_and_track(ac1_pos(i,:), ac2_pos(i,:));
    [threat_level, tau, closing_vel] = threat_detection(range, ac1_pos(i,:), ac2_pos(i,:), ...
                                   [ac1_vx, ac1_vy], [ac2_vx, ac2_vy], ...
                                   TAU_TA, DMOD_TA, TAU_RA, DMOD_RA);
    advisory = advisory_logic(threat_level);
    
    % Store data
    range_data(i) = range;
    advisory_data(i) = threat_level;
    
    % Determine RA advice if RA is issued
    if threat_level == 2 && ~ra_issued
        ra_issued = true;
        ra_time = t;
        
        % Check ID parity
        ac1_parity = mod(ac1_id, 2);
        ac2_parity = mod(ac2_id, 2);
        
        if ac1_parity ~= ac2_parity
            % Different parity - even climbs, odd descends
            if ac1_parity == 0
                ra_advice.ac1 = 'CLIMB';
                ra_advice.ac2 = 'DESCEND';
            else
                ra_advice.ac1 = 'DESCEND';
                ra_advice.ac2 = 'CLIMB';
            end
        else
            % Same parity
            if sign(ac1_vx) ~= sign(ac2_vx)
                % Opposite directions: positive vx climbs, negative descends
                if ac1_vx > 0
                    ra_advice.ac1 = 'CLIMB';
                else
                    ra_advice.ac1 = 'DESCEND';
                end
                if ac2_vx > 0
                    ra_advice.ac2 = 'CLIMB';
                else
                    ra_advice.ac2 = 'DESCEND';
                end
            else
                % Same direction (possible overtaking)
                speed1 = abs(ac1_vx);
                speed2 = abs(ac2_vx);
                if speed1 > speed2
                    ra_advice.ac1 = 'CLIMB';
                    ra_advice.ac2 = 'DESCEND';
                elseif speed2 > speed1
                    ra_advice.ac1 = 'DESCEND';
                    ra_advice.ac2 = 'CLIMB';
                else
                    % Same speed, no RA needed
                    ra_advice.ac1 = 'NONE';
                    ra_advice.ac2 = 'NONE';
                end
            end
        end
    end
    
    % Update plots every 5 time steps for smooth animation
    if mod(i, 5) == 1 || i == n_steps
        update_2d_plot(fig1, ac1_pos(1:i,:), ac2_pos(1:i,:), i, advisory, t, range, tau, closing_vel, TAU_TA, DMOD_TA, TAU_RA, DMOD_RA, ra_advice);
        update_radar_plot(fig2, ac1_pos(i,:), ac2_pos(i,:), range, advisory, t, ra_advice);
        pause(0.1);
    end
end

%% Core TCAS Functions

function [is_tracked, range] = identify_and_track(ac1_pos, ac2_pos)
    % Identify and Track Function
    % Calculate range between aircraft
    dx = ac2_pos(1) - ac1_pos(1);
    dy = ac2_pos(2) - ac1_pos(2);
    range = sqrt(dx^2 + dy^2);
    
    % Simple tracking - if within 20km, aircraft is tracked
    is_tracked = range < 20000;
end

function [threat_level, tau, closing_velocity] = threat_detection(range, ac1_pos, ac2_pos, ac1_vel, ac2_vel, ...
                                        TAU_TA, DMOD_TA, TAU_RA, DMOD_RA)
    % Threat Detection Function
    % Returns: 0=No Threat, 1=TA, 2=RA
    
    % Calculate relative position and velocity
    dx = ac2_pos(1) - ac1_pos(1);
    dy = ac2_pos(2) - ac1_pos(2);
    dvx = ac2_vel(1) - ac1_vel(1);
    dvy = ac2_vel(2) - ac1_vel(2);
    
    % Calculate closing velocity
    if range > 0
        closing_velocity = (dx*dvx + dy*dvy) / range;
    else
        closing_velocity = 0;
    end
    
    % Calculate TAU
    if abs(closing_velocity) > 0.1 && closing_velocity < 0  % Converging
        tau = range / abs(closing_velocity);
    else
        tau = inf;
    end
    
    % Determine threat level
    if (tau < TAU_RA) || (range < DMOD_RA)
        threat_level = 2;  % RA
    elseif (tau < TAU_TA) || (range < DMOD_TA)
        threat_level = 1;  % TA
    else
        threat_level = 0;  % No Alert
    end
end

function advisory_text = advisory_logic(threat_level)
    % Advisory Logic Function
    % Convert threat level to advisory text
    
    switch threat_level
        case 2
            advisory_text = 'RESOLUTION ADVISORY';
        case 1
            advisory_text = 'TRAFFIC ADVISORY';
        otherwise
            advisory_text = 'NO ALERT';
    end
end

function update_2d_plot(fig, ac1_pos, ac2_pos, current_step, advisory, t, range, tau, closing_vel, TAU_TA, DMOD_TA, TAU_RA, DMOD_RA, ra_advice)
    % Update 2D Aircraft Plot with Text Information
    
    figure(fig);
    clf;
    hold on; grid on;
    
    % Plot flight paths
    plot(ac1_pos(:,1)/1000, ac1_pos(:,2)/1000, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Own Aircraft Path');
    plot(ac2_pos(:,1)/1000, ac2_pos(:,2)/1000, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Intruder Path');
    
    % Plot current positions
    plot(ac1_pos(current_step,1)/1000, ac1_pos(current_step,2)/1000, 'bo', ...
         'MarkerSize', 10, 'MarkerFaceColor', 'b', 'DisplayName', 'Own Aircraft');
    plot(ac2_pos(current_step,1)/1000, ac2_pos(current_step,2)/1000, 'ro', ...
         'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'Intruder');
    
    % Draw line between aircraft
    plot([ac1_pos(current_step,1), ac2_pos(current_step,1)]/1000, ...
         [ac1_pos(current_step,2), ac2_pos(current_step,2)]/1000, 'k--', 'LineWidth', 1);
    
    % Set background color based on advisory
    switch advisory
        case 'RESOLUTION ADVISORY'
            set(gca, 'Color', [1, 0.9, 0.9]);  % Light red
        case 'TRAFFIC ADVISORY'
            set(gca, 'Color', [1, 1, 0.9]);    % Light yellow
        otherwise
            set(gca, 'Color', 'white');
    end
    
    xlabel('Horizontal Position (km)');
    ylabel('Altitude (ft)');
    title(['2D Aircraft View - ' advisory]);
    legend('Location', 'best');
    axis equal;
    xlim([-2, 18]);
    ylim([34, 38]);
    
    % Add RA advice if available
    ra_text = '';
    if isfield(ra_advice, 'ac1')
        ra_text = {
            '=== RESOLUTION ADVISORY ===';
            sprintf('Own Aircraft: %s', ra_advice.ac1);
            sprintf('Intruder: %s', ra_advice.ac2);
            '';
        };
    end
    
    % Add text display with all updating values and thresholds
    info_text = {
        '=== SIMULATION DATA ===';
        sprintf('Time: %.1f s', t);
        sprintf('Range: %.2f km', range/1000);
        sprintf('TAU: %.1f s', tau);
        sprintf('Closing Velocity: %.1f m/s', closing_vel);
        '';
        '=== THRESHOLDS ===';
        sprintf('RA Distance: %.2f m', DMOD_RA);
        sprintf('TA Distance: %.2f m', DMOD_TA);
        sprintf('RA TAU: %.0f s', TAU_RA);
        sprintf('TA TAU: %.0f s', TAU_TA);
        '';
        '=== AIRCRAFT STATUS ===';
        sprintf('Own Aircraft: %s', advisory);
        sprintf('Intruder: %s', advisory);
        sprintf('Altitude: %.0f ft', ac1_pos(current_step,2));
    };
    
    % Combine RA text with info text
    if ~isempty(ra_text)
        info_text = [ra_text; info_text];
    end
    
    text(0.02, 0.02, info_text, 'Units', 'normalized', 'FontSize', 10, ...
         'VerticalAlignment', 'top', 'BackgroundColor', 'white', 'EdgeColor', 'black');
end

function update_radar_plot(fig, ac1_pos, ac2_pos, range, advisory, t, ra_advice)
    % Update Pilot Radar Display with Own Aircraft Advisory
    
    figure(fig);
    clf;
    
    % Create radar rings
    theta = 0:0.1:2*pi;
    for r = [5, 10, 15]*1000  % 5km, 10km, 15km rings
        plot(r*cos(theta)/1000, r*sin(theta)/1000, 'g:', 'LineWidth', 0.5);
        hold on;
    end
    
    % Center radar on own aircraft
    ac1_radar = [0, 0];  % Own aircraft at center
    ac2_radar = (ac2_pos - ac1_pos) / 1000;  % Relative position in km
    
    % Plot aircraft on radar
    plot(ac1_radar(1), ac1_radar(2), 'bs', 'MarkerSize', 12, ...
         'MarkerFaceColor', 'b', 'DisplayName', 'Own Aircraft');
    plot(ac2_radar(1), ac2_radar(2), 'rs', 'MarkerSize', 12, ...
         'MarkerFaceColor', 'r', 'DisplayName', 'Intruder');
    
    % Draw range line
    plot([ac1_radar(1), ac2_radar(1)], [ac1_radar(2), ac2_radar(2)], 'k--', 'LineWidth', 1);
    
    % Set background color based on advisory
    switch advisory
        case 'RESOLUTION ADVISORY'
            set(gca, 'Color', [0.2, 0.1, 0.1]);  % Dark red
        case 'TRAFFIC ADVISORY'
            set(gca, 'Color', [0.2, 0.2, 0.1]);  % Dark yellow
        otherwise
            set(gca, 'Color', 'black');          % Black
    end
    
    % Display information
    info_text = {
        sprintf('Altitude: %.0f ft', ac1_pos(2));
        sprintf('Range: %.2f km', range/1000);
        sprintf('Status: %s', advisory);
    };
    
    text(-12, 12, info_text, 'Color', 'green', 'FontSize', 12, ...
         'FontWeight', 'bold', 'VerticalAlignment', 'top');
    
    % Add Own Aircraft Advisory Status with RA advice
    switch advisory
        case 'RESOLUTION ADVISORY'
            if isfield(ra_advice, 'ac1')
                if strcmp(ra_advice.ac1, 'CLIMB')
                    advisory_text = 'CLIMB, CLIMB NOW';
                elseif strcmp(ra_advice.ac1, 'DESCEND')
                    advisory_text = 'DESCEND, DESCEND NOW';
                else
                    advisory_text = 'RESOLUTION ADVISORY';
                end
            else
                advisory_text = 'RESOLUTION ADVISORY';
            end
            advisory_color = [1 0 0]; % Red
        case 'TRAFFIC ADVISORY'
            advisory_text = 'TRAFFIC TRAFFIC';
            advisory_color = [1 0.5 0]; % Orange
        otherwise
            advisory_text = 'NO ALERT';
            advisory_color = [0 0.447 0.741]; % Blue (MATLAB default blue)
    end
    
    text(0, 13, ['OWN AIRCRAFT: ' advisory_text], 'Color', advisory_color, ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'BackgroundColor', 'black', 'EdgeColor', advisory_color);
    
    % Radar formatting
    axis equal;
    xlim([-15, 15]);
    ylim([-15, 15]);
    xlabel('Relative X (km)', 'Color', 'green');
    ylabel('Relative Y (km)', 'Color', 'green');
    title('Pilot Radar Display', 'Color', 'green');
    grid on;
    set(gca, 'GridColor', 'green', 'GridAlpha', 0.3);
    set(gca, 'XColor', 'green', 'YColor', 'green');
end
