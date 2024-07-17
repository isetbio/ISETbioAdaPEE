function [sce0,sce90,sce180,sce270,sceBg] = t_AOtumblingESceneEngine(varargin)

% Initialize
close all;

% Parse optional input
p = inputParser;
p.addParameter('visualizeScene', true, @islogical);
p.parse(varargin{:});
visualizeScene = p.Results.visualizeScene;

% Make sure figures directory exists so that output writes
% don't fail
rootPath = ISETBioCSFGeneratorRootPath;
if (~exist(fullfile(rootPath,'local','figures'),'dir'))
    mkdir(fullfile(rootPath,'local','figures'));
end

% Load in a monitor that mimics the primaries in the Berkely AO system.
theDisplay = load(fullfile(rootPath,'sampledata','monoDisplay.mat'));
presentationDisplay = theDisplay.monoDisplay;

% Will's description of the stimulus parameters for this experiment.
%   - Wavelength: the tumbling-E was modulated in the imaging channel. The
%   center wavelength is 840 nm. We don't have a spectroradiometer that
%   operates in this part of the spectrum, so we haven't measured the
%   spectral bandwidth directly, but the filter used to select light in
%   this channel is this one:
%   https://www.idex-hs.com/store/product-detail/ff01_840_12_25/fl-004460 -
%   Display size: 512 by 512 pixels, 1.413 by 1.413 degrees, 362.3
%   pixels/degree.
%
%   - The E was presented as a decrement against the 840 nm imaging
%   channel. The contrast is nominally 100%, but this in practice this will
%   be slightly less due to (a) imperfect extinction by the AOM and (b)
%   background 940 nm light that is used for wavefront sensing and is not
%   modulated.
%
%   - The average 840 nm power measured at the cornea was 141.4 microwatts.
%   This would be distributed more or less uniformly over the 1.413 degree
%   square field described above. Assuming a 16.67 mm eye length, I'm
%   getting 8.37E-04 W/mm2, but you might want to check my math on that.
%
%   - Temporal characteristics of the AOSLO: 30 fps, 50 ns per pixel. This
%   means each pixel in the raster is illuminated very briefly every ~33
%   ms. Depending on the size of the cone, the effective pulse of light it
%   receives every frame will be slightly longer since the AOSLO pixels are
%   smaller than the cones themselves. At this AOSLO field size, a cone
%   with a 1 arcmin diameter will receive stimulus light over the course of
%   ~0.40 ms per frame. The timing of stimulation might be relevant for
%   this modeling, so happy to discuss the details further.
%
% Other potentially relevant details:
%   - Test eccentricity: 1 degree (usually temporal)
%   - Stimulus duration: 3 AOSLO frames
%   - Stimulus size: 20/40 tumbling-E optotype (width of E bar = 2 arcmin; overall E size is 10 arcmin)
%   - Imposed stimulus motion on the retina
%   - Magnitude: we shifted the letter on each frame by increments of the
%   bar width -- either 0, 0.5, 1.0, or 2.0. "0" imposed motion in this
%   case means it was retinally stabilized
%   direction: shifts were imposed in retinal coordinates along the four
%   cardinal meridians Performance was assessed as % correct for a fixed
%   letter size

% Here are some other parameters that we need to think about in the code.
%   wls = 820:10:860;
%   eWavelengthNm = 840;
%
% Spatial parameters
%   nPixels = 512;
%   fieldSizeMinutes = 1.43*60;
%   fieldSizeDegs = fieldSizeMinutes/60;
%
% Background power in uW.
%   fieldPowerUW = 141.4;
%   fieldPowerUWPerDeg2 = fieldPowerUW/(fieldSizeDegs^2);

% E power in uW.  This is the power for the stimulus that
% % is added to the background.  Let's assume for now that
% % it is twice the background power.
%   ePowerUW = 0;

% Set the parameters for the AO mimicing display
sceneParams = sceTumblingEscene;
sceneParams.presentationDisplay = presentationDisplay;
sceneParams.plotDisplayCharacteristics = false;

% Define the foreground (E) and background RGB wrt the monochromatic
% monitor.  I think the Berkeley experiments use only the green
% channel, so we'll do that here.
sceneParams.chromaSpecification.backgroundRGB = [0 0 0];
sceneParams.chromaSpecification.foregroundRGB = [0 0.5 0];

% Instantiate a tumblingEsceneEngine for 0 deg rotation E
sceneParams.letterRotationDegs = 0;
tumblingEsceneEngine0degs = sceneEngine(@sceTumblingEscene,sceneParams);

% Generate sceneEngine for 90 deg rotation E
sceneParams.letterRotationDegs = 90;
tumblingEsceneEngine90degs = sceneEngine(@sceTumblingEscene,sceneParams);

% Generate sceneEngine for 180 deg rotation E
sceneParams.letterRotationDegs = 180;
tumblingEsceneEngine180degs = sceneEngine(@sceTumblingEscene,sceneParams);

% Generate sceneEngine for 270 deg rotation E
sceneParams.letterRotationDegs = 270;
tumblingEsceneEngine270degs = sceneEngine(@sceTumblingEscene,sceneParams);

