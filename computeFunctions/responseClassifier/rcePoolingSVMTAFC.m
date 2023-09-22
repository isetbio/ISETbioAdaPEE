function dataOut = rcePoolingSVMTAFC(responseClassifierOBJ, operationMode, classifierParamsStruct, nullResponses, testResponses)
% Compute function for training a binary 2AFC SVM classifier to predict response classes from response instances.
%
% Syntax:
%   dataOut = rcePoolingSVMClassifier(responseClassifierOBJ, operationMode, ...
%             classifierParamsStruct, nullResponses, testResponses)
%
% Description:
%    Compute function to be used as a computeFunctionHandle for a @responseClassifierEngine
%    object for training a binary, two-alternative forced choise classifier. The classifier
%    consists of a spatial pooling stage followed by a binary SVM classifier.
%
%    There are 2 ways to use this function.
%
%       [1] If called directly and with no arguments, 
%
%           dataOut = rcePoolingSVMClassifier()
%
%       it does not compute anything and simply returns a struct with the 
%       defaultParams that define the classifier
%
%       [2] If called from a parent @responseClassifierEngine object, 
%       it either trains a binary SVM classifier or it uses the already
%       trained classifier (stored in the parent @responseClassifierEngine object)
%       to predict response classes for a novel set of response instances. 
%
%    This function models a TAFC task, so that each trial is considered to
%    be either null/test across the two alternatives, or test/null.
%
% Inputs:
%    responseClassifierOBJ          - the parent @responseClassifierEngine object that
%                                     is calling this function as its computeFunctionHandle
%    operationMode                  - a string in {'train', 'predict'},defining whether we should 
%                                     train a classifier or use a trained classifier to predict classes
%    classifierParamsStruct         - a struct containing properties of the
%                                     employed response classifier.
%    nullResponses                  - an [mTrials x nDims x nTimePoints] matrix of responses to the null stimulus
%    testResponses                  - an [mTrials x nDims x nTimePoints] matrix of responses to the test stimulus
%
% Outputs:
%    dataOut  - A struct that depends on the input arguments. 
%
%               If called directly with no input arguments, the returned struct contains
%               the defaultParams that define the classifier to be used
%
%             - If called from a parent @responseClassifierEngine object, the returned
%               struct is organized as follows: 
%
%               In 'train' mode (the first two are required by the @responseClassifierEngine object,
%               the rest are specific to this function):
%                   .trainedClassifier       : the trained binary SCV classifer
%                   .preProcessingConstants  : constants computed during the dimensionality reduction preprocessing phase
%                   .features                : the features used for classification
%                   .pCorrect                : probability of correct classification for the in-sample trials (training data)
%                   .nominalClassLabels      : the classifier-assigned response classes
%                   .predictedClassLabels    : the classifier-predicted response classes
%                   .decisionBoundary        : if the feature set is 2D, the 2D decision boundary, otherwise []
%
%               In 'predict' mode (the first two are required by the @responseClassifierEngine object,
%               the rest are specific to this function):
%                   .pCorrect                : probability of correct classification for the out-of-sample trials (testing data)
%                   .trialPredictions        : vector of the trial-by-trial predictions 
%                                              (0 == incorrectly predicting nominal class, 1 == correctly predicting nominal class)
%                   .features                : the features used for classification
%                   .nominalClassLabels      : the classifier-assigned response classes
%                   .predictedClassLabels    : the classifier-predicted response classes
%   
% Optional key/value input arguments:
%    None.
%
% See Also:
%     t_responseClassifier

