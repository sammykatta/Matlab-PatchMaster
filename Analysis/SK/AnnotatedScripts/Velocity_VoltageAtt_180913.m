% I-d and Q-d curves for velocity steps (corrected for space clamp)
% Current or charge vs. displacement, and vs. distance 

% This version uses TrapRate protocols, which have both the on and the off
% at the same velocity (except for one particular velocity where
% Patchmaster refused to do the off at the same velocity), in a trapezoid
% shape.

% At the moment, this is limited to anterior recordings, filtered at both
% 2.5 or 5 kHz (because we can see the actual velocity).

%%Import data and metadata
ephysData = ImportPatchData('incl',1);
projects = {'FAT';'SYM'};
ephysData = FilterProjectData(ephysData, projects);
%fix a couple messed up names
ephysData.FAT029 = ephysData.FAT029s;
ephysData.FAT017 = ephysData.FAT017e001;
ephysData.FAT164 = ephysData.FAT164001;
ephysData = rmfield(ephysData,{'FAT017e001';'FAT029s';'FAT164001'});

clear projects;

ephysMetaData = ImportMetaData();  %Recording Database.xlsx
attenuationData = ImportMetaData(); %AttenuationCalcs_IC2_180810.xlsx

%% Analyze capacity transient for C, Rs, and tau

ephysData = CtAnalysis(ephysData);

clear lastfit;

%% Select recordings that match parameters based on metadata

strainList = {'TU2769'};
internalList = {'IC2'};

wormPrep = {'dissected'};
cellDist = [40 200]; % stimulus/cell distance in um
resistCutoff = '<250'; % Rs < 250 MOhm
extFilterFreq = [2.5 5]; % frequency of low-pass filter for stimulus command
includeFlag = 1; 

stimPosition = {'anterior'};

velocityCells = FilterRecordings(ephysData, ephysMetaData,...
    'strain', strainList, 'internal', internalList, ...
    'stimLocation', stimPosition, 'wormPrep', wormPrep, ...
    'cellStimDistUm',cellDist, 'RsM', resistCutoff, ...
    'stimFilterFrequencykHz', extFilterFreq, 'included', includeFlag);


clear cellDist strainList internalList cellTypeList stimPosition resistCutoff ans wormPrep excludeCells;


%% Visual/manual exclusion of bad sweeps 
% This is mainly based on excluding sweeps with leak > 10pA, but also
% sweeps where the recording was lost partway through or some unexpected
% source of noise was clearly at play.

protList ={'TrapRate'};
matchType = 'first';

ExcludeSweeps(ephysData, protList, velocityCells, 'matchType', matchType);

% This results in a file with three columns: cell ID, series, and sweeps 
% that have been approved for analysis use.

%% Find MRCs 
% antTraps_allFreq(180913).xls
protList ={'TrapRate'};
matchType = 'first';

sortSweeps = {'velocity','velocity','magnitude','magnitude'};

[velocityMRCs, velocityStim] = IdAnalysis(ephysData,protList,velocityCells,'num','matchType',matchType, ...
    'tauType','thalfmax', 'sortSweepsBy', sortSweeps, 'integrateCurrent',1 , ...
    'recParameters', ephysMetaData,'sepByStimDistance',1,'pdCompare',1,'subZeroCharge',1);

clear protList sortSweeps matchType