% Generate params for the background scene
backgroundSceneParams = sceneParams;
backgroundSceneParams.chromaSpecification.foregroundRGB = sceneParams.chromaSpecification.backgroundRGB;
backgroundSceneEngine = sceneEngine(@sceTumblingEscene,backgroundSceneParams);

% Generate scenes with size of 0.1 deg
sizeDegs = 0.1;
theSmallEsceneSequence0degs = tumblingEsceneEngine0degs.compute(sizeDegs);
theSmallEsceneSequence90degs = tumblingEsceneEngine90degs.compute(sizeDegs);
theSmallEsceneSequence180degs = tumblingEsceneEngine180degs.compute(sizeDegs);
theSmallEsceneSequence270degs = tumblingEsceneEngine270degs.compute(sizeDegs);
theSmallBackgroundSceneSequence = backgroundSceneEngine.compute(sizeDegs);

% Get first frame of the scene sequences
theSmallEscene0degs = theSmallEsceneSequence0degs{1};
theSmallEscene90degs = theSmallEsceneSequence90degs{1};
theSmallEscene180degs = theSmallEsceneSequence180degs{1};
theSmallEscene270degs = theSmallEsceneSequence270degs{1};
theSmallBackgroundScene = theSmallBackgroundSceneSequence{1};

if (visualizeScene)
    subplotPosVectors = NicePlot.getSubPlotPosVectors(...
        'rowsNum', 1, ...
        'colsNum', 4, ...
        'heightMargin',  0.0, ...
        'widthMargin',    0.05, ...
        'leftMargin',     0.05, ...
        'rightMargin',    0.00, ...
        'bottomMargin',   0.05, ...
        'topMargin',      0.00);

    domainVisualizationLimits = 0.3*0.5*[-1 1 -1 1];

    hFig = figure(1);
    clf;
    set(hFig, 'Position', [10 10 1550 400], 'Color', [1 1 1]);
    ax = subplot('Position', subplotPosVectors(1,1).v);
    visualizeScene(theSmallEscene0degs, ...
        'spatialSupportInDegs', true, ...
        'crossHairsAtOrigin', true, ...
        'displayRadianceMaps', false, ...
        'avoidAutomaticRGBscaling', true, ...
        'noTitle', true, ...
        'axesHandle', ax);
    set(ax, 'XLim', [domainVisualizationLimits(1) domainVisualizationLimits(2)], ...
        'YLim', [domainVisualizationLimits(3) domainVisualizationLimits(4)], ...
        'XTick', [-0.1 0 0.1], 'YTick', [-0.1 0 0.1] ...
        );

    ax = subplot('Position', subplotPosVectors(1,2).v);
    visualizeScene(theSmallEscene90degs, ...
        'spatialSupportInDegs', true, ...
        'crossHairsAtOrigin', true, ...
        'displayRadianceMaps', false, ...
        'avoidAutomaticRGBscaling', true, ...
        'noYLabel', true, ...
        'noYTicks', true, ...
        'noTitle', true, ...
        'axesHandle', ax);
    set(ax, 'XLim', [domainVisualizationLimits(1) domainVisualizationLimits(2)], ...
        'YLim', [domainVisualizationLimits(3) domainVisualizationLimits(4)], ...
        'XTick', [-0.1 0 0.1], 'YTick', [-0.1 0 0.1] ...
        );

    ax = subplot('Position', subplotPosVectors(1,3).v);
    visualizeScene(theSmallEscene180degs, ...
        'spatialSupportInDegs', true, ...
        'crossHairsAtOrigin', true, ...
        'displayRadianceMaps', false, ...
        'avoidAutomaticRGBscaling', true, ...
        'noYLabel', true, ...
        'noYTicks', true, ...
        'noTitle', true, ...
        'axesHandle', ax);
    set(ax, 'XLim', [domainVisualizationLimits(1) domainVisualizationLimits(2)], ...
        'YLim', [domainVisualizationLimits(3) domainVisualizationLimits(4)], ...
        'XTick', [-0.1 0 0.1], 'YTick', [-0.1 0 0.1] ...
        );

    ax = subplot('Position', subplotPosVectors(1,4).v);
    visualizeScene(theSmallEscene270degs, ...
        'spatialSupportInDegs', true, ...
        'crossHairsAtOrigin', true, ...
        'displayRadianceMaps', false, ...
        'avoidAutomaticRGBscaling', true, ...
        'noYLabel', true, ...
        'noYTicks', true, ...
        'noTitle', true, ...
        'axesHandle', ax);
    set(ax, 'XLim', [domainVisualizationLimits(1) domainVisualizationLimits(2)], ...
        'YLim', [domainVisualizationLimits(3) domainVisualizationLimits(4)], ...
        'XTick', [-0.1 0 0.1], 'YTick', [-0.1 0 0.1] ...
        );

    projectBaseDir = ISETBioCSFGeneratorRootPath;
    pdfFile = fullfile(projectBaseDir,'figures','t_AOTumblingSceneEngine_stimuli.pdf');
    NicePlot.exportFigToPDF(pdfFile,hFig, 300);
end

% Set output if any requested
if (nargout > 0)
    sce0 = tumblingEsceneEngine0degs;
    sce90 = tumblingEsceneEngine90degs;
    sce180 = tumblingEsceneEngine180degs;
    sce270 = tumblingEsceneEngine270degs;
    sceBg = backgroundSceneEngine;
end

end

