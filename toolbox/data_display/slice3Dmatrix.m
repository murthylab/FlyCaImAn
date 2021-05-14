function slice3Dmatrix(Y, iparams)
% slice3Dmatrix: tool to display 3D matrices, 
%   Y could be a 3D matrix or a flatten arragement of a 3D matrix
%
% Usage:
%   slice3Dmatrix(Y, iparams)
%
% Args:
%   Y: 3D matrix or a flatten arragement of a 3D matrix
%   iparams: parameters to update
%       (figpos: figure position)
%           (default, genfigpos(1, 'center', [900 900]))
%       (sizY: Y original size)
%           (default, [])
%       (range: min & max image intensity)
%           (default, [])
%       (iter: gate to iteratively update range)
%           (default, 0)
%       (cmap: foreground image colormap)
%           (default, parula)
%       %%%%%%%%%%%% foreground contour %%%%%%%%%%%%
%       (Y1: foreground contour)
%           (default, [])
%       (Y1cmap: color of mask contour)
%           (default, [0 0 0])
%       (Y1text: text to add to contours)
%           (default, [])
%       %%%%%%%%%%%% overlay image (overlays Y over Y2) %%%%%%%%%%%%
%       (Y2: background image)
%           (default, [])
%       (Y2cmap: background image colormap)
%           (default, buildcmap('wk'))
%       (Y2range: intensity range, can be the same size as the 3r dim 
%           (use different range for different planes))
%           (default, [0 1])
%       (overcor: overlay image color)
%           (default, [1 0 0])
%       (xyzres: image resolution)
%           (default, [1.2, 1.2, 1])
%       %%%%%%%%%%%% foreground dots %%%%%%%%%%%%
%       (Y3: (y, x, z) positions)
%           (default, [])
%       (Y3cmap: color of points)
%           (default, [1 0 0])
%       (Y3text: text to add to points)
%           (default, [])
%       (Y3textcmap:, color of text, default 'cyan')
%           (default, 'cyan')
%       (Y3fontsiz: font size of text)
%           (default, 12)
%       %%%%%%%%%%%% saving params %%%%%%%%%%%%
%       (vgate: save flag)
%           (default, 0)
%       (vname: file name)
%           (default, 'test')
%       (vquality: video quality)
%           (default, 100)
%       (frate: frame rate)
%           (default, 10)
%       (save_frame_flag: save each frame separately)
%           (default, 0)
%       %%%%%%%%%%%% add text to corner %%%%%%%%%%%%
%       (vstrt: frame idx)
%           (default, [])
%       (vstr: text to add)
%           (default, [])
%       (vfontsiz: font size of text)
%           (default, 30)
%       %%%%%%%%%%%% extra %%%%%%%%%%%%
%       (nan: value to use to replace nan)
%           (default, 0)
%       (axp: axis to slide through)
%           (default, 3)
%       (lag: time lag for display)
%           (default, 0.001)
%       (cbargate: plot colorbar image)
%           (default, 1)
%       (axisratio: flag to use equal axis or not)
%           (default, 1)
%       (text_position: use the default (0), or com position)
%           (default, 0)
%
% Notes:
% 2019-02-26:
%   generalize code to handle more than one foreground (4th dimension in Y)
% 2019-06-14:
%   add other text position options (for contours)

% default params
pi.figpos = genfigpos(1, 'center', [900 900]);
pi.sizY = [];
pi.range = [];
pi.iter = 0;
pi.cmap = parula;
pi.Y1 = [];
pi.Y1cmap = [0 0 0];
pi.Y1text = [];
pi.Y2 = [];
pi.Y2cmap = buildcmap('wk');
pi.Y2range = [0 1];
pi.Y3 = [];
pi.Y3cmap = [1 0 0];
pi.Y3text = [];
pi.Y3textcmap = 'cyan';
pi.Y3fontsiz = 12;
pi.overcor = [1 0 0];
pi.xyzres = [1.2, 1.2, 1];
pi.vgate = 0;
pi.vname = 'test';
pi.vquality = 100;
pi.frate = 10;
pi.save_frame_flag = 0;
pi.vstrt = [];
pi.vstr = [];
pi.vfontsiz = 30;
pi.nan = 0;
pi.axp = 3;
pi.lag = 0.001;
pi.cbargate = 0;
pi.axisratio = 1;
pi.text_position = 0;

