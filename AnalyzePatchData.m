% AnalyzePatchData.m
% 
% TODO: Figure out import for RecordingDatabase.xlsx, add columns for OC,WC
% series numbers of interest and pull those.

%% Import Data

% Don't forget to run sigTOOL first!
ephysData = ImportPatchData(ephysData);

% Keep only data with given project prefixes/names.
projects = {'FAT'};

ephysData = FilterProjectData(ephysData, projects);

%% Analyze capacity transient for C, Rs, and tau

ephysData = CtAnalysis(ephysData);

%% Temporary: Assign numbers of IVq series to look at

% TODO: Read these in from a separate file.

allCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT027';'FAT028';'FAT029';'FAT030';'FAT031'};


% List which sets of ct_ivqs to use for on cell (row 1)/whole cell (row 2)
% calculations for the above selection of cells. (i.e., if the second  
% ct_ivq protocol run for that recording was the one you want to use for  
% whole-cell, put "2" in row 1). Make sure it has three sequential ivq
% pgfs.
protStart = [1 1 1 4 1 1 1 1 1 1; ...
             4 4 4 7 4 7 6 4 4 4];

for i = 1:length(allCells)
    ephysData.(allCells{i}).protOC = protStart(1,i);
    ephysData.(allCells{i}).protWC = protStart(2,i);    
end
clear i protStart allCells
%% Process voltage steps
allCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT027';'FAT028';'FAT029';'FAT030';'FAT031';'FAT032'};

testingAll = IVAnalysis(ephysData,allCells);

% TODO: Get multi-group working. Problem = format for outputting groups,
% since current output is a single struct with 
wtCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT032'};
fatCells = {'FAT027';'FAT028';'FAT029'; 'FAT030'; 'FAT031'};

testingSplit = IVAnalysis(ephysData,allCells);


%% Plot I-V Curves (after processing voltage sgteps)
steadyStateTime = 400:550;

TU2769mean = mean(mean(wtCapCorr(steadyStateTime,:,:),1),3);
TU2769_SEM = std(mean(wtCapCorr(steadyStateTime,:,:),1),0,3)/sqrt(size(TU2769mean,3));
GN381mean = mean(mean(fatCapCorr(steadyStateTime,:,:),1),3);
GN381_SEM = std(mean(fatCapCorr(steadyStateTime,:,:),1),0,3)/sqrt(size(GN381mean,3));

vVec = -110:20:110;
figure(); hold on;
errorbar(vVec, TU2769mean/1E-12, TU2769_SEM/1E-12, 'b');
errorbar(vVec, GN381mean/1E-12, GN381_SEM/1E-12, 'r');
% Alternate if you only have one cell, and can't draw error bars:
% plot(vVec, mean(fatCapCorr(steadyStateTime,:,5),1)/1E-12, 'r');

plotfixer;
hline(0,'k');
vline(0,'k');

%% Plot a single cell's iv steps 
dt = 0.2; % ms, based on sampling frequency (5kHz in current ct_ivq)
tVec = 0:dt:210-dt;

% Plotting FAT020 for example
figure();
plot(tVec, (FAT031_WC(:,:,1)-FAT031_OC(:,:,1))/1E-12, 'b');
stepsh(1) = gca;

plotfixer;

% Set axis limits
for iLims = 1:size(stepsh)
    set(stepsh(iLims),'XLim', [0 150])    
    set(stepsh(iLims),'YLim', [-300 300])
end

%% Draw stimulus protocol for IVq
dt = 0.2; % ms, based on sampling frequency (5kHz in current ct_ivq)
tVec = 0:dt:210-dt;
vVec = zeros(length(tVec),12)-60;

for i = 1:12
    vVec(10/dt:110/dt,i)=-110+20*(i-1);
end

plot(tVec,vVec,'r');
plotfixer;


%% Plot mechanically evoked currents in response to single steps

% TODO: Fix this so it can also deal with WC_ProbeSmall and Large, given
% that they have different nSteps and stepSize
% Find all WC_probe protocols
allCells = {'FAT032'};

