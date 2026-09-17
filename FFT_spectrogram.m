clc;
clearvars;
close all;

%% ========================================================================
% 0. THÔNG SỐ CẤU HÌNH
% ========================================================================

filename = 'sine_24v.csv';

% ============================================================
% CHỌN BẬC SÓNG HÀI TỐI ĐA
% Ví dụ: 10, 21, 25, 50...
% ============================================================
MAX_HARMONIC = 50;


%% ========================================================================
% 1. ĐỌC DỮ LIỆU CSV
% ========================================================================

try
    data = readmatrix(filename);
catch
    data = csvread(filename);
end

% Loại bỏ dòng NaN
valid_rows = ~isnan(data(:,1)) & ~isnan(data(:,2));

time_raw   = data(valid_rows,1);
signal_raw = data(valid_rows,2);


%% ========================================================================
% 2. TÍNH TẦN SỐ LẤY MẪU BAN ĐẦU
% ========================================================================

N_raw = length(time_raw);

dt_avg = (time_raw(end) - time_raw(1)) / (N_raw - 1);

Fs_raw = 1 / dt_avg;

fprintf('=========================================\n');
fprintf('FILE: %s\n', filename);
fprintf('=========================================\n');

fprintf('So mau ban dau N = %d\n', N_raw);
fprintf('Tan so lay mau Fs = %.4f Hz\n', Fs_raw);


%% ========================================================================
% 3. ƯỚC LƯỢNG TẦN SỐ CƠ BẢN 50 Hz / 60 Hz
% ========================================================================

% Loại DC
v_dc_free = signal_raw - mean(signal_raw);

% FFT sơ bộ
Y_temp = fft(v_dc_free);

% Phổ một phía
P_temp = abs(Y_temp(1:floor(N_raw/2)+1));

% Trục tần số
f_temp = (0:floor(N_raw/2)) * (Fs_raw/N_raw);

% Tìm peak trong vùng 45-65 Hz
idx_search = find(f_temp >= 45 & f_temp <= 65);

if isempty(idx_search)
    error('Khong tim thay vung tan so 45-65 Hz.');
end

[~, local_idx] = max(P_temp(idx_search));

idx_f1_est = idx_search(local_idx);

f1_est = f_temp(idx_f1_est);

fprintf('\nTan so co ban uoc luong = %.4f Hz\n', f1_est);


%% ========================================================================
% 4. XÁC ĐỊNH HỆ THỐNG 50 Hz HOẶC 60 Hz
% ========================================================================

if abs(f1_est - 60) < 5

    f_nom = 60;
    N_cycles = 12;

else

    f_nom = 50;
    N_cycles = 10;

end

fprintf('He thong danh dinh = %d Hz\n', f_nom);
fprintf('So chu ky cua so = %d cycles\n', N_cycles);


%% ========================================================================
% 5. ĐỒNG BỘ CỬA SỔ LẤY MẪU
% ========================================================================

T_win = N_cycles / f_nom;

% Lấy đúng khoảng thời gian yêu cầu
idx_win = find((time_raw - time_raw(1)) <= T_win);

t_win = time_raw(idx_win);
s_win = signal_raw(idx_win);

N_samples = length(s_win);

fprintf('Thoi gian cua so = %.6f s\n', T_win);
fprintf('So mau trong cua so = %d\n', N_samples);


%% ========================================================================
% 6. NỘI SUY VỀ LƯỚI THỜI GIAN ĐỀU
% ========================================================================

t_uniform = linspace( ...
    t_win(1), ...
    t_win(end), ...
    N_samples)';

s_uniform = interp1( ...
    t_win, ...
    s_win, ...
    t_uniform, ...
    'linear');


%% ========================================================================
% 7. TÍNH TẦN SỐ LẤY MẪU SAU KHI NỘI SUY
% ========================================================================

dt = (t_uniform(end) - t_uniform(1)) / (N_samples - 1);

Fs = 1/dt;

fprintf('Fs sau noi suy = %.4f Hz\n', Fs);


%% ========================================================================
% 8. TÍNH FFT
% ========================================================================

