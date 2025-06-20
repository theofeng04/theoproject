
%% 1. Load spreadsheet ----------------------------------------------------
tbl = readtable('fishdata.xlsx');

%% 2. Build date & day_index (July–Oct) -----------------------------------
tbl.date      = datetime(tbl.Year, tbl.Month, tbl.Day);
tbl           = tbl(month(tbl.date) >= 7 & month(tbl.date) <= 10 , :);
tbl.day_index = days(tbl.date - datetime(tbl.Year,7,1)) + 1;

%% 3. Aliases / cleaning --------------------------------------------------
tbl.boat_load              = tbl.PeopleCount;
tbl.water_temperature      = tbl.WaterTemp;
tbl.lunar_light_percentage = tbl.MoonPhase;
tbl.fish_per_person_per_day = tbl.FishPerPeopleDay;         % Excel ratio col

%% ------------------------------------------------------------------------
%% PART A : scatter plots with quadratic metrics
figure('Name','Freedom – Quadratic Fits','Color','w');
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile
quadPanel(tbl.day_index, tbl.fish_per_person_per_day, ...
          'Day Index (Jul 1 = 1)', 'Productivity vs. Date');

nexttile
quadPanel(tbl.water_temperature, tbl.fish_per_person_per_day, ...
          'Water Temp (°F)', 'Productivity vs. Water Temp');

nexttile
quadPanel(tbl.lunar_light_percentage, tbl.fish_per_person_per_day, ...
          'Moon Illumination (%)', 'Productivity vs. Moon Phase');

nexttile
quadPanel(tbl.boat_load, tbl.fish_per_person_per_day, ...
          'People on Boat', 'Productivity vs. Boat Load');

%% ------------------------------------------------------------------------
%% PART B : global quadratic model & simulator
Xraw = [ tbl.day_index, ...
         tbl.water_temperature, ...
         tbl.lunar_light_percentage, ...
         tbl.boat_load ];
y = tbl.fish_per_person_per_day;

good = all(~isnan([Xraw y]),2);
Xraw = Xraw(good,:);     y = y(good);

% Design matrix  [1  x  x.^2]   →   β0…β8
X = [ ones(size(Xraw,1),1),  Xraw,  Xraw.^2 ];

beta = X \ y;                              % least-squares

yhat = X*beta;
SSE  = sum((y - yhat).^2);
SST  = sum((y - mean(y)).^2);
R2_glob   = 1 - SSE/SST;
RMSE_glob = sqrt(SSE/numel(y));

fprintf('Global R²   = %.3f\n', R2_glob);
fprintf('Global RMSE = %.3f fish / person / day\n', RMSE_glob);

% ---- prediction helper (vector or scalar) ------------------------------
predictCatch = @(d,T,M,B) ...
    [ ones(numel(d),1),  d(:), T(:), M(:), B(:), ...
      d(:).^2, T(:).^2, M(:).^2, B(:).^2 ] * beta;

% demo “what-if”
demo = predictCatch( 60, 67.5, 10, 32 );
fprintf('Demo trip  (d=60, T=67.5°F, moon 10%%, load 32)  →  %.2f fish/p/day\n', demo);

% ---- 1 000-trip bootstrap ----------------------------------------------
Nmc = 1000;  rng default
idx  = randi(size(Xraw,1), Nmc, 1);
dB   = Xraw(idx,1);   tB = Xraw(idx,2);
mB   = Xraw(idx,3);   bB = Xraw(idx,4);
pred = predictCatch(dB,tB,mB,bB);

figure('Color','w');
histogram(pred, 'BinWidth',0.1);
xlabel('Predicted Fish / Person / Day');
ylabel('Frequency');
title('Freedom – 1 000 Bootstrap Trips (Quadratic Model)'); grid on;


%% -----------------------------------------------------------------------
function quadPanel(x, y, xlab, ttl)
    good = ~isnan(x) & ~isnan(y);
    scatter(x, y, 36, 'filled'); hold on;

    if nnz(good) > 3
        % quadratic fit
        c  = polyfit(x(good), y(good), 2);
        xs = linspace(min(x(good)), max(x(good)), 200);
        plot(xs, polyval(c,xs), 'k-', 'LineWidth', 1.2);

        % R²
        yhat = polyval(c, x(good));
        SSE = sum((y(good)-yhat).^2);
        SST = sum((y(good)-mean(y(good))).^2);
        R2  = 1 - SSE/SST;

        % F & p
        n = nnz(good); df1 = 2; df2 = n-3;
        F = ((SST-SSE)/df1)/(SSE/df2);
        p = 1 - betainc(df2/(df2+df1*F), df2/2, df1/2);

        % annotation without LaTeX interpreter
        xr = xlim; yr = ylim;
        msg = sprintf('R^{2} = %.2f\np = %.3f', R2, p);
        text(xr(1)+0.02*(xr(2)-xr(1)), yr(2)-0.1*(yr(2)-yr(1)), ...
             msg, 'FontSize',8,'FontWeight','bold', ...
             'BackgroundColor','w', 'Interpreter','none');
    end

    xlabel(xlab); ylabel('Fish / Person / Day');
    title(ttl); grid on; hold off;
end