for iCell = 1:length(allCells)
    protName = 'WC_Probe';
    cellName = allCells{iCell};
    allSeries = find(strcmp(protName,ephysData.(cellName).protocols)); 
    nSeries = length(allSeries);
    nSteps = size(ephysData.(cellName).data{2,allSeries(1)},2);
    
    mechPeaks = zeros(nSeries,nSteps,2);
    stepSize = zeros(nSeries,nSteps);
    onTau = zeros(nSeries,nSteps);
    offTau = zeros(nSeries,nSteps);
    
    for iSeries = 1:nSeries
        probeI = ephysData.(cellName).data{1,allSeries(iSeries)};
        % convert command V to um, at 0.408 V/um
        stimComI = ephysData.(cellName).data{2,allSeries(iSeries)} ./ 0.408;
        sf = 5; %sampling frequency, in kHz
       
        
        
        % Find timepoint in sweep at which probe starts pushing (on) and when it
        % goes back to neutral position (off). Use that timepoint to find nearby
        % peak current
        
        
        for iStep = 1:nSteps
            % Figure out points when stimulus command for step starts and ends
            stepOn = stimComI(:,iStep) - mean(stimComI(1:10*sf,iStep));
            stepStart = find(stepOn > 0.05); % step detection threshold in um
            stepLength = length(stepStart);
            if stepLength == 0
                continue
            end
            stepStart = stepStart(1);
            stepEnd = stepStart + stepLength;
            stepSize (iSeries,iStep) = mean(stepOn(stepStart:stepEnd));
            
            % Get baseline for each step by grabbing the mean of the 250 points before
            % the probe displacement.
            baseProbeI_on = mean(probeI(stepStart-150+1:stepStart-1,iStep));
            baseProbeI_off = mean(probeI(stepEnd-150+1:stepEnd-1,iStep));
            
            % Find the peak current for the on step and the off step for this sweep
            % Two options for ignoring the stimulus artifact (which shows up
            % even with unpatched pipette):
            % Start looking at stepStart +2 (+1 too early, +3 hits actual peak)
            % Swap subtract order and don't use abs(onSubtract) for finding max
            onSubtract = baseProbeI_on - probeI(:,iStep);
            peakOnLoc = find(onSubtract(stepStart+1:stepStart+500) == max(onSubtract(stepStart+1:stepStart+500)));
            peakOnLoc = peakOnLoc(1) + stepStart;
            
            offSubtract = baseProbeI_off - probeI(:,iStep);
            peakOffLoc = find(offSubtract(stepEnd+2:stepEnd+500) == max(offSubtract(stepEnd+2:stepEnd+500)));
            peakOffLoc = peakOffLoc(1)+stepEnd;
            
            mechPeaks(iSeries,iStep,1) = -onSubtract(peakOnLoc);
            mechPeaks(iSeries,iStep,2) = -offSubtract(peakOffLoc);
            
            [~,onFitInd] = min(abs(onSubtract(peakOnLoc:75*sf+peakOnLoc)-(onSubtract(peakOnLoc)/(2*exp(1)))));
            [~,offFitInd] = min(abs(offSubtract(peakOffLoc:75*sf+peakOffLoc)-(offSubtract(peakOffLoc)/(2*exp(1)))));
            
            onFitTime = onFitInd/sf; % seconds
            onT = 0:1/sf:onFitTime;
            offFitTime = offFitInd/sf; % seconds
            offT = 0:1/sf:offFitTime;

            
            onFit = fit(onT',onSubtract(peakOnLoc:peakOnLoc+onFitInd),'exp1');
            offFit = fit(offT',onSubtract(peakOffLoc:peakOffLoc+offFitInd),'exp1');
            %     plot(capFit,t,ICt(intStart:intStart+minInd));
            
            % Calculate time constant in seconds for calculation
            onTau(iSeries,iStep) = -1/onFit.b;
            offTau(iSeries,iStep) = -1/offFit.b;
            
            % TODO: Fit with an alpha function instead of exp1 to get tau1 and tau2
        end
        
        
    end
    
    % Using this instead of mean function to get around the problem of
    % series with different numbers of sweeps. This only takes the average
    % of non-zero elements for each position
%     mechPeaksMean = reshape(sum(mechPeaks,1)./sum(mechPeaks~=0,1),size(mechPeaks,2),2);
    mechPeaksMean = reshape(mean(mechPeaks,1),size(mechPeaks,2),2);
    
    % TODO: This actually needs to be a scatterplot and a trendline, not a
    % line graph.
    figure()
    hold on;
    plot(mean(stepSize,1),mechPeaksMean(:,1)/1E-12,'b')
    plot(mean(stepSize,1),mechPeaksMean(:,2)/1E-12,'r')
    set(gca,'YDir','reverse');
    plotfixer;
end

clear protName cellName allSeries allCells iCell nSeries nSteps iSeries iStep sf 

% dt = 0.001; % s
% tVec = 0:dt:7-dt;
% 
% figure()
% plot(tVec, probeI(:,1)/1E-12)
% figure()
% plot(tVec, probeI(:,5)/1E-12)
% figure()
% plot(tVec, probeI(:,9)/1E-12)

%% Plot single MRC sets
% Draw stim protocol for MRCs
dt = 0.2; % ms, based on sampling frequency (5kHz in current WC_Probe)
tVec = 0:dt:750-dt;
dVec = zeros(length(tVec),12);

% for i = 1:6
%     dVec(50/dt:250/dt,i)=1+2*(i-1);
% end
% 
% figure()
% plot(tVec,dVec,'r');
% plotfixer;

% Get data
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,1);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,2);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,3);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,4);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,5);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,6);
% plot(tVec,toPlot/1E-12);

figure()
toPlot = ephysData.FAT032.data{1,18};
plot(tVec,toPlot/1E-12,'b');
plotfixer;

%% ISI validation

% Validate that interstimulus interval is long enough for full recovery
% from stimulus by running a step with the ISI of choice 16-32x. Check to
% see whether on/off currents amplitude is steady over time.
allCells = {'FAT032'};