if ~exist('iparams', 'var'); iparams = []; end
pi = loparam_updater(pi, iparams);

if isempty(pi.sizY); pi.sizY = size(Y); end

% reshape Y if it is flat
pi.sizYi = size(Y);
pi.sizY1_orig = size(pi.Y1);
pi.sizY1_target = [pi.sizY prod(pi.sizY1_orig)/prod(pi.sizY)];

% flatten Y1
if pi.sizY1_orig(1) == pi.sizY1_target(1)
    pi.Y1 = reshape(pi.Y1, ...
        [prod(pi.sizY), prod(pi.sizY1_orig)/prod(pi.sizY)]);
end

Y = reshape(full(Y), [pi.sizY prod(pi.sizYi)/prod(pi.sizY)]);

if prod(pi.sizY1_orig)/prod(pi.sizY) > 1 ...
        && size(pi.Y1cmap, 1) == 1
    pi.Y1cmap = jet(prod(pi.sizY1_orig)/prod(pi.sizY));   
end

if isempty(pi.Y1text) || ...
        numel(pi.Y1text) ~= size(pi.Y1cmap, 1)
    pi.Y1text = cell(size(pi.Y1cmap, 1), 1);
end

if ~isempty(pi.Y2)
    sizM = size(pi.Y2);
    pi.Y2 = reshape(pi.Y2, ...
        [pi.sizY prod(sizM)/prod(pi.sizY)]); 
    pi.Y2 = double(pi.Y2);
    pi.Y2range = double(pi.Y2range);
end

Y(isnan(Y)) = pi.nan;

% generate figure
pi.figH = figure();
set(pi.figH, 'color', 'w', ...
    'Position', pi.figpos);

% plotting
plotmuliproj(Y, pi)

end

function plotmuliproj(Y, pi)
% plotmuliproj: plot each frame from Y
%
% Usage:
%   plotmuliproj(Y, pi)
%
% Args:
%   Y: 2DxT or 3D image
%   pi: parameters

pi.d2proj = [3 2 1]; 
pi.axesname = {'X', 'Y'};
if isempty(pi.range)
    pi.range = [min(Y(:)) prctile(Y(:), 75)];
end

pi.hAxes(1) = subplot(1, 1, 1);
%colormap(pi.figH, pi.cmap);
%colormap(pi.hAxes, pi.cmap);

% video related
vHandle = [];

if pi.vgate
    vHandle = VideoWriter(pi.vname);
    vHandle.Quality = pi.vquality;
    vHandle.FrameRate = pi.frate;
    open(vHandle);
end

fprintf(['Plotting ', num2str(size(Y, 4)), ...
    ' volume(s)\n'])