% Loại thành phần DC
v_ac = s_uniform - mean(s_uniform);

N = length(v_ac);

% FFT
Y = fft(v_ac);

% Phổ biên độ một phía
P1 = abs(Y(1:floor(N/2)+1)) / N;

% Nhân đôi các thành phần không phải DC/Nyquist
if N > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end

% Độ phân giải FFT
df = Fs/N;

% Trục tần số
f = (0:floor(N/2)) * df;


%% ========================================================================
% 9. TÌM TẦN SỐ CƠ BẢN f1
% ========================================================================

idx_search = find(f >= 45 & f <= 65);

[~, local_idx] = max(P1(idx_search));

idx_fund = idx_search(local_idx);

f1 = f(idx_fund);

fprintf('\n=========================================\n');
fprintf('KET QUA PHAN TICH\n');
fprintf('=========================================\n');

fprintf('Tan so co ban f1 = %.4f Hz\n', f1);


%% ========================================================================
% 10. KIỂM TRA BẬC HARMONIC CÓ THỂ TÍNH
% ========================================================================

max_possible_harmonic = floor((Fs/2) / f1);

if MAX_HARMONIC > max_possible_harmonic

    fprintf('\nCANH BAO:\n');
    fprintf('MAX_HARMONIC = %d vuot qua gioi han Nyquist.\n', ...
        MAX_HARMONIC);

    fprintf('Chi co the tinh toi bac %d.\n', ...
        max_possible_harmonic);

    MAX_HARMONIC = max_possible_harmonic;

end


%% ========================================================================
% 11. TÍNH BIÊN ĐỘ TỪNG HARMONIC
%
% Công thức:
%
% V_h = sqrt(
%        0.5*V(h-1)^2
%        + V(h)^2
%        + 0.5*V(h+1)^2
%       )
%
% Đây là cách gom nhóm 3 bin xung quanh harmonic.
% ========================================================================

V_h     = zeros(1, MAX_HARMONIC);
V_h_pct = zeros(1, MAX_HARMONIC);
f_h     = zeros(1, MAX_HARMONIC);

for h = 1:MAX_HARMONIC

    % Tần số harmonic
    f_h(h) = h * f1;

    % Vị trí bin trung tâm
    idx_center = round(f_h(h) / df) + 1;

    % Kiểm tra giới hạn
    if idx_center <= length(P1)

        % -------------------------------------------------
        % Harmonic cơ bản
        % -------------------------------------------------
        if h == 1

            V_h(h) = P1(idx_center);

        % -------------------------------------------------
        % Harmonic từ bậc 2 trở đi
        % Gom 3 bin:
        %
        % 0.5 bin trước
        % 1.0 bin trung tâm
        % 0.5 bin sau
        % -------------------------------------------------
        else

            c_prev = 0;
            c_center = P1(idx_center);
            c_next = 0;

            if idx_center > 1
                c_prev = P1(idx_center - 1);
            end

            if idx_center < length(P1)
                c_next = P1(idx_center + 1);
            end

            V_h(h) = sqrt( ...
                0.5*c_prev^2 + ...
                c_center^2 + ...
                0.5*c_next^2 );

        end
    end
end


%% ========================================================================
% 12. TỶ LỆ BIÊN ĐỘ HARMONIC SO VỚI FUNDAMENTAL
% ========================================================================

V_h_pct = (V_h / V_h(1)) * 100;


%% ========================================================================
% 13. TÍNH THD
% ========================================================================

% THD:
%
% THD = sqrt(V2^2 + V3^2 + ... + VN^2) / V1 * 100%

THD = sqrt(sum(V_h(2:MAX_HARMONIC).^2)) ...
      / V_h(1) * 100;


%% ========================================================================
% 14. HIỂN THỊ KẾT QUẢ
% ========================================================================

fprintf('\n=========================================\n');
fprintf('THD RESULTS\n');
fprintf('=========================================\n');

