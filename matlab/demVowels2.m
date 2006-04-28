% DEMVOWELS2 Model the vowels data with a 2-D FGPLVM using RBF kernel and back constraints.
%
% 

% Copyright (c) 2006 Neil D. Lawrence
% demVowels2.m version 1.1



% Fix seeds
randn('seed', 1e5);
rand('seed', 1e5);

dataSetName = 'vowels';
experimentNo = 2;

% load data
[Y, lbls] = lvmLoadData(dataSetName);

% Set up model
options = fgplvmOptions('fitc');
options.numActive = 200;
latentDim = 2;
d = size(Y, 2);

model = fgplvmCreate(latentDim, d, Y, options);

% Optimise the model.
iters = 1000;
display = 1;

model = fgplvmOptimise(model, display, iters);

% Save the results.
capName = dataSetName;;
capName(1) = upper(capName(1));
save(['dem' capName num2str(experimentNo) '.mat'], 'model');

if exist('printDiagram') & printDiagram
  fgplvmPrintPlot(model, lbls, capName, experimentNo);
end

% Load the results and display dynamically.
fgplvmResultsDynamic(dataSetName, experimentNo, 'vector')

errors = fgplvmNearestNeighbour(model, lbls);
