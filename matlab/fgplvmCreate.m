function model = fgplvmCreate(q, d, Y, options)

% FGPLVMCREATE Create a GPLVM model with inducing varibles.
%
% model = fgplvmCreate(q, d, Y, options)
%

% Copyright (c) 2006 Neil D. Lawrence
% fgplvmCreate.m version 1.3



if size(Y, 2) ~= d
  error(['Input matrix Y does not have dimension ' num2str(d)]);
end

if isstr(options.initX)
  initFunc = str2func([options.initX 'Embed']);
  X = initFunc(Y, q);
else
  if size(options.initX, 1) == size(Y, 1) ...
        & size(options.initX, 2) == q
    X = options.initX;
  else
    error('options.initX not in recognisable form.');
  end
end
    
model = gpCreate(q, d, X, Y, options);

model.type = 'fgplvm';

if isstruct(options.prior)
  model.prior = options.prior;
else
  if ~isempty(options.prior)
    model.prior = priorCreate(options.prior);
  end
end

if isstruct(options.inducingPrior)
  model.inducingPrior = options.inducingPrior;
else
  if ~isempty(options.inducingPrior)
    model.inducingPrior = priorCreate(options.inducingPrior);
  end
end

if isfield(options, 'back') & ~isempty(options.back)
  if isstruct(options.back)
    model.back = options.back;
  else
    if ~isempty(options.back)
      model.back = modelCreate(options.back, model.d, model.q, options.backOptions);
    end
  end
  if options.optimiseInitBack
    % Match back model to initialisation.
    model.back = mappingOptimise(model.back, model.y, model.X);
  end
end

initParams = fgplvmExtractParam(model);
% This forces kernel computation.
model = fgplvmExpandParam(model, initParams);

