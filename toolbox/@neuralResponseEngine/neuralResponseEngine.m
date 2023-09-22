classdef neuralResponseEngine < handle
% Define a neuralResponseEngine class
%
% Syntax:
%   theNeuralResponseEngine =
%      neuralResponseEngine(neuralComputeFunctionHandle, neuralResponseParamsStruct)
%
% Description:
%    The neuralResponseEngine stores the optics and coneMosaic returned by
%    its computeFunction (whenever they are returned), so that they can be
%    reused in subsequent calls of its computeFunction.
%
%
% Inputs:
%    neuralComputeFunctionHandle     - Function handle to the computeFunction that defines the
%                                       operation of the employed neural response pipeline
%
%    neuralResponseParamsStruct      - Struct with parameters specific to the computeFunction. 
%                                      Optional. If not defined, the default params
%                                      defined in the computeFunction are used
% Outputs:
%    The created neuralResponseEngine object.
%
% Optional key/value pairs: None
%
%
% See Also:
%    t_neuralResponseCompute.m, nrePhotopigmentExcitationsConeMosaicHexWithNoEyeMovements.m
%

% History:
%    9/20/2020  NPC Wrote it

    %% Public properties
    properties

    end
    
    %% Private properties
    properties (SetAccess=private)
        % User-supplied compute function handle to the neural computation routine
        neuralComputeFunction
        
        % User-supplied struct with all neural computation params
        neuralParams
        
        % The neural pipeline struct  - generated by the user-supplied compute function
        neuralPipeline
        
        % Valid noise flags
        validNoiseFlags = {'none', 'random'};
    end
    
    % Public methods
    methods
        % Constructor
        function obj = neuralResponseEngine(neuralComputeFunctionHandle, neuralResponseParamsStruct)
            % Validate and set the scene compute function handle
            obj.validateAndSetComputeFunctionHandle(neuralComputeFunctionHandle);
            
            % If we dont receice a paramsStruct as the second argument use
            % the default params returned by the neuralComputeFunctionHandle
            if (nargin == 1)
                neuralResponseParamsStruct = obj.neuralComputeFunction();
            end
             
            % Validate and set the scene params struct
            obj.validateAndSetParamsStruct(neuralResponseParamsStruct);
        end
        
        % Method to set a custom neural pipeline
        function customNeuralPipeline(obj, thePipeline)
            obj.neuralPipeline = thePipeline;
        end
        
        % Compute method
        [neuralResponses, temporalSupportSeconds] = compute(obj, ...
                theSceneSequence, theSceneTemporalSupportSeconds, instancesNum, varargin);
        
        function updateParamsStruct(obj, paramsStruct)
            % Set the neural params
            obj.neuralParams = paramsStruct;
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