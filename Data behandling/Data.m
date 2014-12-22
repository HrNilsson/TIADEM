data = dlmread('2014-12-22 20-13-52.txt'); % Stable measurements
%data = dlmread('2014-12-22 16-37-55.txt'); % Unstable measurements
%data = dlmread('2014-12-22 15-49-36.txt');
%data = dlmread('2014-12-22 15-26-48.txt');
%data = dlmread('2014-12-22 12-42-09.txt');

j = 1;
pairedData = zeros(length(data),6);
% pairedData = [timeSyncError, beaconPeriod, drift, skew, temp, seq, timestamp]
for i = 1:length(data)-1
   if ((abs(data(i,7) - data (i+1,7)) < 50) && (data(i,1)-data(i+1,1) ~= 0))
       if (abs(data(i,2)-data(i+1,2)) > 1000000)
           % outlier
           continue;
       end
       
       if(data(i,1) == 1) % parent is i, child is i+1
            pairedData(j,1) = data(i,2)-data(i+1,2);
            pairedData(j,2) = data(i,3);
            pairedData(j,3) = data(i,4);
            pairedData(j,4) = data(i+1,4);
            pairedData(j,5) = data(i+1,5);
            pairedData(j,6) = data(i,6);
            pairedData(j,7) = data(i,7);
       else % parent is i+1, child is i
            pairedData(j,1) = data(i+1,2)-data(i,2);
            pairedData(j,2) = data(i+1,3);
            pairedData(j,3) = data(i+1,4);
            pairedData(j,4) = data(i,4);
            pairedData(j,5) = data(i,5);
            pairedData(j,6) = data(i+1,6);
            pairedData(j,7) = data(i+1,7);
       end
       j = j+1;
   else
       % no match
   end
end
pairedData  = pairedData(1:j-1,:);

% Remove unwanted parts:
%pairedData  = pairedData(11:length(pairedData),:); %Unstable
pairedData  = pairedData(30:length(pairedData)/2-75,:); %Stable

% Normalize timestamps
pairedData(:,7) = (pairedData(:,7)-pairedData(1,7))/1000;

figure(1)
clf

% SyncError, beacon period, temperature and error bound vs time
[hAx,pBeacon,pError] = plotyy(pairedData(:,7),pairedData(:,2),pairedData(:,7),pairedData(:,1));
set(get(hAx(1),'Ylabel'),'String','Beacon period [s] | Temperature [C]') 
set(get(hAx(2),'Ylabel'),'String','Synchronization error [ms]')

axes(hAx(1))
hold on
plot(pairedData(:,7),pairedData(:,5),'--b');
axes(hAx(2))
hold on
plot(pairedData(:,7),ones(size(pairedData(:,7)))*2,'--r');

title('Time Synchronization Error')
xlabel('Time')

grid minor
legend(...
    'Synchronization error',...
    'Average error bound',...
    'Beacon period [s]',...
    'Temperature [C]')

%%
figure(2)
% Drift and temperature vs time
[hAx2,pBeacon,pError] = plotyy(pairedData(:,7),pairedData(:,3),pairedData(:,7),pairedData(:,5)); 

title('Drift and temperature')
xlabel('Time')

ylabel(hAx2(1),'Drift ms / s^2') % left y-axis
ylabel(hAx2(2),'Temperature [C]') % right y-axis

grid minor
legend(...
    'Drift [ms/s^2]',...
    'Temperature [C]')

figure(3)
% Skew and temperature vs time
[hAx2,pBeacon,pError] = plotyy(pairedData(:,7),pairedData(:,4),pairedData(:,7),pairedData(:,5)); 

title('Skew and temperature')
xlabel('Time')

ylabel(hAx2(1),'Skew ms / s') % left y-axis
ylabel(hAx2(2),'Temperature [C]') % right y-axis

grid minor
legend(...
    'Skew [ms/s]',...
    'Temperature [C]')