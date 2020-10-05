function dataOut = pcaSVMClassifier(responseClassifierOBJ, operationMode, classifierParamsStruct, nullResponses, testResponses)
% Compute function for training a binary SVM classifier to predict classes from
% responses.
%
% Syntax:
%   dataOut = pcaSVMClassifier(responseClassifierOBJ, operationMode, ...
%             classifierParamsStruct, nullResponses, testResponses)
%
% Description:
%    Compute function to be used as a computeFunctionHandle for a @responseClassifierEngine
%    object. There are 2 ways to use this function.
%
%       [1] If called directly and with no arguments, 
%
%           dataOut = pcaSVMClassifier()
%
%       it does not compute anything and simply returns a struct with the 
%       defaultParams that define the classifier
%
%       [2] If called from a parent @responseClassifierEngine object, 
%       it either trains a binary SVM classifier or it uses the already
%       trained classifier (stored in the parent @responseClassifierEngine object)
%       to predict the classes of a novel set of responses. 
%
% Inputs:
%    responseClassifierOBJ          - the parent @responseClassifierEngine object that
%                                     is calling this function as its computeFunctionHandle
%
%    operationMode                  - a string in {'train', 'predict'},defining whether we should 
%                                     train a classifier or use a trained classifier to predict classes
%
%    classifierParamsStruct         - a struct containing properties of the
%                                     employed response classifier.
%
%    nullResponses                  - an [mTrials x nDims] matrix of responses to the null stimulus
%
%    testResponses                  - an [mTrials x nDims] matrix of responses to the test stimulus
%
%
% Optional key/value input arguments: none
%
% Outputs:
%    dataOut  - A struct that depends on the input arguments. 
%
%               If called directly with no input arguments, the returned struct contains
%               the defaultParams that define the classifier to be used
%
%             - If called from a parent @responseClassifierEngine object, the returned
%               struct is organized as follows: 
%               In 'train' mode:
%
%                   .features                : the features used for classification
%                   .trainedClassifier       : the trained binary SCV classifer
%                   .preProcessingConstants  : constants computed during the dimensionality reduction preprocessing phase
%                   .pCorrectInSample        : probability of correct classification for the in-sample (training data)
%                   .decisionBounday         : if the feature set is 2D, the 2D decision boundary, otherwise []
%
%               In 'predict' mode:
%
%                   .features                : the features used for classification
%                   .pCorrectOutOfSample     : probability of correct classification for the out-of-sample (testing data)
%                   .predictedClassLabels    : the predicted labels for the out-of-sample responses
%
%
% See Also:
%     t_responseClassifier

