function model = gpUpdateKernels(model, X, X_u, rawBeta)

% GPUPDATEKERNELS Update the kernels that are needed.
%
% model = gpUpdateKernels(model, X, X_u, rawBeta)
%

% Copyright (c) 2006 Neil D. Lawrence
% gpUpdateKernels.m version 1.3



if nargin < 4
  rawBeta = [];
end
if ~isempty(rawBeta)
  fhandle = str2func([model.betaTransform 'Transform']);
  model.beta = fhandle(rawBeta, 'atox');
end
switch model.approx
 case {'ftc','nftc'}
  % Long term should allow different kernels in each dimension here.
  model.K_uu = kernCompute(model.kern, X);
  
  if ~isfield(model, 'isSpherical') | model.isSpherical
    [model.invK_uu, U] = pdinv(model.K_uu);
    model.logDetK_uu = logdet(model.K_uu, U);
  else   
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      [model.invK_uu{i}, U] = pdinv(model.K_uu(ind, ind));
      model.logDetK_uu(i) = logdet(model.K_uu(ind, ind), U);
    end
  end
 case {'dtc', 'fitc', 'pitc'}
  model.K_uu = kernCompute(model.kern, X_u);
  
  if ~isfield(model.kern, 'whiteVariance') | model.kern.whiteVariance == 0
    % There is no white noise term so add some jitter.
    model.K_uu = model.K_uu ...
        + sparseDiag(repmat(1e-6*mean(abs(diag(model.K_uu))), size(model.K_uu, 1), 1));
  end
  model.K_uf = kernCompute(model.kern, X_u, X);
  [model.invK_uu, U] = pdinv(model.K_uu);
  model.logDetK_uu = logdet(model.K_uu, U);

