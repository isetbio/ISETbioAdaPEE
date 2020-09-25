classdef neuralResponseEngine < handle
    %% Public properties
    properties

    end
    
    %% Private properties
    properties (SetAccess=private)
        % User-supplied function handle to the neural computation routine
        neuralComputeFunction
        % User-supplied struct with all neural computation params
        neuralParams
        
        % The optics -  generated by the user-supplied function
        theOptics = [];
        
        % The coneMosaic - generated and returned by the user-supplied function
        theConeMosaic = [];
        
        % Valid noise flags
        validNoiseFlags = {'none', 'random'};
    end
    
    % Public methods
    methods
        % Constructor
        function obj = neuralResponseEngine(neuralComputeFunctionHandle, neuralResponseParamsStruct)
            % Validate and set the scene compute function handle
            obj.validateAndSetComputeFunctionHandle(neuralComputeFunctionHandle);
            
            % Validate and set the scene params
            obj.validateAndSetParamsStruct(neuralResponseParamsStruct);
        end
        
        % Compute method
        function [theNeuralResponses, temporalSupportSeconds] = compute(obj, ...
                theSceneSequence, theSceneTemporalSupportSeconds, instancesNum, varargin)
            % Call the user-supplied compute function
            [theNeuralResponses, temporalSupportSeconds, obj.theOptics, obj.theConeMosaic] = obj.neuralComputeFunction(...
                obj, obj.neuralParams, theSceneSequence, theSceneTemporalSupportSeconds, instancesNum, varargin{:});
        end
        
        % Method to validate the passed noiseFlags
        validateNoiseFlags(obj,noiseFlags);
    end
    
    % Private methods
    methods (Access = private)
        % Method to validate and set the scene compute function handle
        validateAndSetComputeFunctionHandle(obj,sceneComputeFunctionHandle);
        % Method to validate and set the scene params struct
        validateAndSetParamsStruct(obj,sceneParamsStruct);
    end
    
end