for t = 1:size(Y, pi.axp)
    
    % overlay Y onto Y2
    if ~isempty(pi.Y2)
         
        % plot background and foreground
        
        % Set background Image
        % set intensity range and convert it to gray scale (0-1)
        if size(pi.Y2range, 1) > 1
            bIm = mat2gray(pi.Y2(:, :, t), pi.Y2range(t, :));
        else
            bIm = mat2gray(pi.Y2(:, :, t), pi.Y2range);
        end
        bIm_size = size(bIm);

        % update spatial resolution
        pixres = pi.xyzres(setdiff(1:3, pi.axp));
        imobj_a = imref2d(bIm_size, pixres(2), pixres(1));
        imshow(bIm*size(pi.Y2cmap, 1), imobj_a, ...
            pi.Y2cmap, 'Parent', pi.hAxes);
        
        for ic = 1:size(Y, 4)
            
            % Set foreground image
            if pi.axp == 3
                ImTemp = squeeze(Y(:, :, t, ic));
            elseif pi.axp == 2
                ImTemp = squeeze(Y(:, t, :, ic));
            else
                ImTemp = squeeze(Y(t, :, :, ic));
            end
            
            ImTemp = double(ImTemp);
            % set intensity range and convert it to gray scale (0-1)
            ImTemp = mat2gray(ImTemp, pi.range);
            
            % generate colormap
            ImCorMap = cat(3, pi.overcor(ic, 1)*ones(bIm_size), ...
                pi.overcor(ic, 2)*ones(bIm_size), ...
                pi.overcor(ic, 3)*ones(bIm_size));
            hold(pi.hAxes, 'on');
            h = imshow(ImCorMap, imobj_a, 'Parent', pi.hAxes);
            hold(pi.hAxes, 'off');
            set(h, 'AlphaData', ImTemp)

            clear ImTemp

        end
                
        % figure details
        set(pi.hAxes, 'Box', 'off');
        set(pi.hAxes, 'xcolor', 'w', 'xtick', []);
        set(pi.hAxes, 'ycolor', 'w', 'ytick', [])
        
        if t == size(Y, pi.axp) && pi.cbargate
            pi = plotcolorbar(pi);
        end
        
    else
        
        % just plot background
        if pi.axp == 3
            temp_Y1 = squeeze(Y(:, :, t));
        elseif pi.axp == 2
            temp_Y1 = squeeze(Y(:, t, :));
        else
            temp_Y1 = squeeze(Y(t, :, :));
        end
        
        pixres = pi.xyzres(setdiff(1:3, pi.axp));
        imobj_a = imref2d(size(temp_Y1), pixres(2), pixres(1));
        
        plotproj(pi.hAxes(1), temp_Y1, num2str(t), pi.iter, ...
            pi.range, pi.axesname, imobj_a, pi.cmap, pi.axisratio);               
        
        if t == size(Y, pi.axp) && pi.cbargate
            pi = plotcolorbar(pi, temp_Y1);
        end
        
        clear temp_Y1
        
    end
        
    % plot overlay Y1 only on XY
    if ~isempty(pi.Y1)
        
        % if mask is same size uses each for each Y(:, :, t)
        if size(Y, 3) == pi.sizY1_target(3)         

            for ic = 1:pi.sizY1_target(4)
                
                % full volume per mask
                temp_Y1 = reshape(full(pi.Y1(:, ic)), [pi.sizY 1]);

                if pi.axp == 3
                    temp_Y1 = squeeze(temp_Y1(:, :, t));
                elseif pi.axp == 2
                    temp_Y1 = squeeze(temp_Y1(:, t, :));
                else
                    temp_Y1 = squeeze(temp_Y1(t, :, :));
                end
                
                pixres = pi.xyzres(setdiff(1:3, pi.axp));
                imobj_a = imref2d(size(temp_Y1), pixres(2), pixres(1));
                
                overlay_mask(pi.hAxes(1), temp_Y1, pi.Y1text(ic), ...
                    pi.Y1cmap(ic, :), imobj_a, pi.text_position);
                clear temp_Y1
                
            end
            
        % otherwise it uses the same for all (1)
        elseif pi.sizY1_target(3)
            
            temp_Y1 = reshape(full(pi.Y1(:, 1)), [pi.sizY 1]);

            pixres = pi.xyzres(setdiff(1:3, pi.axp));
            imobj_a = imref2d(size(temp_Y1), pixres(2), pixres(1));
            overlay_mask(pi.hAxes(1), temp_Y1, pi.Y1text(1), [], ...
                imobj_a, pi.text_position)
            
        end

    end
    
    % add points
    if ~isempty(pi.Y3)
        
        pts2use = find(pi.Y3(:, pi.axp) == t);
        temp_Y3 = pi.Y3(pts2use, setdiff(1:3, pi.axp));
        
        if pi.axp == 3
           hold(pi.hAxes, 'on')
           scatter(temp_Y3(:, 2)*pi.xyzres(2), ...
               temp_Y3(:, 1)*pi.xyzres(1), 5, ...
               'MarkerFaceColor', 'b', ...
               'MarkerEdgeColor', 'b', ...
               'Parent', pi.hAxes);
           
           if ~isempty(pi.Y3text)
               for i = 1:numel(pts2use)
                    text(temp_Y3(i, 2)*pi.xyzres(2), ...
                        temp_Y3(i, 1)*pi.xyzres(1), ...
                        pi.Y3text{pts2use(i)}, ...
                        'Color', pi.Y3textcmap, ...
                        'FontSize', pi.Y3fontsiz,...
                        'Parent', pi.hAxes)
               end
           end
           
        end
                
    end
    
    % add text to movie frames
    if ~isempty(pi.vstrt)
        if pi.vstrt(t) ~= 0
            text(0.05, 0.9, pi.vstr{pi.vstrt(t)}, ...
                'HorizontalAlignment', 'left', ...
                'Color', 'r', 'units', 'normalized', ...
                'FontSize', pi.vfontsiz, 'Parent', pi.hAxes);
        end    
    end
    
    % append frames to video
    if pi.vgate
        writeVideo(vHandle, getframe(pi.hAxes));
    end
    
    % save single frames
    if pi.save_frame_flag
        
        % default saving params
        figformat = [0 0 0 0 0 0 0 0 1];
        fitsize = 1;
        axcolor = 'none';
        figcolor = 'none';
        xyzcolor = 'none';
        tickgate = 'off';
        resolution_ = '-r300';
        
        [File_name, Folder_name] = split_path(pi.vname);
        
        save_edit_fig_int(pi.hAxes, pi.figH, ...
            Folder_name, [File_name, '_f_', num2str(t)], ...
            figformat, fitsize, axcolor, figcolor, ...
            xyzcolor, tickgate, resolution_);
        
    end
    
    hold(pi.hAxes, 'off'); 
    pause(pi.lag)
    