% History:
%    09/26/2020  NPC  Wrote it.
%
%   Examples:
%{
    % Usage case #1. Just return the default classifier params
    defaultParams =  pcaSVMClassifier()

    % Usage case #2. Train a binary SVM classifier on a data set  using a parent 
    % @responseClassifierEngine object and the default classifier params

    % Instantiate the parent @neuralResponseEngine object
    theNeuralEngineOBJ = neuralResponseEngine(@nrePhotopigmentExcitationsWithNoEyeMovements);

    % Instantiate a @sceneEngine object and generate a test scene sequence
    theSceneEngineOBJ = sceneEngine(@uniformFieldTemporalModulation);
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

    % Instantiate a responseClassifierEngine with the @pcaSVMClassifier compute function
    theClassifierEngine = responseClassifierEngine(@pcaSVMClassifier);
   
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
    
    % Feature assembly phase
    [features, classLabels] = computeFeatures(classifierParamsStruct, nullResponses, testResponses);

    % Feature preprocessing analysis
    if (strcmp(operationMode, 'train'))
        % Compute pre-processing constants: centering factor & principal components
        m = mean(features,1);
        % Center the in-sample eatures
        features = bsxfun(@minus, features, m);
        % Determine PCs without centering (we're doing the centering so we can do it the same way for the out-of-sample data during the prediction phase)
        principalComponents = pca(features,'Centered', false,'NumComponents', classifierParamsStruct.PCAComponentsNum);
    else
        % Retrieve the in-sample pre-processing constants
        m = responseClassifierOBJ.preProcessingConstants.centering;
        principalComponents = responseClassifierOBJ.preProcessingConstants.principalComponents; 
        % Center the out-of-sample features
        features = bsxfun(@minus, features, m);
    end

    % Feature dimensionality reduction via projection to the space defined by the first classifierParamsStruct.PCAComponentsNum
    features = features * principalComponents;
        
    % Classify
    if (strcmp(operationMode, 'train'))
        % Train an SVM classifier on the data
        [trainedSVM, pCorrectInSample, decisionBoundary] = classifierTrain(classifierParamsStruct, features, classLabels);
    else
        % Employ the trained classifier to predict classes for the responses in this data set
        [predictedClassLabels, pCorrectOutOfSample] = classifierPredict(responseClassifierOBJ.trainedClassifier, features, classLabels);
    end
    
    % Assemble dataOut struct
    dataOut.features = features;
    if (strcmp(operationMode, 'train'))
        % Return the trained SVM, the preprocessing constants, the
        % in-sample pCorrect and the decision boundary
        dataOut.trainedClassifier = trainedSVM;
        dataOut.preProcessingConstants = struct(...
            'centering', m, ...
        	'principalComponents', principalComponents);
        dataOut.pCorrectInSample = pCorrectInSample;
        dataOut.decisionBoundary = decisionBoundary;
     else
         % Return the out-of-sample pCorrect and the predicted classes
        dataOut.pCorrectOutOfSample = pCorrectOutOfSample;
        dataOut.predictedClassLabels = predictedClassLabels;
     end
     
end


function [predictedClassLabels, pCorrectOutOfSample] = classifierPredict(trainedSVM, features, actualClassLabels)
    N = size(features,1);
    predictedClassLabels = predict(trainedSVM, features);
    pCorrectOutOfSample = sum(predictedClassLabels(:)==actualClassLabels(:))/N;
end

function [compactSVMModel, pCorrectInSample, decisionBoundary] = classifierTrain(classifierParamsStruct, features, classLabels)
 
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

function [features, classLabels] = computeFeatures(classifierParamsStruct, nullResponses, testResponses)
    
    % Reshape data to [nTrials x mResponse dimensions]
    nTrials = size(nullResponses,1);
    cellsNum = size(nullResponses,2);
    timeBins = size(nullResponses,3);
    responseSize = cellsNum*timeBins;
    
    nullResponses = reshape(nullResponses, [nTrials responseSize]);
    testResponses = reshape(testResponses, [nTrials responseSize]);
    
    % Arange responses according to whether we are simulating a 1- or a 2-interval task
    if (classifierParamsStruct.taskIntervals == 1)
        features = zeros(2*nTrials, responseSize);
        classLabels = zeros(2*nTrials, 1);
        
        % Class 0 data are the null response data
        features(1:nTrials,:) = nullResponses;
        classLabels(1:nTrials,1) = 0;
        
        % Class 0 data are the test response data
        features(nTrials+(1:nTrials),:) = testResponses;
        classLabels(nTrials+(1:nTrials),1) = 1;
    else
        halfTrials = floor(nTrials/2);
        if (halfTrials<1)
            error('For a 2-interval classifier, we need at least 2 trials');
        end
        features = zeros(2*halfTrials, 2*responseSize);
        classLabels = zeros(2*halfTrials, 1);
        
        % Class 0 data contain the null responses in the 1st interval
        features(1:halfTrials,:) = cat(2, ...
            nullResponses(1:halfTrials,:), ...
            testResponses(1:halfTrials,:));
        classLabels(1:halfTrials,1) = 0;
        
        % Class 1 data contain the null responses in the 2nd interval
        features(halfTrials+(1:halfTrials),:) = cat(2, ...
            testResponses(halfTrials+(1:halfTrials),:), ...
            nullResponses(halfTrials+(1:halfTrials),:));
        classLabels(halfTrials+(1:halfTrials),1) = 1;
    end
end


function p = generateDefaultParams()
    p = struct(...
        'PCAComponentsNum', 2, ...
        'taskIntervals', 1, ...
        'classifierType', 'svm', ...
        'kernelFunction', 'linear', ...
        'crossValidationFoldsNum', 10);
end
