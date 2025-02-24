% t_spatialCSF_EMExamples
%
% Eye movement examples using cMosaic, for t_spatialCSF

% Examples:
%{
    % Verify that cMosaic FEMs work without crashing. Same EM paths on
    % train and test.
    t_spatialCSF('useMetaContrast', false, ...
        'whichNoiseFreeNre', 'excitationsCmosaic', ...
        'whichNoisyInstanceNre', 'Poisson', ...
        'whichClassifierEngine', 'rcePoisson', ...
        'useConeContrast', false, ...
        'useFixationalEMs', true, ...
        'testEMsMatchTrain', true, ...
        'nTrainEMs', 4, ...
        'nTestEMs', 4, ...
        'nTrain', 1, ...
        'nTest', 64', ...
        'temporalFilterValues', [], ...
        'oiPadMethod', 'zero', ...
        'validationThresholds', [0.0258    0.0526    0.1576    0.4792], ...
        'visualizeEachScene', false, ...
        'visualizeEachResponse', false, ...
        'responseVisualizationFunction', @nreVisualizeCMosaic, ...
        'maxVisualizedNoisyResponseInstances', 2, ...
        'maxVisualizedNoisyResponseInstanceStimuli',2);

    % Verify that cMosaic FEMs work without crashing. Different EM paths on
    % train and test. 
    %
    % Can't use meta contrast for this case.
    %
    % DHB: THRESHOLD VALUES DO NOT MAKE SENSE TO ME FOR THIS CASE.  EDGE
    % EFFECTS?
    t_spatialCSF('useMetaContrast', false, ...
        'whichNoiseFreeNre', 'excitationsCmosaic', ...
        'whichNoisyInstanceNre', 'Poisson', ...
        'whichClassifierEngine', 'rcePoisson', ...
        'useConeContrast', false, ...
        'useFixationalEMs', true, ...
        'testEMsMatchTrain', false, ...
        'nTrainEMs', 4, ...
        'nTestEMs', 4, ...
        'nTrain', 1, ...
        'nTest', 64', ...
        'temporalFilterValues', [], ...
        'oiPadMethod', 'zero', ...
        'validationThresholds', [], ...
        'visualizeEachScene', false, ...
        'visualizeEachResponse', false, ...
        'responseVisualizationFunction', @nreVisualizeCMosaic, ...
        'maxVisualizedNoisyResponseInstances', 2, ...
        'maxVisualizedNoisyResponseInstanceStimuli',2);
%}