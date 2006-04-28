function model = fgplvmExpandParam(model, params)

% FGPLVMEXPANDPARAM Expand a parameter vector into a GP-LVM model.
%
% model = fgplvmExpandParam(model, params)
%

% Copyright (c) 2006 Neil D. Lawrence
% fgplvmExpandParam.m version 1.3



startVal = 1;
if isfield(model, 'back')
  endVal = model.back.numParams;
  model.back = modelExpandParam(model.back, params(startVal:endVal));
  model.X = modelOut(model.back, model.y);
else
  endVal = model.N*model.q;
  model.X = reshape(params(startVal:endVal), model.N, model.q);
end
startVal = endVal+1;
endVal = endVal + model.kern.nParams;

switch model.approx
 case 'ftc'
  endVal = endVal;
 case {'dtc', 'fitc', 'pitc'}
  if model.fixInducing
    % account for beta attached to the end.
    endVal = endVal + 1; 
    % X_u values are taken from X values.
    model.X_u = model.X(model.inducingIndices, :);
  else
    % Parameters include inducing variables and beta.
    endVal = endVal + model.q*model.k + 1;
  end
 case 'nftc'
  % account for beta attached to the end.
  endVal = endVal + 1;     

 otherwise
  error('Unknown approximation type.')
end
if model.learnScales
  endVal = endVal + model.d;
end
model = gpExpandParam(model, params(startVal:endVal));


% Give parameters to dynamics if they are there.
if isfield(model, 'dynamics') & ~isempty(model.dynamics)
  startVal = endVal + 1;
  endVal = length(params);

  % Fill the dynamics model with current latent values.
  model.dynamics = modelSetLatentValues(model.dynamics, model.X);

  % Update the dynamics model with parameters (thereby forcing recompute).
  model.dynamics = modelExpandParam(model.dynamics, params(startVal:endVal));
end

