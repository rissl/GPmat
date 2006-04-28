function [gParam, gX_u, gX] = gpLogLikeGradients(model, ...
                                                  X, Y, X_u)

% GPLOGLIKEGRADIENTS Compute the gradients for the parameters and X.
%
% [gParam, gX_u, gX] = gpLogLikeGradients(model, ...
%                                                  X, Y, X_u)
%

% Copyright (c) 2006 Neil D. Lawrence
% gpLogLikeGradients.m version 1.4



if nargin < 4
  if isfield(model, 'X_u')
    X_u = model.X_u;
  else
    X_u = [];
  end
  if nargin < 3
    Y = model.m;
  end
  if nargin < 2
    X = model.X;
  end
end

gX_u = [];
gX = [];

g_scaleBias = gpScaleBiasGradient(model);

switch model.approx
 case 'ftc'
  % Full training conditional.
  
  if nargout > 2
    %%% Prepare to Compute Gradients with respect to X %%%
    gKX = kernGradX(model.kern, X, X);
    gKX = gKX*2;
    dgKX = kernDiagGradX(model.kern, X);
    for i = 1:model.N
      gKX(i, :, i) = dgKX(i, :);
    end
    gX = zeros(model.N, model.q);
  end
  
  %%% Compute Gradients of Kernel Parameters %%%
  gParam = zeros(1, model.kern.nParams);

  for k = 1:model.d
    gK = localCovarianceGradients(model, Y(:, k), k);
    if nargout > 2
      %%% Compute Gradients with respect to X %%%
      ind = gpDataIndices(model, k);
      counter = 0;
      for i = ind
        counter = counter + 1;
        for j = 1:model.q
          gX(i, j) = gX(i, j) + gKX(ind, j, i)'*gK(:, counter);
        end
      end
    end
    %%% Compute Gradients of Kernel Parameters %%%
    if model.isMissingData
      gParam = gParam ...
               + kernGradient(model.kern, ...
                              X(model.indexPresent{k}, :), ...
                              gK);
    else
      gParam = gParam + kernGradient(model.kern, X, gK);
    end
  end
  gParam = [gParam g_scaleBias];
 case {'dtc', 'fitc', 'pitc'}
  % Sparse approximations.
  [gK_u, gK_uf, gK_star, g_beta] = gpCovGrads(model, Y);
  
  %%% Compute Gradients of Kernel Parameters %%%
  gParam_u = kernGradient(model.kern, X_u, gK_u);
  gParam_uf = kernGradient(model.kern, X_u, X, gK_uf);

  g_param = gParam_u + gParam_uf;
  
  %%% Compute Gradients with respect to X_u %%%
  gKX = kernGradX(model.kern, X_u, X_u);
  
  % The 2 accounts for the fact that covGrad is symmetric
  gKX = gKX*2;
  dgKX = kernDiagGradX(model.kern, X_u);
  for i = 1:model.k
    gKX(i, :, i) = dgKX(i, :);
  end
  
  if ~model.fixInducing | nargout > 1
    % Allocate space for gX_u
    gX_u = zeros(model.k, model.q);
    % Compute portion associated with gK_u
    for i = 1:model.k
      for j = 1:model.q
        gX_u(i, j) = gKX(:, j, i)'*gK_u(:, i);
      end
    end
    
    % Compute portion associated with gK_uf
    gKX_uf = kernGradX(model.kern, X_u, X);
    for i = 1:model.k
      for j = 1:model.q
        gX_u(i, j) = gX_u(i, j) + gKX_uf(:, j, i)'*gK_uf(i, :)';
      end
    end
  end
  if nargout > 2
    %%% Compute gradients with respect to X %%%
    
    % Allocate space for gX
    gX = zeros(model.N, model.q);
    
    % this needs to be recomputed so that it is wrt X not X_u
    gKX_uf = kernGradX(model.kern, X, X_u);
    
    for i = 1:model.N
      for j = 1:model.q
        gX(i, j) = gKX_uf(:, j, i)'*gK_uf(:, i);
      end
    end    
  end