fprintf('Fundamental frequency : %.4f Hz\n', f1);
fprintf('Fundamental amplitude  : %.6f V Peak\n', V_h(1));
fprintf('Maximum harmonic       : %d\n', MAX_HARMONIC);
fprintf('THD                    : %.4f %%\n', THD);

fprintf('=========================================\n');


%% ========================================================================
% 15. BẢNG HARMONIC
% ========================================================================

fprintf('\n');
fprintf('-----------------------------------------------------\n');
fprintf(' Harmonic     Frequency (Hz)     Amplitude (V)    %%\n');
fprintf('-----------------------------------------------------\n');

for h = 1:MAX_HARMONIC

    fprintf('   H%-3d       %10.3f         %10.6f       %8.3f\n', ...
        h, ...
        f_h(h), ...
        V_h(h), ...
        V_h_pct(h));

end

fprintf('-----------------------------------------------------\n');
fprintf('THD-%d = %.4f %%\n', MAX_HARMONIC, THD);
fprintf('-----------------------------------------------------\n');


%% ========================================================================
% 16. VẼ PHỔ FFT
% ========================================================================

figure( ...
    'Name', 'Single-Sided FFT Spectrum', ...
    'Color', 'white', ...
    'Position', [100 100 1100 650]);


%% Trục đồ thị

ax = axes( ...
    'Parent', gcf, ...
    'Color', 'white', ...
    'XColor', 'black', ...
    'YColor', 'black', ...
    'LineWidth', 1.2, ...
    'FontSize', 11, ...
    'FontWeight', 'bold');

hold(ax, 'on');


%% Vẽ FFT

plot(ax, f, P1, ...
    'Color', [0 0.35 0.8], ...
    'LineWidth', 1.1);


%% Đánh dấu fundamental

plot(ax, f1, V_h(1), ...
    'ro', ...
    'MarkerSize', 7, ...
    'MarkerFaceColor', 'red');


%% ========================================================================
% 17. GIỚI HẠN TRỤC X
% ========================================================================

f_max_plot = (MAX_HARMONIC + 1) * f1;

xlim(ax, [0 f_max_plot]);

ylim(ax, [0 max(P1)*1.2]);


%% ========================================================================
% 18. LABEL / TITLE
% ========================================================================

xlabel(ax, ...
    'Frequency (Hz)', ...
    'Color', 'black', ...
    'FontSize', 11, ...
    'FontWeight', 'bold');

ylabel(ax, ...
    '|Vpeak|', ...
    'Color', 'black', ...
    'FontSize', 11, ...
    'FontWeight', 'bold');

title(ax, ...
    sprintf('FFT - THD_%d', ...
    MAX_HARMONIC), ...
    'Color', 'black', ...
    'FontSize', 13, ...
    'FontWeight', 'bold');


%% ========================================================================
% 19. GRID VÀ KHUNG
% ========================================================================

grid(ax, 'on');

ax.GridColor = [0.75 0.75 0.75];
ax.GridAlpha = 0.5;

box(ax, 'on');


%% ========================================================================
% 20. KHUNG HIỂN THỊ THD
% ========================================================================

text(ax, ...
    0.72, 0.92, ...
    sprintf([ ...
    'Fundamental = %.2f Hz\n' ...
    'V1 = %.3f V Peak\n' ...
    'THD_%d = %.2f %%'], ...
    f1, ...
    V_h(1), ...
    MAX_HARMONIC, ...
    THD), ...
    'Units', 'normalized', ...
    'Color', 'black', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'white', ...
    'EdgeColor', 'black', ...
    'LineWidth', 1, ...
    'Margin', 8, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top');


%% ========================================================================
% 21. VẼ CÁC VẠCH HARMONIC
% ========================================================================

for h = 1:MAX_HARMONIC

    if f_h(h) <= f_max_plot

        xline(ax, ...
            f_h(h), ...
            '--', ...
            'Color', [0.75 0.75 0.75], ...
            'LineWidth', 0.6);

    end

end


%% ========================================================================
% 22. HOÀN TẤT
% ========================================================================

hold(ax, 'off');

fprintf('\nPhan tich FFT + THD hoan tat.\n');