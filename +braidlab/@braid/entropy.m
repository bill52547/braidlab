function [varargout] = entropy(b,varargin)
%ENTROPY   Topological entropy of a braid.
%   ENTR = ENTROPY(B) returns the topological entropy of the braid B.  More
%   precisely, ENTR is the maximum growth rate of a loop under iteration of
%   B.  If the braid B labels a pseudo-Anosov isotopy class on the punctured
%   disk, then ENTR is the topological entropy of the pseudo-Anosov
%   representative.  The maximum number of iterations is chosen such that if
%   the iteration fails to converge, the braid is most likely finite-order
%   and an entropy of zero is returned.
%
%   ENTR = ENTROPY(B,TOL) also specifies the absolute tolerance TOL (default
%   1e-6) that should be aimed for.  TOL is only approximate: if the
%   iteration converges slowly it can be off by a small amount.
%
%   ENTR = ENTROPY(B,TOL,MAXIT) also specifies the maximum number of
%   iterations MAXIT to try before giving up.  The default is computed based
%   on TOL and the extreme case given by the small-dilatation psi braids.
%
%   ENTR = ENTROPY(B,0,MAXIT) uses a tolerance of zero, which means
%   that exactly MAXIT iterations are performed and convergence is not
%   checked for.  The final value of the entropy at the end of
%   iteration is returned.
%
%   ENTR = ENTROPY(B,TOL,MAXIT,NCONV) or ENTROPY(B,TOL,[],NCONV) demands
%   that the tolerance TOL be achieved NCONV consecutive times (default 3).
%   For low-entropy braids, achieving TOL a few times does not guarantee TOL
%   digits, so increasing NCONV is required for extreme accuracy.
%
%   ENTR = ENTROPY(B,TOL,MAXIT,NCONV,LOOPLENGTH) specifies how loop
%   length is computed in entropy
%   0 - intaxis - # of intersections with horizontal axis (Dynnikov-Wiest)
%   1 - minlength - minimal topological length
%   2 - L2 norm of Dynnikov coordinates (default)
%
%   Note that the choice of lengths should affect the result only
%   over a finite number of iterations. If computation with
%   small TOL (e.g., 1e-6) and unspecified MAXINT, then the
%   L2-length (LOOPLENGTH = 0) should be used as it is the
%   fastest. But if only a small number of iterations is used, then
%   one choice of loop length might be preferred over another.
%
%   [ENTR,PLOOP] = ENTROPY(B,...) also returns the projective loop PLOOP
%   corresponding to the generalized eigenvector.  The Dynnikov coordinates
%   are normalized such that NORM(PLOOP.COORDS)=1.
%
%   ENTR = ENTROPY(B,'trains') uses the Bestvina-Handel train-track
%   algorithm instead of the Moussafir iterative technique.  (The flags 'BH'
%   and 'train-tracks' can also be used instead of 'trains'.)  Note that
%   for long braids this algorithm becomes very inefficient.
%
%   This is a method for the BRAID class.
%   See also BRAID, LOOP.MINLENGTH, LOOP.INTAXIS, BRAID.TNTYPE, PSIROOTS.

% <LICENSE
%   Braidlab: a Matlab package for analyzing data using braids
%
%   http://bitbucket.org/jeanluc/braidlab/
%
%   Copyright (C) 2013--2014  Jean-Luc Thiffeault <jeanluc@math.wisc.edu>
%                             Marko Budisic         <marko@math.wisc.edu>
%
%   This file is part of Braidlab.
%
%   Braidlab is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   Braidlab is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with Braidlab.  If not, see <http://www.gnu.org/licenses/>.
% LICENSE>

import braidlab.util.debugmsg

%% Process inputs 
import braidlab.util.validateflag

parser = inputParser;

parser.addRequired('b', @(x)isa(x,'braidlab.braid') );
parser.addParameter('tol', 1e-6, @isnumeric );
parser.addParameter('maxit', nan, @isnumeric );
parser.addParameter('nconv', nan, @isnumeric );
parser.addParameter('type','l2',@ischar);
parser.addParameter('finite',false,@islogical);

parser.parse( b, varargin );

params = parser.Results;

b = params.b;

%% 2-POINT and ZERO BRAIDS HAVE ENTROPY ZERO
if isempty(b.word) || b.n < 3
  varargout{1} = 0;
  if nargout > 1, varargout{2} = []; end
  return
end

% determine type of algorithm
algtype = validateflag(parser.type, 'intaxis','minlength','l2',...
                       {'trains','train-tracks','bh'});

%% TRAIN-TRACKS ALGORITHM
if strcmpi( algtype, 'trains')
  if nargout > 1
    error('BRAIDLAB:braid:entropy:nargout',...
          'Too many output arguments for ''trains'' option.')
  end
  [TN,varargout{1}] = tntype_helper(b.word,b.n);
  if strcmpi(TN,'reducible1')
    warning('BRAIDLAB:braid:entropy:reducible',...
            'Reducible braid... falling back on iterative method.')
    tol = toldef;
  else
    return
  end