end

  
switch model.approx
 case 'ftc'
  % Compute the inner product values.
  if ~isfield(model, 'isSpherical') | model.isSpherical
    for i = 1:model.d
      model.innerProducts(1, i) = model.m(:, i)'*model.invK_uu...
          *model.m(:, i);
    end
  else
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      model.innerProducts(1, i) = model.m(ind, i)'*model.invK_uu{i}...
          *model.m(ind, i);
    end
  end
  
 case 'dtc'
  if ~isfield(model, 'isSpherical') | model.isSpherical
    % Compute A = invBetaK_uu + K_uf*K_uf'
    K_uf2 = model.K_uf*model.K_uf';
    model.A = (1/model.beta)*model.K_uu+ K_uf2;
    % This can become unstable when K_uf2 is low rank.
    [model.Ainv, U] = pdinv(model.A);
    model.logdetA = logdet(model.A, U);
 
    % compute inner products
    for i = 1:model.d
      E = model.K_uf*model.m(:, i);    
      model.innerProducts(1, i) = ...
          model.beta*(model.m(:, i)'*model.m(:, i) ...
                      - E'*model.Ainv*E);
    end
  else
    if ~model.isMissingData
      K_uf2 = model.K_uf*model.K_uf';
    end
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      % Compute A = invBetaK_uu + K_uf*K_uf'
      if model.isMissingData
        K_uf2 = model.K_uf(:, ind)*model.K_uf(:, ind)';
      end
      model.A{i} = (1/model.beta)*model.K_uu+ K_uf2;
      % This can become unstable when K_uf2 is low rank.
      [model.Ainv{i}, U] = pdinv(model.A{i});
      model.logdetA(i) = logdet(model.A{i}, U);
      % compute inner products
      E = model.K_uf(:, ind)*model.m(ind, i);    
      model.innerProducts(1, i) = ...
          model.beta*(model.m(ind, i)'*model.m(ind, i) ...
                      - E'*model.Ainv{i}*E);
    end
  end
  
 case 'fitc'
  model.diagK = kernDiagCompute(model.kern, X);
  if ~isfield(model, 'isSpherical') | model.isSpherical
    model.diagD = (1/model.beta) + model.diagK - sum(model.K_uf.*(model.invK_uu*model.K_uf), 1)';
    model.Dinv = sparseDiag(1./model.diagD);
    K_ufDinvK_uf = model.K_uf*model.Dinv*model.K_uf';
    model.A = model.K_uu + K_ufDinvK_uf;
    % This can become unstable when K_ufDinvK_uf is low rank.
    [model.Ainv, U] = pdinv(model.A);
    model.logDetA = logdet(model.A, U);
    
    % compute inner products
    for i = 1:model.d
      Dinvm = model.Dinv*model.m(:, i);
      K_ufDinvm = model.K_uf*Dinvm;
      model.innerProducts(1, i) = Dinvm'*model.m(:, i) - K_ufDinvm'*model.Ainv*K_ufDinvm;
    end
  else
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      model.diagD{i} = (1/model.beta) + model.diagK(ind) ...
          - sum(model.K_uf(:, ind).*(model.invK_uu*model.K_uf(:, ind)), 1)';
      model.Dinv{i} = sparseDiag(1./model.diagD{i});
      K_ufDinvK_uf = model.K_uf(:, ind)*model.Dinv{i}...
          *model.K_uf(:, ind)';
      model.A{i} = model.K_uu + K_ufDinvK_uf;
      % This can become unstable when K_ufDinvK_uf is low rank.
      [model.Ainv{i}, U] = pdinv(model.A{i});
      model.logDetA(i) = logdet(model.A{i}, U);
    
      % compute inner products
      Dinvm = model.Dinv{i}*model.m(ind, i);
      K_ufDinvm = model.K_uf(:, ind)*Dinvm;
      model.innerProducts(1, i) = Dinvm'*model.m(ind, i) - K_ufDinvm'*model.Ainv{i}*K_ufDinvm;
    end
      
  end
  
 case 'pitc'
  if ~isfield(model, 'isSpherical') | model.isSpherical
    model.A = model.K_uu;
    K_ufDinvm = zeros(model.k, model.d);
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      model.K{i} = kernCompute(model.kern, X(ind, :));
      model.D{i} = (1/model.beta)*eye(length(ind)) + model.K{i} - ...
          model.K_uf(:, ind)'*model.invK_uu*model.K_uf(:, ind);
      [model.Dinv{i}, U] = pdinv(model.D{i});
      model.logDetD(i) = logdet(model.D{i}, U);
      K_ufDinvK_uf = model.K_uf(:, ind)*model.Dinv{i}...
          *model.K_uf(:, ind)';
      model.A = model.A + K_ufDinvK_uf;
      Dinvm{i} = model.Dinv{i}*model.m(ind, :);
      K_ufDinvm = K_ufDinvm + model.K_uf(:, ind)*Dinvm{i};
    end
    % This can become unstable when K_ufDinvK_uf is low rank.
    [model.Ainv, U] = pdinv(model.A);
    model.logDetA = logdet(model.A, U);
    
    % compute inner products
    for i = 1:model.d
      model.innerProducts(1, i) = - K_ufDinvm(:, i)'*model.Ainv*K_ufDinvm(:, ...
                                                        i);
    end
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      for j = 1:model.d
        model.innerProducts(1, j) = model.innerProducts(1, j) ...
            + Dinvm{i}(:, j)'*model.m(ind, j);
      end
    end
  else
    for j = 1:model.d
      model.A{j} = model.K_uu;
      K_ufDinvm = zeros(model.k, model.d);
      for i = 1:length(model.blockEnd)
        ind = gpDataIndices(model, j, i);
        model.K{i, j} = kernCompute(model.kern, X(ind, :));
        model.D{i, j} = (1/model.beta)*eye(length(ind)) + model.K{i, j} - ...
            model.K_uf(:, ind)'*model.invK_uu*model.K_uf(:, ind);
        [model.Dinv{i, j}, U] = pdinv(model.D{i, j});
        model.logDetD(i, j) = logdet(model.D{i, j}, U);
        K_ufDinvK_uf = model.K_uf(:, ind)*model.Dinv{i, j}...
            *model.K_uf(:, ind)';
        model.A{j} = model.A{j} + K_ufDinvK_uf;
        Dinvm{i}(ind, j) = model.Dinv{i, j}*model.m(ind, j);
        K_ufDinvm(:, j) = K_ufDinvm(:, j) + model.K_uf(:, ind)*Dinvm{i}(ind, ...
                                                          j);
      end
      % This can become unstable when K_ufDinvK_uf is low rank.
      [model.Ainv{j}, U] = pdinv(model.A{j});
      model.logDetA(j) = logdet(model.A(j), U);
    end
    
    % compute inner products
    for j = 1:model.d
      model.innerProducts(1, j) = - K_ufDinvm(:, j)'*model.Ainv{j}*K_ufDinvm(:, ...
                                                        j);
    end
    for i = 1:length(model.blockEnd)
      ind = gpBlockIndices(model, i);
      for j = 1:model.d
        model.innerProducts(1, j) = model.innerProducts(1, j) ...
            + Dinvm{i}(ind, j)'*model.m(ind, j);
      end
    end
    
  end
  case 'nftc'
  % Compute the inner product values.
  if ~isfield(model, 'isSpherical') | model.isSpherical
      model.A = 1/model.beta*eye(size(model.K_uu))+model.K_uu;
      
      [model.Ainv, U] = pdinv(model.A);
      model.logDetA = logdet(model.A, U);
 
      for i = 1:model.d
          model.innerProducts(1, i) = model.m(:, i)'*model.Ainv...
              *model.m(:, i);
      end
  else
    for i = 1:model.d
      ind = gpDataIndices(model, i);
      model.A{i} =  1/model.beta*eye(size(model.K_uu{i}))+model.K_uu{i};
      % This can become unstable when K_uf2 is low rank.
      [model.Ainv{i}, U] = pdinv(model.A{i});
      model.logDetA(i) = logdet(model.A{i}, U);

      model.innerProducts(1, i) = model.m(ind, i)'*model.Ainv{i}...
          *model.m(ind, i);
    end
  end
 otherwise
  error('Unknown approximating criterion.')
end