case 'nftc'
  % Noisy Full training conditional.
  
  if nargout > 2
    %%% Prepare to Compute Gradients with respect to X %%%
    gKX = kernGradX(model.kern, X, X);% this seems to be the same for all
    gKX = gKX*2;
    dgKX = kernDiagGradX(model.kern, X);
    for i = 1:model.N
      gKX(i, :, i) = dgKX(i, :);
    end
    gX = zeros(model.N, model.q);
  end
  
  %%% Compute Gradients of Kernel Parameters %%%
  gParam = zeros(1, model.kern.nParams);
  g_beta = 0;
  for k = 1:model.d
    gK = localCovarianceGradients(model, Y(:, k), k);
    
    g_beta = g_beta - model.beta.^-2.*trace(gK);%*
    %g_beta = g_beta - model.beta(:,k).^-2.*trace(gK);%*
    % If performing KL correction we need to include the correction term
    % for beta
    if model.KLCorrectionTerm
        g_beta = g_beta - 0.5.*sum(model.KLVariance(:,k)-model.m(:,k).*model.m(:,k));       
    end
    fhandle = str2func([model.betaTransform 'Transform']);
    g_beta = g_beta*fhandle(model.beta, 'gradfact');
    
    if nargout > 2
      %%% Compute Gradients with respect to X %%%
      ind = gpDataIndices(model, k);
      counter = 0;
      for i = ind
        counter = counter + 1;
        for j = 1:model.q
          gX(i, j) = gX(i, j) + gKX(ind, j, i)'*gK(:, counter);
        end
      end
    end
    %%% Compute Gradients of Kernel Parameters %%%
    if model.isMissingData
      gParam = gParam ...
               + kernGradient(model.kern, ...
                              X(model.indexPresent{k}, :), ...
                              gK);
    else
      gParam = gParam + kernGradient(model.kern, X, gK);
    end
  end
  
  
  
  gParam = [gParam g_scaleBias];
  
   

    %end  
 otherwise
  error('Unknown model approximation.')
end

switch model.approx
 case 'ftc'
  % Full training conditional. Nothing required here.
 case 'dtc'
  % Deterministic training conditional.  

  % append beta gradient to end of parameters
  gParam = [g_param(:)' g_scaleBias g_beta];
 
 case 'fitc'
  % Fully independent training conditional.
  
  if nargout > 2
    % deal with diagonal term's effect on X gradients..
    gKXdiag = kernDiagGradX(model.kern, X);
    for i = 1:model.N
      gX(i, :) = gX(i, :) + gKXdiag(i, :)*gK_star(i);
    end
  end
  
  % deal with diagonal term's affect on kernel parameters.
  g_param = g_param + kernDiagGradient(model.kern, X, gK_star);

  % append beta gradient to end of parameters  
  gParam = [g_param(:)' g_scaleBias g_beta];

 case 'pitc'
  % Partially independent training conditional.
  
  if nargout > 2
    % deal with block diagonal term's effect on X gradients.
    startVal = 1;
    for i = 1:length(model.blockEnd)
      endVal = model.blockEnd(i);
      ind = startVal:endVal;
      gKXblock = kernGradX(model.kern, X(ind, :), X(ind, :));
      
      % The 2 accounts for the fact that covGrad is symmetric
      gKXblock = gKXblock*2;
      
      % fix diagonal
      dgKXblock = kernDiagGradX(model.kern, X(ind, :));
      for j = 1:length(ind)
        gKXblock(j, :, j) = dgKXblock(j, :);
      end
      
      for j = ind
        for k = 1:model.q
          subInd = j - startVal + 1;
          gX(j, k) = gX(j, k) + gKXblock(:, k, subInd)'*gK_star{i}(:, subInd);
        end
      end
      startVal = endVal + 1;
    end
  end
  % deal with block diagonal's effect on kernel parameters.
  for i = 1:length(model.blockEnd);
    ind = gpBlockIndices(model, i);
    g_param = g_param ...
              + kernGradient(model.kern, X(ind, :), gK_star{i});
  end

  % append beta gradient to end of parameters
  gParam = [g_param(:)' g_scaleBias g_beta];
case 'nftc'
  % Full training conditional. Nothing required here.
  % append beta gradient to end of parameters
  gParam = [gParam g_beta];
 otherwise
  error('Unrecognised model approximation');
end

% if there is only one output argument, pack gX_u and gParam into it.
if nargout == 1;
  gParam = [gX_u(:)' gParam];
end

function gK = localCovarianceGradients(model, y, dimension)

% FGPLVMCOVARIANCEGRADIENTS
switch model.approx
 case 'ftc'
     if ~isfield(model, 'isSpherical') | model.isSpherical
         invKy = model.invK_uu*y;
         gK = -model.invK_uu + invKy*invKy';
     else
         if model.isMissingData
             m = y(model.indexPresent{dimension});
         else
             m = y;
         end
         invKy = model.invK_uu{dimension}*m;
         gK = -model.invK_uu{dimension} + invKy*invKy';
     end
     gK = gK*.5;
 case 'nftc'
     if ~isfield(model, 'isSpherical') | model.isSpherical
         invKy = model.Ainv*y;
         gK = -model.Ainv + invKy*invKy';
     else
         if model.isMissingData
             m = y(model.indexPresent{dimension});
         else
             m = y;
         end
         invKy = model.Ainv{dimension}*m;
         gK = -model.Ainv{dimension} + invKy*invKy';
     end
     gK = gK*.5;
    
otherwise
  error('Model approximation not covered for localCovarianceGradients');
end