for iCell = 1:length(allCells)
    protName = 'WC_Probe5';
    cellName = allCells{iCell};
    allSeries = find(strcmp(protName,ephysData.(cellName).protocols)); 
    nSeries = length(allSeries);
    nSteps = size(ephysData.(cellName).data{2,allSeries(1)},2);

    ISIPeaks = zeros(nSeries,nSteps,2);
    stepSize = zeros(nSeries,nSteps);
    onTau = zeros(nSeries,nSteps);
    offTau = zeros(nSeries,nSteps);
    
    for iSeries = 1:nSeries
        probeI = ephysData.(cellName).data{1,allSeries(iSeries)};
        % convert command V to um, at 0.408 V/um for current setup(5-15-15)
        stimComI = ephysData.(cellName).data{2,allSeries(iSeries)} ./ 0.408;
        sf = 5; %sampling frequency, in kHz
            
        % Find timepoint in sweep at which probe starts pushing (on) and when it
        % goes back to neutral position (off). Use that timepoint to find nearby
        % peak current
        
        for iStep = 1:nSteps
            % Figure out points when stimulus command for step starts and ends
            stepOn = stimComI(:,iStep) - mean(stimComI(1:10*sf,iStep));
            stepStart = find(stepOn > 0.05); % step detection threshold in um
            stepLength = length(stepStart);
            if stepLength == 0
                continue
            end
            stepStart = stepStart(1);
            stepEnd = stepStart + stepLength;
            stepSize (iSeries,iStep) = mean(stepOn(stepStart:stepEnd));
            
            % Get baseline for each step by grabbing the mean of the 250 points before
            % the probe displacement.
            baseProbeI_on = mean(probeI(stepStart-150+1:stepStart-1,iStep));
            baseProbeI_off = mean(probeI(stepEnd-150+1:stepEnd-1,iStep));
            
            % Find the peak current for the on step and the off step for this sweep
            % Two options for ignoring the stimulus artifact (which shows up
            % even with unpatched pipette):
            % Start looking at stepStart +2 (+1 too early, +3 hits actual peak)
            % Swap subtract order and don't use abs(onSubtract) for finding max
            onSubtract = baseProbeI_on - probeI(:,iStep);
            peakOnLoc = find(onSubtract(stepStart+1:stepStart+500) == max(onSubtract(stepStart+1:stepStart+500)));
            peakOnLoc = peakOnLoc(1) + stepStart;
            
            offSubtract = baseProbeI_off - probeI(:,iStep);
            peakOffLoc = find(offSubtract(stepEnd+2:stepEnd+500) == max(offSubtract(stepEnd+2:stepEnd+500)));
            peakOffLoc = peakOffLoc(1)+stepEnd;
            
            ISIPeaks(iSeries,iStep,1) = -onSubtract(peakOnLoc);
            ISIPeaks(iSeries,iStep,2) = -offSubtract(peakOffLoc);
            
            [~,onFitInd] = min(abs(onSubtract(peakOnLoc:75*sf+peakOnLoc)-(onSubtract(peakOnLoc)/(2*exp(1)))));
            [~,offFitInd] = min(abs(offSubtract(peakOffLoc:75*sf+peakOffLoc)-(offSubtract(peakOffLoc)/(2*exp(1)))));
            
            onFitTime = onFitInd/sf; % seconds
            onT = 0:1/sf:onFitTime;
            offFitTime = offFitInd/sf; % seconds
            offT = 0:1/sf:offFitTime;

            
            onFit = fit(onT',onSubtract(peakOnLoc:peakOnLoc+onFitInd),'exp1');
            offFit = fit(offT',onSubtract(peakOffLoc:peakOffLoc+offFitInd),'exp1');
            %     plot(capFit,t,ICt(intStart:intStart+minInd));
            
            % Calculate time constant in seconds for calculation
            onTau(iSeries,iStep) = -1/onFit.b;
            offTau(iSeries,iStep) = -1/offFit.b;
            
            % TODO: Fit with an alpha function instead of exp1 to get tau1 and tau2
        end
        
        
    end

end
%% Dt 

%% Look at current clamp
allCells = fieldnames(ephysData);

for iCell = 1:length(allCells)
    cellName = allCells{iCell}; %split into project name and cell numbers when feeding input
    
    % UPDATE: after June/July 2014 (FAT025), Patchmaster has separate pgfs for
    % 'OC_ct_neg' and 'WC_ct_neg' to make it easier to pull out only capacity
    % transients of interest without having to check the notebook.
    protName = 'cc_gapfree';
    % two alternatives for finding instances of the desired protocol
    % find(~cellfun('isempty',strfind(ephysData.(cellName).protocols,'ct_neg')));
    protLoc = find(strncmp(protName,ephysData.(cellName).protocols,6));
    
    if protLoc
        for i = 1:length(protLoc)
            gapfree(:,i) = ephysData.(cellName).data{1,protLoc(i)};
        end
        basalVoltage{iCell} = gapfree;
    end
end

clear allCells iCell cellName protName protLoc i gapfree;