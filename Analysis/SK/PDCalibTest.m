% PDCalibTest.m
%
%

%TODO: Read in list of calibrations? Or autosearch for ProbeCalib protocol
%and perform this on all instances of that?
nCalibs = 3;

% Temporarily defining calibration protocol locations, later, auto-detect
% and associate each with the given ephysData recording rather than just
% the stepValues variable.
% calibData(:,1) = ephysData.TestCalibrationWorm1.data{3,4};
% calibData(:,2) = ephysData.Worm_B.data{3,11};
% calibData(:,3) = ephysData.Worm_C.data{3,9};
calibData(:,1) = ephysData.PutUnloadCalib.data{3,44};
% calibData(:,2) = ephysData.PutUnloadCalib.data{3,46};
calibData(:,2) = ephysData.Calibrated.data{2,11};
calibData(:,3) = ephysData.Calibrated.data{2,12};

for i = 1:nCalibs
    clear handles;
    plotData = calibData(:,i);
    
    % Run GUI for selecting ranges (hit Begin Selection, then place data
    % cursors in pairs around your ranges. shift-Click for each new data
    % cursor, and click to move the most recently active cursor, or move
    % any cursor at a later time, but be sure to keep them paired with the
    % same start/end cursor).
    %TODO: Fix the datatip labels.
    handles = selectCalibSteps(plotData);
    
    % Pull out the mean value of the signal between the indices set by the
    % user's cursor placement. Store in stepValues with [recordings, steps]
    stepIdx = handles.cursorPoints(:,1);
    stepIdx = reshape(stepIdx,2,[])';
    for j = 1:size(stepIdx,1)
        stepValues(i,j) = mean(plotData(stepIdx(j,1):stepIdx(j,2)))';
    end
end


dVec = [0 2.5 5 7.5 10];
dcmap = [0.4 0.4 0.4; 0.7 0.7 0.7; 1 0 0];
set(gca, 'ColorOrder', dcmap)
hold on
plot(dVec,stepValues)

% Switch x/y to allow feeding in the actual PD data from WC_Probe steps
aDisp = interp1(stepValues(1,:), dVecAxial, aSteps,'linear','extrap');
bDisp = interp1(stepValues(1,:), dVecAxial, bSteps,'linear','extrap');