% History:
%    08/30/2021  NPC  Wrote it.
%
%   Examples:
%{
    % Usage case #1. Just return the default classifier params
    defaultParams =  rcePoolingSVMClassifier()

    % Usage case #2. Train a binary SVM classifier on a data set  using a parent 
    % @responseClassifierEngine object and the default classifier params

    % Instantiate the parent @neuralResponseEngine object
    theNeuralEngineOBJ = neuralResponseEngine(@nrePhotopigmentExcitationsConeMosaicHexWithNoEyeMovements);

    % Instantiate a @sceneEngine object and generate a test scene sequence
    theSceneEngineOBJ = sceneEngine(@sceUniformFieldTemporalModulation);
    testContrast = 0.7/100;
    [theTestSceneSequence, theTestSceneTemporalSupportSeconds] = ...
        theSceneEngineOBJ.compute(testContrast);
    % Generate the null scene sequence
    [theNullSceneSequence, theNullSceneTemporalSupportSeconds] = ...
        theSceneEngineOBJ.compute(0.0);

    % Compute a set of 128 training (in-sample) response instances to the test stimulus
    instancesNum = 128;
    noiseFlags = {'random'};
    [inSampleTestResponses, theResponseTemporalSupportSeconds] = theNeuralEngineOBJ.compute(...
            theTestSceneSequence, ...
            theTestSceneTemporalSupportSeconds, ...
            instancesNum, ...
            'noiseFlags', noiseFlags ...
            );
    % Compute a set of 128 training (in-sample) response instances to the null stimulus
    inSampleNullResponses = theNeuralEngineOBJ.compute(...
            theNullSceneSequence, ...
            theNullSceneTemporalSupportSeconds, ...
            instancesNum, ...
            'noiseFlags', noiseFlags ...
            );

    % Instantiate a responseClassifierEngine with the @rcePoolingSVMClassifier compute function
    theClassifierEngine = responseClassifierEngine(@rcePoolingSVMClassifier);
   
    % Train a binary SVM classifier on the in-sample data set
    trainingData = theClassifierEngine.compute('train',...
        inSampleNullResponses('random'), ...
        inSampleTestResponses('random'));

    % Generate 10 instances of (out-of-sample) responses to test the classifier performance
    instancesNum = 10;
    noiseFlags = {'random'};
    outOfSampleTestResponses = theNeuralEngineOBJ.compute(...
            theTestSceneSequence, ...
            theTestSceneTemporalSupportSeconds, ...
            instancesNum, ...
            'noiseFlags', noiseFlags ...
            );
    outOfSampleNullResponses = theNeuralEngineOBJ.compute(...
            theNullSceneSequence, ...
            theNullSceneTemporalSupportSeconds, ...
            instancesNum, ...
            'noiseFlags', noiseFlags ...
            );

    % Employ the trained classifier to compute its performance on the
    % out-of-sample data set.
    predictedData = theClassifierEngine.compute('predict',...
            outOfSampleNullResponses('random'), ...
            outOfSampleTestResponses('random'));
    
%}

    % Check input arguments. If called with zero input arguments, just return the default params struct
    if (nargin == 0)
        % Default params for this compute function
        dataOut = generateDefaultParams();
        return;
    end
    
    % Check operation mode
    if (~strcmp(operationMode,'train') && ~strcmp(operationMode,'predict'))
        error('Unknown operation mode passed.  Must be ''train'' or ''predict''');
    end
    

    if (strcmp(operationMode, 'train'))
        % Baseline activation: mean response to the null stimulus
        baselineActivation = classifierParamsStruct.pooling.noiseFreeNullResponse;
    else
        % Retrieve the baseline activation used during the training phase
        baselineActivation = responseClassifierOBJ.preProcessingConstants.baselineActivation;
    end
    
    % subtract the baseline activation from both the null and test response instances
    nullResponses = bsxfun(@minus, nullResponses, baselineActivation);
    testResponses = bsxfun(@minus, testResponses, baselineActivation);
        
    % Feature assembly phase: Sspatial pooling of responses
    [features, classLabels] = assembleFeatures(nullResponses, testResponses, ...
        classifierParamsStruct.pooling);

    % Classify
    if (strcmp(operationMode, 'train'))
        % Train an SVM classifier on the data
        [trainedSVM, predictedClassLabels, pCorrectInSample, decisionBoundary] = ...
            classifierTrain(classifierParamsStruct, features, classLabels);
    else
        % Employ the trained classifier to predict classes for the responses in this data set
        [predictedClassLabels, pCorrectOutOfSample] = ...
            classifierPredict(responseClassifierOBJ.trainedClassifier, features, classLabels);
    end
    
    % Assemble dataOut struct
    dataOut.features = features;
    dataOut.nominalClassLabels = classLabels;
    dataOut.predictedClassLabels = predictedClassLabels;
    
    if (strcmp(operationMode, 'train'))
        % Return the trained SVM and the preprocessing constants.
        % These fields are required by the calling object.
        dataOut.trainedClassifier = trainedSVM;
        
        % Save the baseline activation employed during the trainsing phase
        % so it can be re-employed during the 'test' phase 
        dataOut.preProcessingConstants = struct(...
            'baselineActivation', baselineActivation...
            );
        
        % These are optional and specific to this compute function.
        dataOut.pCorrect = pCorrectInSample;
        dataOut.trialPredictions = (predictedClassLabels == classLabels);
        dataOut.decisionBoundary = decisionBoundary;
     else
        % Return the out-of-sample pCorrect, and the trial-by-trial vector
        % of predictions (0 == correct, 1 == correct)
        dataOut.trialPredictions = (predictedClassLabels == classLabels);
        dataOut.pCorrect = pCorrectOutOfSample;
        fprintf('Out-of-sample pCorrect: %f\n', dataOut.pCorrect);
    end
