function visualizeSceneSequence(obj, sceneSequence, temporalSupportSeconds)
   
    scenesNum = numel(sceneSequence);
    maxColsNum = 8;
    if (scenesNum <= maxColsNum)
        rowsNum = 1;
        colsNum = scenesNum;
    else
        colsNum = maxColsNum;
        rowsNum = ceil(scenesNum/colsNum);
    end
    
    if (isempty(obj.presentationDisplay))
       % Generate generic display
       presentationDisplay = displayCreate('LCD-Apple');
    else
       % Use employed display
       presentationDisplay = obj.presentationDisplay;
    end
    % Compute the RGB settings for the display
    displayLinearRGBToXYZ = displayGet(presentationDisplay, 'rgb2xyz');
    displayXYZToLinearRGB = inv(displayLinearRGBToXYZ);
     
    hFig = figure(); clf;
    set(hFig, 'Position', [100 400 600 640], 'Color', [1 1 1]); 
    for frameIndex = 1:scenesNum
        subplot('Position', [0.01 0.02 0.98 0.95]);
        % Extract the XYZ image representation
        xyzImage = sceneGet(sceneSequence{frameIndex}, 'xyz');
        if (frameIndex == 1)
            xPixels = size(xyzImage,2);
            yPixels = size(xyzImage,1);
            x = 1:xPixels;
            y = 1:yPixels;
            x = x-mean(x);
            y = y-mean(y);
        end
        
        % Linear RGB image
        displayLinearRGBimage = imageLinearTransform(xyzImage, displayXYZToLinearRGB);
        % Settings RGB image
        displaySettingsImage = (ieLUTLinear(displayLinearRGBimage, displayGet(presentationDisplay, 'inverse gamma'))) / displayGet(presentationDisplay, 'nLevels');

        % Render image
        image(x,y,displaySettingsImage);
        % Cross hairs
        hold on;
        plot([0 0], max(abs(y))*[-1 1], 'k-');
        plot(max(abs(x))*[-1 1], [0 0],'k-');
        axis 'image';
        set(gca, 'FontSize', 16,  'XTick', [], 'YTick', []);
        title(sprintf('frame %d (%2.0f msec)', frameIndex,temporalSupportSeconds(frameIndex)*1000));
        drawnow;
    end
    
end