function nreVisualizeMRGCmosaic(neuralPipeline, neuralResponses, temporalSupportSeconds, ...
    maxVisualizedInstances, visualizationMetaData, varargin)
% Custom visualization function for mRGCMosaic based neural responses 
%
% Syntax:
%    nreVisualizeMRGCmosaic(neuralPipeline, neuralResponses, temporalSupportSeconds, ...
%        maxVisualizedInstances, visualizationMetaData, varargin);
%
% Description:
%   Custom visualization function for MRGCMosaic neural response engines.
%
%   This function is called from the visualize() method of a
%   @neuralResponseEngine object whose:
%      - noiseFreeComputeFunctionHandle is set to @nreNoiseFreeMidgetRGCMosaic, 
%      - noisyInstancesComputeFunctionHandle is set to @nreNoisyInstancesGaussian, and 
%      - customVisualizationFunctionHandle is set to @nreVisualizeMRGCmosaic
%
% The visualize() method is called both from the noiseFree and the noisyInstances compute methods
%
% Inputs:
%    neuralPipeline                 - the parent @neuralResponseEngine object that
%                                     is calling this function as its computeFunctionHandle
%    neuralResponses                - a 3D matrix, [kTrials x mNeurons x tFrames], of neural responses
%    temporalSupportSeconds         - the temporal support for the stimulus frames, in seconds
%    maxVisualizedInstances         - the max number of mRGCMosaic response instances to visualize
%    visualizationMetaData          - either [] or a struct containing the noise-free responses of the input cone mosaic 
%    
% Optional key/value input arguments:
%    'figureHandle'                 - either [] or a figure handle
%    'axesHandle'                   - either [] or an axes handle
%    'responseLabel'                - string, just a comment about the responses visualized
%    'clearAxesBeforeDrawing'       - boolean, whether to clear the axes before drawing
%
% Outputs:
%   None
%
% Example usage:
%
% noiseFreeResponseParams = nreNoiseFreeMRGCMosaic([],[],[],[]);
% noisyInstancesParams = nreNoisyInstancesGaussian;
%
% theMRGCMosaicNeuralEngine = neuralResponseEngine( ...
%    @nreNoiseFreeMidgetRGCMosaic, ...
%    @nreNoisyInstancesGaussian, ...
%    noiseFreeResponseParams, ...
%    noisyInstancesParams);
%
% theMRGCMosaicNeuralEngine.visualizeEachCompute = true;
% theMRGCMosaicNeuralEngine.customVisualizationFunctionHandle = @nreVisualizeMRGCmosaic;
% theMRGCMosaicNeuralEngine.maxVisualizedNoisyResponseInstances = 2;
%
% For more usage examples, see t_spatialCSF
%