end

%% ITERATIVE ALGORITHM

% finite computation 
if params.finite 
  params.tol = 0;
end

if ( params.tol == 0 ) && ( isnan(maxit) || maxit <= 0 )
  error('BRAIDLAB:braid:entropy:badarg', ...
        'Must specify either tolerance>0 or maximum iterations.')
end

%% STOPPED HERE %%
maxit = params.maxit;
nconv = params.nconv;


%% PROCESS SECOND ARGUMENT - either tolerance or char
if isnan(maxit)
  % Use the spectral gap of the lowest-entropy braid to compute the
  % maximum number of iterations.
  % The maximum number of iterations is chosen based on the tolerance and
  % spectral gap.  Roughly, each iteration yields spgap decimal digits.
  spgap = 19 * b.n^-3;
  maxit = ceil(-log10(tol) / spgap) + 30;
end

% Number of convergence criteria required to be satisfied.
% Consecutive convergence is more desirable, but becomes hard to achieve
% for low-entropy braids.
if nargin < 4 || isempty(nconvreq), nconvreq = 3; end

% choice of length - default is 2 (l2 norm)
if nargin < 5, looplength = 2; end
validateattributes(looplength, {'numeric'}, ...
                   {'integer', '>=',0,'<=',2} );

switch(looplength)
  case 0,
    lenfun = @(l)l.intaxis;
    usediscount = true;
  case 1,
    lenfun = @minlength;
    usediscount = false;
  case 2,
    lenfun = @l2norm;
    usediscount = false;
  otherwise,
    error('BRAIDLAB:braid:entropy:unknownlength', ['Supported loop ' ...
                        'length flags are 0,1,2.'] )
end

%% ITERATIVE ALGORITHM

% Use a fundamental group generating set as the initial multiloop.
u = braidlab.loop(b.n,@double,'bp');

%% determine if mex should be attempted
global BRAIDLAB_braid_nomex
if ~exist('BRAIDLAB_braid_nomex') || ...
      isempty(BRAIDLAB_braid_nomex) || ...
      BRAIDLAB_braid_nomex == false
  usematlab = false;
else
  usematlab = true;
end

params = sprintf(['TOL = %.1e \t MAXIT = %d \t NCONV = %d \t LOOPLENGTH ' ...
                  '= %d'], tol,maxit,nconvreq,looplength);

braidlab.util.debugmsg( params, 1);

if ~usematlab
  try
    % Only works on double precision numbers.
    %
    % Limited argument checking with
    % BRAIDLAB:entropy_helper:badlengthflag and
    % BRAIDLAB:entropy_helper:badarg
    % errors.
    [entr,i,u.coords] = entropy_helper(b.word,u.coords,...
                                       maxit,nconvreq,...
                                       tol,looplength, true);
    usematlab = false;
  catch me
    warning(me.identifier, [ me.message ...
                        ' Reverting to Matlab entropy'] );
    usematlab = true;
  end
end

if usematlab
  
  nconv = 0; 
  entr0 = -1; 
  
  % discount extra arcs if intaxis is used
  switch(looplength)
    case 0,
      discount = b.n - 1;
    otherwise,
      discount = 0;
  end
  
  currentLoopLength = lenfun(u) - discount;
  for i = 1:maxit
    
    % normalize discounting factor
    discount = discount/currentLoopLength;
    
    % normalize braid coordinates to avoid overflow
    u.coords = u.coords/currentLoopLength;  
    
    % apply braid to loop
    u = b*u;
    
    % update loop length
    currentLoopLength = lenfun(u) - discount;
    
    entr = log(currentLoopLength);
    
    debugmsg(sprintf('  iteration %d  entr=%.10e  diff=%.4e',...
                     i,entr,entr-entr0),2)
    % Check if we've converged to requested tolerance.
    if abs(entr-entr0) < tol
      nconv = nconv + 1;
      % Only break if we converged nconvreq times, to prevent accidental
      % convergence.
      if nconv >= nconvreq
        break;
      end
    elseif nconv > 0
      % We failed to converge nconvreq times in a row: reset nconv.
      debugmsg(sprintf('Converged %d time(s) in a row (< %d)',nconv,nconvreq))
      nconv = 0;
    end
    entr0 = entr;
  end
end

if tol > 0 % If tolerance is 0, we never expected convergence.
  if i >= maxit
    tol
    warning('BRAIDLAB:braid:entropy:noconv', ...
            ['Failed to converge to requested tolerance; braid is likely' ...
             ' finite-order or has low entropy.  Returning zero entropy.'])
    entr = 0;
  else
    debugmsg(sprintf(['Converged %d time(s) in a row after ' ...
                      '%d iterations'],nconvreq,i))
  end
end

varargout{1} = entr;

if nargout > 1
  u.coords = u.coords/currentLoopLength;
  varargout{2} = u;
end
