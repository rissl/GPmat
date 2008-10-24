function kern = rbfKernParamInit(kern)

% RBFKERNPARAMINIT RBF kernel parameter initialisation.
% The radial basis function kernel (RBF) is sometimes also known as
% the squared exponential kernel. It is a very smooth non-linear
% kernel and is a popular choice for generic use.
%
% k(x_i, x_j) = sigma2 * exp(-gamma/2 *(x_i - x_j)'*(x_i - x_j))
%
% The parameters are sigma2, the process variance (kern.variance)
% and gamma, the inverse width (kern.inverseWidth). The inverse
% width controls how wide the basis functions are, the larger
% gamma, the smaller the basis functions are.
%
% There is also an automatic relevance determination version of
% this kernel provided.
%
% SEEALSO : rbfardKernParamInit
%
% FORMAT
% DESC initialises the radial basis function
%  kernel structure with some default parameters.
% ARG kern : the kernel structure which requires initialisation.
% RETURN kern : the kernel structure with the default parameters placed in.
%
% SEEALSO : kernCreate, kernParamInit
%
% COPYRIGHT : Neil D. Lawrence, 2004, 2005, 2006

% KERN


kern.inverseWidth = 1;
kern.variance = 1;
% kern.inverseWidth = 10*rand;
% kern.variance = 10*rand;
kern.nParams = 2;

% Constrains parameters positive for optimisation.
kern.transforms.index = [1 2];
kern.transforms.type = optimiDefaultConstraint('positive');
kern.isStationary = true;