end


function [predictedClassLabels, pCorrectOutOfSample] = classifierPredict(trainedSVM, features, actualClassLabels)
    N = size(features,1);
    predictedClassLabels = predict(trainedSVM, features);
    pCorrectOutOfSample = sum(predictedClassLabels(:)==actualClassLabels(:))/N;
end

function [compactSVMModel, predictedClassLabels, pCorrectInSample, decisionBoundary] = classifierTrain(classifierParamsStruct, features, classLabels)
 
     % Train the SVM classifier
     svmModel = fitcsvm(features, classLabels, ...
                'KernelFunction', classifierParamsStruct.kernelFunction);
            
     % Cross-validate the SVM yp obtain pCorrect for the in-Sample data
     crossValidatedSVM = crossval(svmModel,'KFold', classifierParamsStruct.crossValidationFoldsNum);
     
     % Compute pCorrect via cross-validation
     percentCorrect = 1 - kfoldLoss(crossValidatedSVM,'lossfun','classiferror','mode','individual');
     stdErr = std(percentCorrect)/sqrt(classifierParamsStruct.crossValidationFoldsNum);
     pCorrectInSample = mean(percentCorrect);
            
     % Extract the trained, compact classifier. The compact SVM saves space
     % by not including the train data.
     compactSVMModel = compact(svmModel);
     
     % Generated predicted class labels for the training data set
     predictedClassLabels = predict(compactSVMModel, features);
     
     % Compute the 2D decision boundary
     if (size(features,2) == 2)
         N = 200;
         x = linspace(min(features(:)), max(features(:)), N);
         y = linspace(min(features(:)), max(features(:)), N);
         [X,Y] = meshgrid(x, y);

         % Run the SVM to get assigned classes for all the xy grid points
         highResFeatureGrid = [X(:),Y(:)];
         [~, score] = predict(compactSVMModel,highResFeatureGrid);

         % Get our decision boundary (score)
         decisionBoundary.z = score(:,1);
         decisionBoundary.x = x;
         decisionBoundary.y = y;
     else
         decisionBoundary = [];
     end
     
end