%% Quick plot for looking at asymmetry in slow velocities
figure();
for i = 1:8
axh(i) = subtightplot(2,4,i);
plot(velocityMRCs{i,2}([5 4 3 2 1],:)');
cmapline('ax',gca,'colormap','parula');
end
linkaxes(axh,'xy');
plotfixer;

% %% Get normalized mean traces (normalized to highest velocity)
% % Can then use normVelocityMRCs as input for the final
% normVelocitySweeps = cellfun(@(x,y) x./y(end,6),velocityMRCs(:,2),velocityMRCs(:,3),'un',0);
% normVelocityMRCs = velocityMRCs;
% normVelocityMRCs(:,2) = normVelocitySweeps;
%% Quick plot for selecting representative traces
figure();
for i = 1:8
axh(i) = subtightplot(2,4,i);
plot(velocityMRCs{i,2}');
cmapline('ax',gca,'colormap','parula');
end
linkaxes(axh,'xy');

figure();
plot(velocityMRCs{1,2}');
cmapline('ax',gca,'colormap','copper');

%% Plot selected representative traces and stimuli
% FAT214 with on ramps for 106, 785, 1560, 7230, 39740 um/s
whichTraces = [3 5 6 10 12];

% Grab stimuli based on velocityStim (second output from IdAnalysis)
% Just example stim from one single trace, not averaged
stimTrace = cell(0);
stimTrace{1} = ephysData.FAT214.data{2,18}(:,2);
stimTrace{2} = ephysData.FAT214.data{2,11}(:,2);
stimTrace{3} = ephysData.FAT214.data{2,12}(:,3);
stimTrace{4} = ephysData.FAT214.data{2,12}(:,4);
stimTrace{5} = ephysData.FAT214.data{2,17}(:,5);

% Plot calibrated photodiode trace as alternative
a = ephysData.FAT214.data{3,24}; % probe steps
a = a-mean(a(1:3000));
b = ephysData.FAT214.data{3,25}-ephysData.FAT214.data{3,26}; %pd steps minus worm only pd steps
b = b-mean(b(1:3000));
c = [0 2.5 5 7.5 10 12.5];

% calibCells = {'FAT214'};
% calibData = cell(0);
% calibData{1} = b;
% 
% clear handles;
% plotData = calibData{:,1};
% handles = selectCalibSteps(plotData,calibCells{1});
% stepIdx = handles.cursorPoints(:,1);
% stepIdx = reshape(stepIdx,2,[])';
% for j = 1:size(stepIdx,1)
%     stepValues(1,j) = mean(plotData(stepIdx(j,1):stepIdx(j,2)))';
% end
% close;      
% d = stepValues(1:6);
d = [0.000254495420305394,-0.0837948030556295,-0.321306248450060,-0.664159366423493,-1.04265743523145,-1.44646508446994];
e = velocityStim{1,3};
f = interp1(-d,c,-e,'pchip');
pdTrace = f(whichTraces,:);

%pad to same length
sweepLengths = cellfun('length',stimTrace);
maxLength = max(sweepLengths);
stimTrace = cellfun(@(x)cat(1,x,NaN(maxLength-length(x),1)),stimTrace,'UniformOutput',false);
stimTrace = cell2mat(stimTrace);
stimZero = mean(stimTrace(1:100,:),1);
stimTrace = stimTrace - repmat(stimZero,[10000 1]);
stimTrace = stimTrace/0.408;
tVec = (1:length(velocityMRCs{1,2}))/10; % time in ms

figure();
axh(1)=subplot(2,1,1);
plot(tVec,pdTrace);
cmapline('ax',gca,'colormap','copper');
chH = get(gca,'children');
set(gca,'children',flipud(chH));

axh(2)=subplot(2,1,2);
plot(tVec,velocityMRCs{1,2}(whichTraces,:)');
linkaxes(axh,'x');
cmapline('ax',gca,'colormap','copper');
chH = get(gca,'children');
set(gca,'children',flipud(chH));
ylim([-10e-11 1e-11]);
plotfixer();

% Ramp start and end times for the given velocities were pulled manually 
% from the velocityStim parameter tables. (80um/s off start = 5503, 106 = 5253).
onStart = 1500;
offStart = [5253; 4601; 4551; 4511; 4501];

boxSize = [-10 50];
onBox = [onStart onStart]/10 + boxSize;
offBox = [offStart offStart]/10 + repmat(boxSize,5,1);

% Add lines to demarcate on and off ramp starts
onH{1} = vline(onBox(1));
onH{2} = vline(onBox(2));
offH{1} = vline(offBox(:,1));
offH{2} = vline(offBox(:,2),'b:');
cmapline('lines',offH{1}','colormap','bone');
cmapline('lines',offH{2}','colormap','bone');

%% Plot representative trace expansions
figure();
axh(1)=subplot(2,1,1);
plot(tVec,velocityMRCs{1,2}(whichTraces,:)');
xlim(onBox);ylim([-10e-11 1e-11]);
cmapline('ax',gca,'colormap','copper');
chH = get(gca,'children');
set(gca,'children',flipud(chH));


tVec_Off = repmat(tVec,5,1);
tVec_Off = tVec_Off - repmat(offStart/10,1,10000);

axh(2)=subplot(2,1,2);
plot(tVec_Off',velocityMRCs{1,2}(whichTraces,:)');
xlim(boxSize);ylim([-10e-11 1e-11]);
cmapline('ax',gca,'colormap','copper');
chH = get(gca,'children');
set(gca,'children',flipud(chH));

linkaxes(axh,'y');
plotfixer;

%% Separate and write representative traces for channel-sim-distance figure

% FAT218 mean traces at 106um/s, 320, 3790 separated by on/off
% stimulus, from [stimStart-250, stimEnd+250]ms.
onStimStart = 1503; onStimEnd = 2250;
offStimStart = [5253; 4752; 4521]; offStimEnd = offStimStart + 747;
sf = 10; %kHz
boxTime = 150*sf; %ms
onBox = [onStimStart-boxTime onStimEnd+boxTime];
offBox = [offStimStart-boxTime offStimEnd+boxTime];


reps(:,1:3) = velocityMRCs{4,2}([3 4 8],onBox(1):onBox(2))';
reps(:,4) = velocityMRCs{4,2}(3,offBox(1,1):offBox(1,2))';
reps(:,5) = velocityMRCs{4,2}(4,offBox(2,1):offBox(2,2))';
reps(:,6) = velocityMRCs{4,2}(8,offBox(3,1):offBox(3,2))';

tVec = ((1:length(reps))-boxTime-1)'./(sf*1000);

%% Pull out and combine data to plot one particular velocity vs. distance

% Voltage attenuation data comes from the length constant fitting done in
% Igor, which gives a voltage attenuation factor at the location of the
% stimulus site for each recording, based on the calculated length
% constant.

% Grab the current at the selected step size (e.g., 10um) for each
% recording, grab the cell-stimulus distance for that recording, and match
% the recording name against the voltage attenuation table to find the
% attenuation factor for that recording.
whichMRCs = velocityMRCs;
thisAtt = attenuationData(:,[2 8 10]);
distCol = 12;
peakCol = 11; % 6 for peak current, 11 for integrated current/charge
distVPeak = [];
stepVel = 11360;

for iCell = 1:size(whichMRCs,1)
    thisCell = whichMRCs{iCell,3};
    whichVel = round(thisCell(:,1)) == stepVel;
    if any(whichVel)
        thisName = whichMRCs{iCell,1};
        hasAtt = strcmp(thisName,thisAtt(:,1));
        
        if any(hasAtt) && thisAtt{hasAtt,2}
            distVPeak(iCell,:) = [thisCell(whichVel,[distCol peakCol]) thisAtt{hasAtt,3}];
        else
            distVPeak(iCell,:) = [thisCell(whichVel,[distCol peakCol]) nan];
        end
        
    end
    
end

distVPeak_On = distVPeak;


% Off ramps

distVPeak = [];

for iCell = 1:size(whichMRCs,1)
    thisCell = whichMRCs{iCell,4};
    whichVel = round(thisCell(:,1)) == -stepVel;
    if any(whichVel)
        thisName = whichMRCs{iCell,1};
        hasAtt = strcmp(thisName,thisAtt(:,1));
        
        if any(hasAtt) && thisAtt{hasAtt,2}
            try distVPeak(iCell,:) = [thisCell(whichVel,[distCol peakCol]) thisAtt{hasAtt,3}];
            catch
                distVPeak(iCell,:) = [mean(thisCell(whichVel,[distCol peakCol]),1) thisAtt{hasAtt,3}];
            end
        else
            try distVPeak(iCell,:) = [thisCell(whichVel,[distCol peakCol]) nan];
            catch
                distVPeak(iCell,:) = [mean(thisCell(whichVel,[distCol peakCol]),1) nan];
            end
        end
        
    end
    
end

distVPeak_Off = distVPeak;

clear a iCell thisCell whichMRCs whichStep thisName hasAtt distVPeak

%% Make correction to I for space clamp error for one particular velocity
% (Note: this is an approximation, assuming that the majority of the
% current is happening at the stimulus site, which we know is not entirely
% true, and channels at different points along the neurite will experience
% different voltages.

% Now calculate what the actual voltage was at the stimulus site based on
% the voltage attenuation factor. In this case, command voltage was -60mV
% for all steps. 

% attenuation factor = Vm'/Vc so Vm' = Vc * attenuation factor
 
% Then calculate what current would've been based on sodium reversal
% potential. 
% For IC2 solution used here, Ena = +94mV.
 
% Im' = Im * ((Vc-Ena)/(Vm'-Ena))
 
Vc = -0.06; %in V
Ena = 0.094; % in V
Im = distVPeak_On(:,2);
Vatt = distVPeak_On(:,3);

Vm = Vc * Vatt;
distVPeak_On(:,4) = (Im * (Vc-Ena)) ./ (Vm-Ena);


Im = distVPeak_Off(:,2);
Vatt = distVPeak_Off(:,3);

Vm = Vc * Vatt;
distVPeak_Off(:,4) = (Im * (Vc-Ena)) ./ (Vm-Ena);


%% Plot on and off currents vs distance for one velocity

figure();
scatter(distVPeak_On(:,1),distVPeak_On(:,4),'b');
hold on;
scatter(distVPeak_Off(:,1),distVPeak_Off(:,4),'r');
xlabel('Distance from cell body (um)');
ylabel(sprintf('Current @%dum (pA)',stepVel))
xlim(gca,[0 200]);
ylim(gca,[0 200]);
legend({'On current','Off current'});


%% Correct all velocities and export for Igor fitting of Boltzmann to each recording

% Set the filename
fname = 'PatchData/int_attCorrectedVel(190703).xls';
noCorr = 0;
normFlag = 1; %normalize to 40mm/s ramp (highest velocity "step")
normVel = 39740; % must be negative for off
tol = 12;
dType = 'decay';

for i = 1:2
whichRamp = i; % 1 for on currents, 2 for off currents
switch dType
    case 'peak'
        peakCol = 6;
    case 'charge'
        peakCol = 11;
    case 'act'
        peakCol = 8;
    case 'decay'
        peakCol = 9;
end
distCol = 12;

allVel = vertcat(velocityMRCs{:,whichRamp+2});
eachVel = uniquetol(allVel(:,1),tol,'DataScale',1);
% the value of 12 is empirically chosen as being larger than the largest
% difference between velocities that could be binned (usually 10 after roundVel) and smaller than the
% difference between velocities that shouldn't (i.e., 64 vs. 80).
distLimits = [40 200];
% limit to same average distance for anterior and posterior
if whichRamp == 2
    normVel = -normVel;
end

Vc = -0.06; %in V
Ena = 0.094; % in V

whichMRCs = velocityMRCs;
thisAtt = attenuationData(:,[2 8 10]);
thisName = cell(0);
vel_Out = cell(length(eachVel)+1,size(whichMRCs,1));

for iCell = 1:size(whichMRCs,1)
    thisCell = whichMRCs{iCell,whichRamp+2};
    thisDist = mean(thisCell(:,distCol)); % check if cell distance is in range
    if thisDist <= distLimits(2) && thisDist >= distLimits(1)
        thisName{iCell,1} = whichMRCs{iCell,1}; %name
        thisName{iCell,2} = thisDist;
        vel_Out{1,iCell} = sprintf('%s_%s_stim%d',thisName{iCell,1},dType,whichRamp);
        hasAtt = strcmp(thisName{iCell,1},thisAtt(:,1));
        Iact = [];
        
        for iVel = 1:length(eachVel)
            stepVel = eachVel(iVel);
            whichVel = abs(thisCell(:,1) - stepVel) < tol; %find closest velocity
            if any(whichVel)
                if any(hasAtt) && thisAtt{hasAtt,2} %if attenuation calc exists and not omitCell
                    if noCorr == 0 && strcmp(dType,'peak') || strcmp(dType,'charge') %attenuation correction for current/charge but not taus
                        Vm = Vc * thisAtt{hasAtt,3};
                        Im = thisCell(whichVel,peakCol);
                        if length(Im) > 1
                            %multiple profiles containing this velocity, take mean weighted by nReps
                            Im = sum((thisCell(whichVel,peakCol).*thisCell(whichVel,end)))/sum(thisCell(whichVel,end));
                        end
                        
                        Iact(iVel,1) = (Im * (Vc-Ena)) ./ (Vm-Ena);
                    else
                        Im = thisCell(whichVel,peakCol);
                        if length(Im) > 1
                            %multiple profiles containing this velocity, take mean weighted by nReps
                            Im = sum((thisCell(whichVel,peakCol).*thisCell(whichVel,end)))/sum(thisCell(whichVel,end));
                        end
                        Iact(iVel,1) = Im;
                    end
                else
                    Iact(iVel,1) = nan;
                end

                
            else
                Iact(iVel,1) = nan;
            end
        end
        
        if whichRamp == 2
            Iact = flipud(Iact);
        end
        vel_Out(2:length(eachVel)+1,iCell) = num2cell(Iact);
            
    end
end

if whichRamp == 2
    eachVel = flipud(eachVel);
end

thisName(:,1) = cellfun(@(x) sprintf('%s',x),thisName(:,1),'un',0);
vel_Name = [{sprintf('Anterior_stim%d',whichRamp), sprintf('Ant_Dist_stim%d',whichRamp)}; thisName];
vel_Out = vel_Out(:,~cellfun(@isempty, vel_Out(1,:))); % clear out empty waves (where dist didn't match)
vel_Name = vel_Name(~cellfun(@isempty, vel_Name(:,1)),:);

vel_Out = [[{sprintf('vel_stim%d',whichRamp)};num2cell(eachVel)] vel_Out]; % append stepSize wave



xlswrite(fname,vel_Out,sprintf('%s_stim%d',dType,whichRamp));
xlswrite(fname,vel_Name,sprintf('%sStats_stim%d',dType,whichRamp));

% Normalize based on current/charge at given step size and write to xls
if normFlag && strcmp(dType,'peak') || strcmp(dType,'charge')
    %WT
    which_Out = vel_Out;
    norm_Out = cell(size(which_Out));
    
    currMat = cell2mat(which_Out(2:end,2:end));
    whichRow = find(cellfun(@(x) abs(x-normVel)<tol, which_Out(2:end,1)));
    normRow = currMat(whichRow,:);
    normMat = bsxfun(@rdivide,currMat,normRow);
    norm_Out(2:end,2:end) = num2cell(normMat);
    norm_Out(:,1) = which_Out(:,1);
    norm_Out(1,2:end) = cellfun(@(x) ['norm_' x],which_Out(1,2:end),'un',0);
    
    
    this_Norm = norm_Out;
    this_Max = normRow';
    
    xlswrite(fname,this_Norm,['stim' num2str(whichRamp) '_' dType '_Norm']);
    xlswrite(fname,this_Max,['stim' num2str(whichRamp) '_' dType '_Max']);
    
    clear currMat which Row normRow normMat norm_Out
end


clear iCell thisCell Iact whichMRCs whichStep hasAtt thisAtt Vc Ena thisName
end

%% Calculate ratios
% re-save vel_Out as on/offVelChrg and on/offVelPeak for the corresponding
% cases
on = antOnChar;
off = antOffChar;
out = on(1,:);

onVel = [on{2:end,1}];
offVel = -[off{2:end,1}];


for i = 1:length(onVel)
   whichVel = abs(onVel(i)-offVel)<12;
   if any(whichVel)
       thisVel = find(whichVel);
       out{i+1,1} = offVel(thisVel);
       out(i+1,2:end) = cellfun(@(x,y) x./y, off(thisVel+1,2:end), on(i+1,2:end),'un',0);
   end
end

out = out(~cellfun(@isempty,out(:,1)),:);
out(1,:) = cellfun(@(x) regexprep(x,'stim1','ratio'),out(1,:),'un',0);

xlswrite(fname,out,sprintf('velChrg_ratio'));


%% Renormalize

% The point of the remaining code is to grab the data from Igor or from an Excel
% sheet after fitting individual I-d curves to get max/delta/xhalf from the
% Boltzmann fit, then normalize each I-d curve to its predicted max, and
% export back into an Igor-readable format for plotting.

% From AttCorrectedID_Curve.m

% From Igor, export the entire Igor file as a csv
%% Import fits from Igor table

fitStats = ImportMetaData(); %AttCorrectedI-D_fitstats.xlsx
fitHeaders = fitStats(1,:);
fitStats = fitStats(2:end,:);

%% Get names and match up stats
antStats = fitStats(:,cell2mat(cellfun(@(x) ~isempty(regexp(x,'Ant')), fitHeaders,'un',0)));
postStats = fitStats(:,cell2mat(cellfun(@(x) ~isempty(regexp(x,'Post')), fitHeaders,'un',0)));
antMaxIdx = find(~cellfun(@isempty,(regexp(fitHeaders(:,cell2mat(cellfun(@(x) ~isempty(regexp(x,'Ant')), fitHeaders,'un',0))),'[mM]ax'))));
postMaxIdx = find(~cellfun(@isempty,(regexp(fitHeaders(:,cell2mat(cellfun(@(x) ~isempty(regexp(x,'Post')), fitHeaders,'un',0))),'[mM]ax'))));
antStats = antStats(cellfun(@(x) ~isnumeric(x), antStats(:,1)),:);
postStats = postStats(cellfun(@(x) ~isnumeric(x), postStats(:,1)),:);

% this gives five columns: name, delta, distance, max, xhalf

% straight up taking the fits and recoloring them here won't work because 
% Igor fits are all 200 points long but the X wave
% is calculated, and is different length for each (i.e., some curves have
% X values from 0.5 to 11, some from 3 to 10, etc., and those ranges
% determine what the x values are for each fit separately).

% instead, I'm just going to do the normalization here and send the waves
% back to Igor, where I can average them like the other I-dCellFits

%%
eachVel = fitStats(:,cell2mat(cellfun(@(x) ~isempty(regexp(x,'stepSize')), fitHeaders,'un',0)));
eachVel = eachVel(cellfun(@(x) isnumeric(x) && ~isnan(x),eachVel));

whichSide = antStats;
thisCell = whichSide(:,1);
thisDataNorm = cell(0);

for i = 1:size(whichSide,1)
   thisMax = whichSide{i,antMaxIdx};
   whichData = cell2mat(cellfun(@(x) ~isempty(regexp(x,sprintf('^(?!fit).*%s',thisCell{i}))),fitHeaders,'un',0));
   thisData = fitStats(1:length(eachVel),whichData);
   thisData(cellfun(@isempty,thisData))={nan};
   thisDataNorm(:,i) = cellfun(@(x) x./thisMax, thisData,'un',0);
end

antNorm = thisDataNorm;
antHeaders = cellfun(@(x) sprintf('%s_Norm',x),thisCell,'un',0)';


% POSTERIOR
whichSide = postStats;
thisCell = whichSide(:,1);
thisDataNorm = cell(0);

for i = 1:size(whichSide,1)
   thisMax = whichSide{i,postMaxIdx};
   whichData = cell2mat(cellfun(@(x) ~isempty(regexp(x,sprintf('^(?!fit).*%s',thisCell{i}))),fitHeaders,'un',0));
   thisData = fitStats(1:length(eachVel),whichData);
   thisData(cellfun(@isempty,thisData))={nan};
   thisDataNorm(:,i) = cellfun(@(x) x./thisMax, thisData,'un',0);
end

postNorm = thisDataNorm;
postHeaders = cellfun(@(x) sprintf('%s_Norm',x),thisCell,'un',0)';

%%

xlswrite(fname,antHeaders,'antNorm');
xlswrite(fname,postHeaders,'postNorm');
xlswrite(fname,antNorm,'antNorm','A2');
xlswrite(fname,postNorm,'postNorm','A2');