% History:
%    01/11/2025  NPC  Wrote it

    [figureHandle, axesHandle, clearAxesBeforeDrawing, responseLabel] = ...
        neuralResponseEngine.parseVisualizationOptions(varargin{:});

    if (isempty(figureHandle))
        figureHandle = figure(); clf;
        set(figureHandle, 'Position', [10 10 1700 500]);
    end
    if (isempty(axesHandle))
        axInputConeMosaicActivation = subplot('Position', [0.03 0.1 0.3 0.85]);
        axMRGCMosaicActivation = subplot('Position', [0.36 0.1 0.3 0.85]);
        axResponseTimeResponses = subplot('Position', [0.7 0.1 0.29 0.85]);
    else
        if (iscell(axesHandle)&&(numel(axesHandle) == 3))
            axInputConeMosaicActivation = axesHandle{1};
            axMRGCMosaicActivation = axesHandle{2};
            axResponseTimeResponses = axesHandle{3};
        else
            warning('nreVisualizeMRGCmosaic:expected a cell array with 3 axes handles but did not receive it', 'Will generate new axes.');
            axInputConeMosaicActivation = subplot('Position', [0.03 0.1 0.3 0.85]);
            axMRGCMosaicActivation = subplot('Position', [0.36 0.1 0.3 0.85]);
            axResponseTimeResponses = subplot('Position', [0.7 0.1 0.29 0.85]);
        end
    end

    % Retrieve the neural pipeline
    theMRGCmosaic = neuralPipeline.noiseFreeResponse.mRGCMosaic;

    % Retrieve the input cone mosaic response, if we have them
    theConeMosaicResponses = [];
    if (~isempty(visualizationMetaData)) && (isfield(visualizationMetaData, 'noiseFreeConeMosaicResponses'))
        theConeMosaicResponses = visualizationMetaData.noiseFreeConeMosaicResponses;
    end

    % Back to mRGCMosaic's native response format because we will be calling
    % cMosaic visualizer functions which expect it  
    if (size(neuralResponses,2) == theMRGCmosaic.rgcsNum)
        neuralResponses = permute(neuralResponses,[1 3 2]);
    end

    if (ndims(neuralResponses) == 2)
        if (size(neuralResponses,1) == numel(temporalSupportSeconds))
            neuralResponses = reshape(neuralResponses, [1 size(neuralResponses,1) size(neuralResponses,2)]);
        else
            neuralResponses = reshape(neuralResponses, [size(neuralResponses,1) 1 size(neuralResponses,2)]);
        end
    end

    [nTrials, nTimePoints, nRGCs] = size(neuralResponses);
    activationRangeMRGCMosaic = prctile(neuralResponses(:),[0 100]);
    activationRangeConeMosaic = prctile(theConeMosaicResponses(:),[0 100]);

    % Treat special case of zero activation range
    if (activationRangeMRGCMosaic(1) == activationRangeMRGCMosaic(2))
       activationRangeMRGCMosaic = activationRangeMRGCMosaic(1) + [-10*eps +10*eps]; 
    end

    % Treat special case of zero activation range
    if (activationRangeConeMosaic(1) == activationRangeConeMosaic(2))
       activationRangeConeMosaic = activationRangeConeMosaic(1) + [-10*eps +10*eps]; 
    end

    if (~isempty(theMRGCmosaic.inputConeMosaic.fixEMobj)) 
        emPathsDegs = theMRGCmosaic.inputConeMosaic.fixEMobj.emPosArcMin/60;
    else
        emPathsDegs = [];
    end

    if (numel(temporalSupportSeconds)>1)
        dt = temporalSupportSeconds(2)-temporalSupportSeconds(1);
        XLim = [temporalSupportSeconds(1)-dt/2 temporalSupportSeconds(end)+dt/2];
        XTick = temporalSupportSeconds(1):dt:temporalSupportSeconds(end);
    else
        dt = 0;
        XLim = [temporalSupportSeconds(1)-0.01 temporalSupportSeconds(1)+0.01];
        XTick = temporalSupportSeconds(1);
    end

    for iTrial =  1:min([nTrials maxVisualizedInstances])

        % The instantaneous spatial activation
        for iPoint = 1:nTimePoints

            theConeMosaicReponseTrial = min([iTrial size(theConeMosaicResponses,1)]);

            if (~isempty(theConeMosaicResponses))
                if (isempty(emPathsDegs))
                    theMRGCmosaic.inputConeMosaic.visualize(...
                        'figureHandle', figureHandle, ...
                        'axesHandle', axInputConeMosaicActivation, ...
                        'activation', theConeMosaicResponses(theConeMosaicReponseTrial, iPoint,:), ...
                        'activationRange', activationRangeConeMosaic , ...
                        'horizontalActivationColorbarInside', true, ...
                        'clearAxesBeforeDrawing', clearAxesBeforeDrawing, ...
                        'plotTitle', sprintf('cMosaic %s (t: %2.1f msec)', responseLabel, temporalSupportSeconds(iPoint)*1e3));
                else
                    theEMtrial = min([iTrial size(emPathsDegs,1)]);
    
                    theMRGCmosaic.inputConeMosaic.visualize(...
                        'figureHandle', figureHandle, ...
                        'axesHandle', axInputConeMosaicActivation, ...
                        'activation', theConeMosaicResponses(theConeMosaicReponseTrial, iPoint,:), ...
                        'activationRange', activationRangeConeMosaic , ...
                        'horizontalActivationColorbarInside', true, ...
                        'currentEMposition', squeeze(emPathsDegs(theEMtrial,iPoint,:)), ...
                        'displayedEyeMovementData', struct('trial', theEMtrial, 'timePoints', 1:iPoint), ...
                        'clearAxesBeforeDrawing', clearAxesBeforeDrawing, ...
                        'plotTitle', sprintf('cMosaic %s (t: %2.1f msec, trial %d of %d)', responseLabel, temporalSupportSeconds(iPoint)*1e3, iTrial, nTrials));
         
                end
            end
            
            % Retrieve spatiotemporal response up to this time point
            xtActivation = spatioTemporalResponseComponents(theMRGCmosaic, neuralResponses, temporalSupportSeconds, iTrial, iPoint);

            % Plot the spatiotemporal response up to this time point
            imagesc(axResponseTimeResponses, temporalSupportSeconds, 1:theMRGCmosaic.rgcsNum, xtActivation);
            hold(axResponseTimeResponses, 'on');

            % The stimulus frames
            for i = 1:numel(temporalSupportSeconds)
                plot(axResponseTimeResponses, (temporalSupportSeconds(i)-dt/2)*[1 1], [1 theMRGCmosaic.rgcsNum], 'k-', 'LineWidth', 1.0);
            end
            hold(axResponseTimeResponses, 'off');

            linearRamp = linspace(0,1,1024);
            linearRamp = linearRamp(:);
            cMap = [linearRamp*0 linearRamp linearRamp*0];

            colormap(axResponseTimeResponses, cMap);

            axis(axResponseTimeResponses, 'xy');
            xlabel(axResponseTimeResponses, 'time (sec)');
            ylabel(axResponseTimeResponses, 'mRGC index');
    
            set(axResponseTimeResponses, ...
                    'XLim', XLim, ...
                    'XTick', XTick, ...
                    'YLim', [1 theMRGCmosaic.rgcsNum], ...
                    'CLim', activationRangeMRGCMosaic, ...
                    'Color', [0 0 0], ...
                    'FontSize', 16);
            colorbar(axResponseTimeResponses, 'NorthOutside');
            title(axResponseTimeResponses, sprintf('spatio-temporal %s (trial %d of %d)', responseLabel, iTrial, nTrials));
           
            theMRGCmosaic.visualize(...
                'figureHandle', figureHandle, ...
                'axesHandle', axMRGCMosaicActivation, ...
                'activation', neuralResponses(iTrial, iPoint,:), ...
                'activationRange', activationRangeMRGCMosaic, ...
                'horizontalActivationColorbarInside', true, ...
                'plotTitle', sprintf('mRGCMosaic %s (t: %2.1f msec)', responseLabel, temporalSupportSeconds(iPoint)*1e3));
            
            drawnow;
        end % iPoint
    end % iTrial

end

function xtActivation = spatioTemporalResponseComponents(theMRGCmosaic, neuralResponses, temporalSupportSeconds, iTrial, iPoint)
          
    [nTrials, nTimePoints, mRGCs] = size(neuralResponses);
    
    mosaicSpatioTemporalActivation = squeeze(neuralResponses(iTrial,:,:));
    if (size(mosaicSpatioTemporalActivation,1) == mRGCs)
        mosaicSpatioTemporalActivation = mosaicSpatioTemporalActivation';
    end

    if (size(mosaicSpatioTemporalActivation,1) == numel(temporalSupportSeconds)) && ...
       (size(mosaicSpatioTemporalActivation,2) == theMRGCmosaic.rgcsNum)
            xtActivation = 0 * mosaicSpatioTemporalActivation;
            xtActivation(1:iPoint,:) = mosaicSpatioTemporalActivation(1:iPoint,:);
            xtActivation = xtActivation';
    else
        error('size inconsistency')
    end 
 
end