end

if pi.vgate
    
    % close video object
    close(vHandle); 
    
    % save colorbar
    if isfield(pi, 'figH_cb') && ~isempty(pi.figH_cb)
        print(pi.figH_cb, [pi.vname, '_cb.png'], ...
            '-dpng', '-opengl', '-r300');
        print(pi.figH_cb, [pi.vname, '_cb.svg'], ...
            '-dsvg', '-painters', '-r300');
        close(pi.figH_cb)
    end
    
    close(gcf);
    
end

end

function plotproj(axH, im, tidx, itergate, ...
    imrange, axesname, sparef, cmap, axisratio)
% overlay_mask: overlay contour of im > 0 over axH
% 
% Usage:
%   overlay_mask(axH, im, idx_c, cnt_text)
%
% Args:
%   axH: axes handle
%   im: 2D image
%   tidx: stack index
%   itergate: iteratively calculate max and min
%   imrange: image max and min range
%   axesname: axis name
%   sparef: image spatial object
%   cmap: colormap
%   axisratio: use equal axis or not

if ~exist('sparef', 'var') || isempty(sparef)
    sparef = [];
end

if itergate
    imrange = [min(im(:)) max(im(:))];
end

if ~isempty(imrange) && size(imrange, 1) > 1
	imrange = imrange(str2double(tidx), :);
end

if isempty(sparef) || ~axisratio
    imagesc(squeeze(im), 'Parent', axH);
    
    if tidx == 1
       colormap(axH, cmap)
    end
    
    caxis(axH, imrange)
    
else
    
    %imagesc(sparef.PixelExtentInWorldX:...
    %   sparef.PixelExtentInWorldX:sparef.ImageExtentInWorldX, ...
    %   sparef.PixelExtentInWorldY:sparef.PixelExtentInWorldY:...
    %   sparef.ImageExtentInWorldY, ...
    %   squeeze(im), 'Parent', axH);
    imshow(squeeze(im), sparef, ...
        'DisplayRange', imrange, ...
        'colormap', cmap, 'Parent', axH);
    
end

colorbar;
xlabel(axH, axesname{1, 1});
ylabel(axH, axesname{1, 2});

title(axH, tidx);
set(axH, 'YTick', []);
set(axH, 'XTick', [])

end

function overlay_mask(axH, im, cnt_text, ...
    cnt_cmap, sparef, text_position)
% overlay_mask: overlay contour of im > 0 over axH
% 
% Usage:
%   overlay_mask(axH, im, cnt_text, ...
%       cnt_cmap, sparef, text_position)
%
% Args:
%   axH: axes handle
%   im: X by Y image to use for contour
%   cnt_text: label of contour
%   cnt_cmap: contour colormap
%   sparef: image spatial object
%   text_position: devide in half the FOV and assign text to
%       the center of left ROI

