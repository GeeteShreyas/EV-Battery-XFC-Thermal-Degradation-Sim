%% XFC Thermal Stress & Battery Degradation Analysis
clear; clc; close all;

modelName = 'XFC_Battery_Model';
load_system(modelName);

%% 1. Run 1C Baseline Simulation (4.5 A, 10% -> 80% SoC in 2520 s)
I_charge = 4.5; 
sim1C = sim(modelName, 'StopTime', '2520', 'ReturnWorkspaceOutputs', 'on');

t_1C = sim1C.simlog.Battery_Equivalent_Circuit.batteryTemperature.series.time;
T_1C = sim1C.simlog.Battery_Equivalent_Circuit.batteryTemperature.series.values('degC');
V_1C = sim1C.simlog.Battery_Equivalent_Circuit.batteryVoltage.series.values('V');

%% 2. Run 4C Extreme Fast Charging Simulation (18 A, 10% -> 80% SoC in 630 s)
I_charge = 18; 
sim4C = sim(modelName, 'StopTime', '630', 'ReturnWorkspaceOutputs', 'on');

t_4C = sim4C.simlog.Battery_Equivalent_Circuit.batteryTemperature.series.time;
T_4C = sim4C.simlog.Battery_Equivalent_Circuit.batteryTemperature.series.values('degC');
V_4C = sim4C.simlog.Battery_Equivalent_Circuit.batteryVoltage.series.values('V');

%% 3. Project 500-Cycle Capacity Fade (Arrhenius Thermal + C-Rate Stress)
cycles = 0:500;
Ea = 31500;          % Activation energy for SEI growth (J/mol)
R_gas = 8.314;       % Universal gas constant (J/mol*K)
T_ref = 298.15;      % Reference temperature (25 degC in K)

% Mean cell temperature during each charge profile (in Kelvin)
T_mean_1C = mean(T_1C) + 273.15;
T_mean_4C = mean(T_4C) + 273.15;

% Arrhenius thermal acceleration factor
AF_1C = exp(-(Ea/R_gas) * (1/T_mean_1C - 1/T_ref));
AF_4C = exp(-(Ea/R_gas) * (1/T_mean_4C - 1/T_ref));

% Base fade rate per cycle (tuned for ~80% SoH at 1500 cycles at 1C, 25C)
k_base = 0.000133;
c_rate_penalty_4C = 1.6; % Additional lithium-plating stress at 4C

SoH_1C = 100 * (1 - k_base * AF_1C * cycles);
SoH_4C = 100 * (1 - k_base * AF_4C * c_rate_penalty_4C * cycles);

%% 4. Generate Plots
figure('Color', 'w', 'Position', [100, 100, 1000, 420]);

% Subplot 1: Thermal Stress Profile
subplot(1, 2, 1);
plot(t_1C/60, T_1C, 'b-', 'LineWidth', 2); hold on;
plot(t_4C/60, T_4C, 'r-', 'LineWidth', 2);
yline(45, 'k--', 'Optimal Temp Limit (45 °C)', 'LineWidth', 1.2);
grid on;
xlabel('Charging Time (minutes)');
ylabel('Cell Temperature (°C)');
title('Thermal Stress: 1C vs. 4C Fast Charging');
legend('1C Standard (4.5 A)', '4C XFC (18 A)', 'Location', 'best');

% Subplot 2: 500-Cycle State of Health (SoH) Degradation
subplot(1, 2, 2);
plot(cycles, SoH_1C, 'b-', 'LineWidth', 2); hold on;
plot(cycles, SoH_4C, 'r-', 'LineWidth', 2);
yline(80, 'k--', 'EV End-of-Life (80% SoH)', 'LineWidth', 1.2);
grid on;
xlabel('Equivalent Charge Cycles');
ylabel('State of Health - SoH (%)');
title('Projected Battery Degradation (500 Cycles)');
legend('1C Standard', '4C XFC', 'Location', 'southwest');
ylim([60 102]);

%% Print Summary Metrics to Command Window
fprintf('--- Simulation Summary ---\n');
fprintf('1C Peak Temp: %.1f °C | SoH after 500 cycles: %.1f%%\n', max(T_1C), SoH_1C(end));
fprintf('4C Peak Temp: %.1f °C | SoH after 500 cycles: %.1f%%\n', max(T_4C), SoH_4C(end));