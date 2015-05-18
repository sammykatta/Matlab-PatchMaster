function capCorrIV = IVAnalysis(ephysData, varargin)

% keyboard;
%
nGroups = nargin-1;
if nGroups < 1
    error('NoGroups','Please provide names of recordings in a columnar cell array.')
end

for iGroup = 1:nGroups
    groupCells = varargin{iGroup};
    
    for iCell = 1:length(groupCells)
        cellName = groupCells{iCell}; %TODO: maybe split into project name and cell numbers when feeding input
        
        protName = 'IVq';
        % Flip protName and actual protocol names to compare the last 3 letters
        % when looking for IVq, to get all IVqs without regard to OC vs. WC. Be
        % wary of extra IVqs run separately/not as part of ct_IVq.
        flippedProts = cellfun(@fliplr, ephysData.(cellName).protocols, ...
            'UniformOutput', false);
        
        protLoc = find(strncmp(fliplr(protName),flippedProts,length(protName)));
        protOC = ephysData.(cellName).protOC;
        protWC = ephysData.(cellName).protWC;
        
        if protLoc
            for i = 1:length(protLoc)
                ivq{i} = ephysData.(cellName).data{1,protLoc(i)};
            end
            % Take all the iv steps gathered for the given cell
            ivSteps{iCell} = ivq;
            
            % Pull out the desired two OC and WC iv steps and save by cell name
            % to make it more user friendly when later separating/replotting
            % particular cells of interest. Turn cells into matrix, then split
            % matrix up so you can later take the mean of the three sets of
            % capacitance-corrected iv steps.
            % TODO: Set reshape size based on IV curve protocol size x3
            currSteps = ivSteps{iCell}(protOC:protOC+2);
            eval(sprintf('%s_OC = reshape(cell2mat(currSteps),[1050 12 3]);',cellName))
            currSteps = ivSteps{iCell}(protWC:protWC+2);
            eval(sprintf('%s_WC = reshape(cell2mat(currSteps),[1050 12 3]);',cellName))
            
            % Capacitance correction by subtracting the on-cell from the whole-cell
            eval(sprintf('%sCapCorr = %s_WC-%s_OC;',cellName,cellName,cellName))
        end
        
        eval(sprintf('capCorrCells.(cellName).mean = mean(%sCapCorr,3);', cellName))
        eval(sprintf('capCorrCells.(cellName).OC = %s_OC;', cellName))
        eval(sprintf('capCorrCells.(cellName).WC = %s_WC;', cellName))
        
    end
    
    % TODO: Output cell array of capCorrIV structs, one cell per group (to
    % be named by the caller outside the function)? Or varargout?
    % Or nested structs, so that I can output both the group mean and the
    % whole capCorrCells struct containing each cell's mean?
    % ( I do need the means per cell in order to do Rs V correction later)
    
    clear capCorrCells;
end



end