if ~exist('cnt_text', 'var') || isempty(cnt_text)
    cnt_text = [];
end

if iscell(cnt_text)
    cnt_text = cnt_text{1};
end

if ~exist('sparef', 'var') || isempty(sparef)
    sparef = [];
end

if ~exist('text_position', 'var') || isempty(text_position)
   text_position = 0; 
end

hold(axH, 'on')

if max(im(:)) ~= 0
    
    % plot contours
    if isempty(sparef)
        
        [C] = contour(im > 0, 1, ...
            'color', cnt_cmap, ...
            'Linewidth', 2, 'Parent', axH);
        
    else
        
        [C] = contour(sparef.PixelExtentInWorldX:...
            sparef.PixelExtentInWorldX:sparef.ImageExtentInWorldX, ...
            sparef.PixelExtentInWorldY:sparef.PixelExtentInWorldY:...
            sparef.ImageExtentInWorldY, im > 0, 1, ...
            'color', cnt_cmap, 'Linewidth', 2, 'Parent', axH);
        
    end
    
    % add text to contours
    if ~isempty(cnt_text)
        
        if text_position == 0
            
            th = clabel(C, 'FontSize', 20, 'color', 'k');
            delete(th(1:end-1));

            if ischar(cnt_text)
                set(findobj(th, 'String', '0.5'), ...
                    'String', cnt_text)
            else
                set(findobj(th, 'String', '0.5'), ...
                    'String', num2str(cnt_text))
            end
            
        elseif text_position == 1
            
            % get half FOV on X axis:
            im = im > 0;
            siz = size(im);
            im(:, floor(siz(2)/2) + 1:end, :) = 0;
            siz = size(im);
            
            % get center
            center_ = com(double(im(:)), siz(1), siz(2));
            
            if ~isempty(sparef)
                center_ = center_.*...
                    [sparef.PixelExtentInWorldX, ...
                    sparef.PixelExtentInWorldY];
            end
            
            if ischar(cnt_text)
                text(center_(2), center_(1), ...
                    cnt_text, 'Color', 'k', ...
                    'FontSize', 10, 'Parent', axH)
            else
                text(center_(2), center_(1), ...
                    num2str(cnt_text), 'Color', ...
                    'k', 'FontSize', 10, 'Parent', axH)                
            end
            
        end
        
    end
    
end

end

function pi = plotcolorbar(pi, extra_Y)
% plotcolorbar: function to plot colorbar
%
% Usage:
%   pi = plotcolorbar(pi, extra_Y)
%
% Args:
%   pi: internal variable
%   extra_Y: aditional image

if ~isempty(pi.Y2)
    
    % provide figure with colorbar
    pi.figH_cb = figure();
    pi.AxH_cb(1) = subplot(1, 1, 1);
    
    fakeIm = ones(100, 100)*pi.range(2);
    dt = abs(diff(pi.range))/20;
    samplevals = pi.range(1):dt:pi.range(2);
    fakeIm(1:numel(samplevals)) = samplevals;
    
    imagesc(fakeIm, 'Parent', pi.AxH_cb(1))
    colormap(pi.AxH_cb(1), ...
        colorGradient([0 0 0], pi.overcor));
    
    pi.AxH_cb(2) = colorbar(pi.AxH_cb(1));
    pi.AxH_cb(2).TickLabels = ...
        [pi.range(1) mean(pi.range) pi.range(2)];
    pi.AxH_cb(2).Ticks = ...
        [0.001 + pi.range(1) mean(pi.range) pi.range(2) - 0.001];
    
    figEdit(pi.AxH_cb(1), pi.figH_cb)
    
end

if exist('extra_Y', 'var') && ~isempty(extra_Y)
    
    % provide figure with colorbar
    pi.figH_cb = figure();
    pi.AxH_cb(1) = subplot(1, 1, 1);
    
    imagesc(squeeze(extra_Y), 'Parent', pi.AxH_cb(1))
    caxis(pi.AxH_cb(1), pi.range);
    colormap(pi.AxH_cb(1), pi.cmap);
    
    pi.AxH_cb(2) = colorbar(pi.AxH_cb(1));
    
    figEdit(pi.AxH_cb(1), pi.figH_cb)
    
end

end
