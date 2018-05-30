%%Project runner for mp5

%% Part1 Overlap/s0270/s0450
addpath vlfeat-0.9.19/
addpath vlfeat-0.9.19/toolbox/
vl_setup;

refFrame = imread('./frames/f0450.jpg');
sampleFrame = imread('./frames/f0270.jpg');
mask = ones(size(refFrame));

H = auto_homography(sampleFrame, refFrame);

x = 250;
y = 50;
offset = 200;

points = [x, x, x+offset, x+offset, x;
          y, y+offset, y+offset, y, y;
          1,1,1,1,1];
      
pointsPot = H * points;

pointsPot = bsxfun(@rdivide, pointsPot, pointsPot(3, :));

TI = maketform('projective', eye(3));
TH = maketform('projective', H');

imTransform = imtransform(refFrame, TI, 'XData',[-651 980],'YData',[-51 460]);
mask = (imtransform(mask, TI, 'XData',[-651 980],'YData',[-51 460]) == 0);

imTransform2 = imtransform(sampleFrame, TH, 'XData',[-651 980],'YData',[-51 460]);
mask_2 = (imtransform(mask, TH, 'XData',[-651 980],'YData',[-51 460]) == 0);

imTransform(mask) = imTransform2(mask);

imshow(sampleFrame);
hold on;
plot(points(1, :), points(2, :), 'r', 'LineWidth', 3);
hold off;
frame = getframe(gcf); 
imwrite(frame.cdata, './s0450.jpg');

imshow(refFrame);
hold on;
plot(pointsPot(1, :), pointsPot(2, :), 'r', 'LineWidth', 3);
hold off;
frame = getframe(gcf); 
imwrite(frame.cdata, './s0270.jpg');

imwrite(imTransform, './overlap.jpg');

%% Part2 panorama/homographies

temp = zeros(3, 3, 4);
homPairs = [90, 270, 450, 630, 810 
           270, 450, 450, 450, 630];

outputX = [-651, 980];
outputY = [-51, 460];

for i = 1:5
    image1 = imread(sprintf('./frames/f%04d.jpg', homPairs(2, i)));
    image2 = imread(sprintf('./frames/f%04d.jpg', homPairs(1, i)));
    temp(:, :, i) = auto_homography(image2, image1);
end

temp(:, :, 1) = temp(:, :, 2) * temp(:, :, 1);
temp(:, :, 3) = eye(3);
temp(:, :, 5) = temp(:, :, 4) * temp(:, :, 5);


M = ones(360, 480, 3);
outputWindow = zeros(outputY(2) - outputY(1) + 1, outputX(2) - outputX(1) + 1, 3);

for i = length(homPairs):-1:1
    tMapping = maketform('projective', temp(:, :, i)');
    image2 = im2double(imread(sprintf('./frames/f%04d.jpg', homPairs(1, i))));
    imTransform = imtransform(image2, tMapping, 'XData', outputX, 'YData', outputY);
    mask = imtransform(M, tMapping, 'XData', outputX, 'YData', outputY);
    outputWindow = outputWindow .* (1 - mask) + imTransform .* mask;
end

save('./panorama.mat', 'master_trans');
imwrite(outputWindow, './panorama.jpg');

%% Part 3 Mapping Plane

inputX = [1, 480];
inputY = [1, 360];

inputWidth = inputX(2) - inputX(1) + 1;
inputHeight = inputY(2) - inputY(1) + 1;

outputX = [-651, 980];
outputY = [-51, 460];

outputWidth = outputX(2) - outputX(1) + 1;
outputHeight = outputY(2) - outputY(1) + 1;

hookFrames = [90, 270, 450, 630, 810];

mapping = zeros(3, 3, 900);
iterations = 900 / length(hookFrames);

index = 1;
for i = 1:5
    image = imread(sprintf('./frames/f%04d.jpg', hookFrames(i)));
    for j = 1:iterations
        respImage = imread(sprintf('./frames/f%04d.jpg', index));
        mapping(:, :, index) = auto_homography(respImage, image);
        index = index + 1;
    end
    mapping(:, :, hookFrames(i)) = eye(3);
end

save('./movie.mat', 'movie_trans');
load('./panorama.mat');
load('./movie.mat');

weight = zeros(outputHeight, outputWidth, 3);

M = ones(inputHeight, inputWidth, 3);

for i = 1:length(hookFrames)
    
    T = mapping(:, :, i);

    for j = 1:iterations
        TMapping = maketform('projective', (T * mapping(:, :, index))');
        respImage = im2double(imread(sprintf('./frames/f%04d.jpg', index)));
        mt = imtransform(M, TMapping, 'XData', outputX, 'YData', outputY);
        imTransform = imtransform(respImage, TMapping, 'XData', outputX, 'YData', outputY);
        weight = weight + mt;
        imwrite(imTransform, sprintf('./aligned_frames/a%04d.jpg', index));
        index = index + 1;
    end
end
save('./aligned_frames/weights.mat', 'frame_weights');

%% Part 4 and 5 Background image and movie

inputX = [1, 480];
input = [1, 360];

hookFrames = [90, 270, 450, 630, 810];
temp = 900 / length(hookFrames);

outputX = [-651, 980];
outputY = [-51, 460];

load('./aligned_frames/weights.mat');
outputWindow = zeros(output_height, output_width, 3);

for i = 1:900
    outputWindow = outputWindow + im2double(imread(sprintf('./aligned_frames/a%04d.jpg', i)));
end

frameWeight(frameWeight < 1) = 1;

outputWindow = outputWindow ./ frameWeight;
imwrite(outputWindow, './background.jpg');

load('./panorama.mat');
load('./movie.mat');

bgImage = imread('./background.jpg');

idx = 1;
for i = 1:length(hookFrames)
    T = T(:, :, i);
    
    for j = 1:temp            
        tInverse = maketform('projective', inv(T * movie_trans(:, :, idx))');        
        imTransform = imtransform(bgImage, tInverse, 'UData', outputX, 'VData', outputY, 'XData', inputX, 'YData', input_y);
        imwrite(imTransform, sprintf('./background/f%04d.jpg', idx));
        idx = idx + 1;
    end
end

%% Part 6 Forground Movie
inputX = [1, 480];
inputY = [1, 360];

hookFrames = [90, 270, 450, 630, 810];

inputWidth = inputX(2) - inputX(1) + 1;
inputHeight = inputY(2) - inputY(1) + 1;

outputX = [-651, 980];
outputY = [-51, 460];

outputWidth = outputX(2) - outputX(1) + 1;
outputHeight = outputY(2) - outputY(1) + 1;

temp = 900 / 5;

load('./panorama.mat');
load('./movie.mat');

frame_weights = zeros(outputHeight, outputWidth, 3);
M = ones(inputHeight, inputWidth, 3);

idx = 1;
for i = 1:5
    T = master_trans(:, :, i);
    for j = 1:temp 
        tInverse = maketform('projective', inv(T * movie_trans(:, :, idx))');
        imagesAligned = im2double(imread(sprintf('./aligned_frames/a%04d.jpg', idx)));
        imageTransform = imtransform(imagesAligned, tInverse, 'UData', outputX, 'VData', outputY, 'XData', inputX, 'YData', inputY);
        imwrite(imageTransform, sprintf('./inverse/f%04d.jpg', idx));
        idx = idx + 1;
    end
end

for i = 1:900
    foreground = im2double(imread(sprintf('./inverse/f%04d.jpg', i)));
    background = im2double(imread(sprintf('./background/f%04d.jpg', i)));
    diff_mask = repmat((sum(abs(background - foreground), 3) < 0.3), 1, 1, 3);
    foreground(diff_mask) = 0;
    imwrite(foreground, sprintf('./foreground/f%04d.jpg', i));
end

%% EC Wider video
outputX = [-651, 980];
outputY = [-51, 460];

inputX = [-121, 600];
inputY = [1, 360];

hookFrames = [90, 270, 450, 630, 810];
dependencies = 900 / length(hookFrames);

idx = 1;

load('./video1/panorama.mat');
load('./video1/movie.mat');
image = imread('./video1/background.jpg');

for i = 1:length(hookFrames)
    T = temp(:, :, i);
    for j = 1:dependencies
        tInverse = maketform('projective', inv(T * movie_trans(:, :, idx))');
        imageTransform = imtransform(image, tInverse, 'UData', outputX, 'VData', outputY, 'XData', inputX, 'YData', inputY);
        imwrite(imageTransform, sprintf('./wider/f%04d.jpg', idx));
        idx = idx + 1;
    end
end