% Method for spatial/spatiotemporal pooling of responses
function [features, classLabels] = assembleFeatures(nullResponses, testResponses, poolingParamsStruct)
 
    nTrials = size(nullResponses,1);
    timeBins = size(nullResponses,2);
    cellsNum = size(nullResponses,3);    

    % Check the spatiotemporal kernel size to see if we will do a
    % spatial pooling or a full spatiotemporal pooling
    poolingKernelTemporalDimensionality = size(poolingParamsStruct.weights.direct,2);
                
    switch poolingParamsStruct.type
        case 'linear'
            % Linear spatiotemporal pooling with passed weighting kernel
            
            % Allocate memory for the pooled responses
            nullPooledResponses = zeros(nTrials, timeBins);
            testPooledResponses = zeros(nTrials, timeBins);
    
            % Perform linear spatial or spatio-temporal pooling for each trial and for each time bin
            for t = 1:timeBins   
                % Process this time bin
                if (poolingKernelTemporalDimensionality == 1)
                    % A static kernel (1 time bin)
                    w1 = squeeze(poolingParamsStruct.weights.direct(1,1,:));
                else
                    % A spatiotemporal kernel
                    w1 = squeeze(poolingParamsStruct.weights.direct(1,t,:));
                end
                w1 = w1(:);
                
                % Do the pooling 
                parfor trialIndex = 1:nTrials
                    nR = squeeze(nullResponses(trialIndex,t,:));
                    tR = squeeze(testResponses(trialIndex,t,:));
                    nullPooledResponses(trialIndex,t) = dot(nR(:), w1);
                    testPooledResponses(trialIndex,t) = dot(tR(:), w1);
                end
            end
            
            responseSize = 1*timeBins;
            nullResponses = nullPooledResponses;
            testResponses = testPooledResponses;
            clear('nullPooledResponses', 'testPooledResponses');
            
        case 'quadratureEnergy'
            % Quandrate spatiotemporal pooling with passed pairs of
            % weighting kernels
            
            % Allocate memory
            nullPooledResponses1 = zeros(nTrials, timeBins);
            testPooledResponses1 = zeros(nTrials, timeBins);
            nullPooledResponses2 = zeros(nTrials, timeBins);
            testPooledResponses2 = zeros(nTrials, timeBins);
            
            % Perform quadrature spatial pooling for each trial and for each time bin
            for t = 1:timeBins
                % Process this time bin
                if (poolingKernelTemporalDimensionality == 1)
                    % A static kernel (1 time bin)
                    w1 = squeeze(poolingParamsStruct.weights.direct(1,1,:));
                    w2 = squeeze(poolingParamsStruct.weights.quadrature(1,1,:));
                else
                    % A spatiotemporal kernel
                    w1 = squeeze(poolingParamsStruct.weights.direct(1,t,:));
                    w2 = squeeze(poolingParamsStruct.weights.quadrature(1,t,:));
                end
                
                w1 = w1(:);
                w2 = w2(:);
                % Do the spatial pooling
                parfor trialIndex = 1:nTrials    
                    nR = squeeze(nullResponses(trialIndex,t,:));
                    tR = squeeze(testResponses(trialIndex,t,:));
                    nullPooledResponses1(trialIndex,t) = dot(nR(:), w1);
                    testPooledResponses1(trialIndex,t) = dot(tR(:), w1);
                    nullPooledResponses2(trialIndex,t) = dot(nR(:), w2);
                    testPooledResponses2(trialIndex,t) = dot(tR(:), w2);
                end
            end
            % Compute the energy response
            responseSize = 1*timeBins;
            nullResponses = sqrt(nullPooledResponses1.^2 + nullPooledResponses2.^2);
            testResponses = sqrt(testPooledResponses1.^2 + testPooledResponses2.^2);
            clear('nullPooledResponses1', 'nullPooledResponses2', 'testPooledResponses1', 'testPooledResponses2');
            
        case 'full field'
            % Linear spatial pooling with unity weighting kernel
            
            % Allocate memory for the pooled responses
            nullPooledResponses = zeros(nTrials, timeBins);
            testPooledResponses = zeros(nTrials, timeBins);
    
            % Perform linear spatial or spatio-temporal pooling for each trial and for each time bin
            for t = 1:timeBins   
                % Process this time bin
                % Do the pooling 
                parfor trialIndex = 1:nTrials
                    nR = squeeze(nullResponses(trialIndex,t,:));
                    tR = squeeze(testResponses(trialIndex,t,:));
                    nullPooledResponses(trialIndex,t) = sum(nR(:));
                    testPooledResponses(trialIndex,t) = sum(tR(:));
                end
            end
            
            responseSize = 1*timeBins;
            nullResponses = nullPooledResponses;
            testResponses = testPooledResponses;
            clear('nullPooledResponses', 'testPooledResponses');
            
            
        otherwise
            error('Unknown poolingParamsStruct.type: ''%s''.', poolingParamsStruct.type)
    end

    
    % Arange responses simulating a 2-interval task
    if (nTrials == 1)
        % If we are given only one trial data, arrange randomly in a 
        % class 0: NULL-TEST or in a class 1: % TEST-NULL
        if (rand(1,1) > 0.5)
            features(1,:) = [nullResponses testResponses];
            classLabels(1) = 0;
            fprintf('Arrangle single instance in NULL-TEST (class 0)')
        else
            features(1,:) = [testResponses nullResponses];
            classLabels(1) = 1;
            fprintf('Arrangle single instance in TEST-NULL (class 1)')
        end
        return;
    end
    
    % More than 1 trial data. Split the first half as NULL-TEST pairs and
    % the second half as TEST-NULL pairs
    halfTrials = floor(nTrials/2);
    features = zeros(2*halfTrials, 2*responseSize);
    classLabels = zeros(2*halfTrials, 1);

    % Class 0 data contain the null responses in the 1st interval
    % (NULL-TEST)
    features(1:halfTrials,:) = cat(2, ...
        nullResponses(1:halfTrials,:), ...
        testResponses(1:halfTrials,:));
    classLabels(1:halfTrials,1) = 0;

    % Class 1 data contain the null responses in the 2nd interval
    % (TEST-NULL)
    features(halfTrials+(1:halfTrials),:) = cat(2, ...
        testResponses(halfTrials+(1:halfTrials),:), ...
        nullResponses(halfTrials+(1:halfTrials),:));
    classLabels(halfTrials+(1:halfTrials),1) = 1;
end


function p = generateDefaultParams()
    p = struct(...
        'pooling', struct('type', 'full field'), ...
        'classifierType', 'svm', ...
        'kernelFunction', 'linear', ...
        'crossValidationFoldsNum', 10);
end
