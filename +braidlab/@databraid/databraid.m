%DATABRAID   Class for representing braids created from data.
%   A DATABRAID object holds a braid created from data.  Unlike the BRAID
%   class, a DATABRAID remembers the times at which particles crossed.
%
%   In addition to the data members of the BRAID class, the class DATABRAID
%   has the following data member (property):
%
%    'tcross'   vector of interpolated crossing times
%
%   A DATABRAID has access to most of the methods of BRAID, though some of
%   them work a bit differently.  See in particular DATABRAID.EQ,
%   DATABRAID.COMPACT, and DATABRAID.MTIMES.  MPOWER and MINV are undefined.
%
%   METHODS('DATABRAID') shows a list of methods.
%
%   See also DATABRAID.DATABRAID (constructor).

% <LICENSE
%   Braidlab: a Matlab package for analyzing data using braids
%
%   http://github.com/jeanluct/braidlab
%
%   Copyright (C) 2013-2015  Jean-Luc Thiffeault <jeanluc@math.wisc.edu>
%                            Marko Budisic         <marko@math.wisc.edu>
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

classdef databraid < braidlab.braid
  properties
    tcross            % vector of interpolated crossing times
  end

  methods

    function br = databraid(XY,secnd,third)
    %DATABRAID   Construct a databraid object.
    %   B = DATABRAID(XY) constucts a databraid from a trajectory dataset XY.
    %   The data format is XY(1:NSTEPS,1:2,1:N), where NSTEPS is the number
    %   of time steps and N is the number of particles.
    %
    %   DATABRAID(XY,T) specifies the times of the datapoints.  T defaults
    %   to 1:NSTEPS.
    %
    %   DATABRAID(XY,T,PROJANG) or DATABRAID(XY,PROJ) uses a projection line
    %   with angle PROJANG (in radians) from the X axis to determine
    %   crossings.  The default is to project onto the X axis (PROJANG = 0).
    %
    %   DATABRAID(BB,T) creates a databraid from a braid BB and crossing
    %   times T.  T defaults to [1:length(BB)].
    %
    %   DATABRAID(W,T) creates a databraid from a list of generators W and
    %   crossing times T.  T defaults to [1:length(BB)].
    %
    %   This is a method for the DATABRAID class.
    %   See also DATABRAID, BRAID, BRAID.BRAID.
      if nargin < 1
        error('BRAIDLAB:databraid:databraid:badarg', ...
              'Not enough input arguments.')
      elseif isa(XY,'braidlab.braid')
        br.word = XY.word;
        br.n = XY.n;
        if nargin > 1
          br.tcross = secnd;
        else
          br.tcross = 1:length(br.word);
        end
        check_tcross(br);
        return
      elseif ismatrix(XY)
        br.n = max(size(XY));
        br.word = reshape(XY,[1 br.n]);
        if nargin > 1
          br.tcross = secnd;
        else
          br.tcross = 1:length(br.word);
        end
        check_tcross(br);
        return
      elseif nargin < 2
        t = 1:size(XY,1);
        proj = 0;
      elseif nargin < 3
        if isscalar(secnd)
          % The argument secnd is interpreted as a projection line angle.
          proj = secnd;
          t = 1:size(XY,1);
        else
          % The argument secnd is interpreted as a list of times.
          t = secnd;
          proj = 0;
        end
      end
      if nargin == 3
        t = secnd;
        proj = third;
      end
      if nargin > 3
        error('BRAIDLAB:databraid:databraid:badarg', ...
              'Too many input arguments.')
      end
      [b,br.tcross] = braidlab.braid.colorbraiding(XY,t,proj);
      br.word = b.word;
      br.n = b.n;
    end

    function b = braid(db)
    %BRAID   Convert a DATABRAID to a BRAID.
    %   C = BRAID(B) converts the databraid B to a regular braid object B
    %   by dropping the crossing times.
    %
    %   This is a method for the DATABRAID class.
    %   See also BRAID.BRAID.
      b = braidlab.braid(db.word,db.n);
    end

    function ee = eq(b1,b2)
    %EQ   Test databraids for equality.
    %   EQ(B1,B2) or B1==B2 returns TRUE if the two databraids B1 and B2 are
    %   equal.  Equality of databraids, unlike equality of braids, is
    %   defined lexicographically.  The list of crossing times must also be
    %   identical.
    %
    %   To check if the braids themselves are equal, convert to BRAID
    %   objects before testing: EQ(BRAID(B1),BRAID(B2)).
    %
    %   This is a method for the DATABRAID class.
    %   See also BRAID.EQ, BRAID.LEXEQ.
      ee = (lexeq(braid(b1),braid(b2)) | any(b1.tcross ~= b2.tcross));
    end

    function ee = ne(b1,b2)
    %NE   Test databraids for inequality.
    %   NE(B1,B2) or B1~=B2 returns ~EQ(B1,B2).
    %
    %   This is a method for the BRAID class.
    %   See also DATABRAID.EQ.
      ee = ~(b1 == b2);
    end

    function b12 = mtimes(b1,b2)
    %MTIMES   Multiply two databraids together or act on a loop by a databraid.
    %   C = B1*B2, where B1 and B2 are braid objects, return the product of
    %   the two databraids.  This is only well-defined if the crossing
    %   times of B1 are all earlier than those of B2.
    %
    %   L2 = B*L, where B is a braid and L is a loop object, returns a
    %   new loop L2 given by the action of B on L.
    %
    %   This is a method for the DATABRAID class.
    %   See also BRAID.MTIMES, DATABRAID, LOOP.
      if isa(b2,'braidlab.databraid')
        if b1.tcross(end) > b2.tcross(1)
          error('BRAIDLAB:databraid:mtimes:notchrono',...
                'First braid must have earlier times than second.')
        end
        b12 = braidlab.databraid(...
            braidlab.braid([b1.word b2.word],max(b1.n,b2.n)),...
            [b1.tcross b2.tcross]);
      elseif isa(b2,'braidlab.loop')
        % Action of databraid on a loop.
        b12 = mtimes@braidlab.braid(b1,b2);
      end
    end

    function bs = subbraid(b,s)
      ; %#ok<NOSEM>
      % Do not put comments above the first line of code, so the help
      % message from braid.subbraid is displayed.

      % Use the optional return argument ii for braid.subbraid, which gives
      % a list of the generators that were kept.
      [bb,ii] = subbraid@braidlab.braid(b,s);
      bs = braidlab.databraid(bb,b.tcross(ii));
    end

    function c = tensor(varargin)
    %TENSOR   Tensor product of databraids.
    %   C = TENSOR(B1,B2) returns the tensor product of the databraids B1 and
    %   B2, which is the databraid obtained by laying B1 and B2 side-by-side,
    %   with B1 on the left.  The crossing times are sorted chronologically.
    %
    %   C = TENSOR(B1,B2,B3,...) returns the tensor product of several
    %   databraids.
    %
    %   This is a method for the DATABRAID class.
    %   See also DATABRAID, BRAID.TENSOR.
      if nargin < 2
        error('BRAIDLAB:databraid:tensor:badarg', ...
              'Need at least two databraids.')
      elseif nargin == 2
        a = varargin{1}; b = varargin{2};
        % Sort, but keep track of index changes.
        [tcr,idx] = sort([a.tcross b.tcross]);
        c = braidlab.databraid(tensor@braidlab.braid(a,b),tcr);
        % Re-order the generators according to sorting.
        c.word = c.word(idx);
      else
        c = tensor(varargin{1},tensor(varargin{2:end}));
      end
    end

    function c = compact(b)
    %COMPACT   Try to shorten a databraid by cancelling generators.
    %   C = COMPACT(B) attempts to shorten a databraid B by cancelling
    %   adjacent generators, and returns the shortened databraid C.  The
    %   crossing times corresponding to the cancelled generators are
    %   dropped from the TCROSS data member of C.
    %
    %   Note that DATABRAID.COMPACT is less effective than BRAID.COMPACT,
    %   since it preserves the order of generators.  It does this in order
    %   to maintain the ordering of the crossing times.
    %
    %   This is a method for the DATABRAID class.
    %   See also BRAID.COMPACT.
      c = b;

      function [cc,shorter] = canceladj(cc)
        shorter = false;

        i1 = 1:2:length(cc.word)-1;
        ic = find(cc.word(i1) == -cc.word(i1+1));
        if ~isempty(ic), shorter = true; end
        cc.word(i1(ic)) = 0; cc.word(i1(ic)+1) = 0;

        i2 = 2:2:length(cc.word)-1;
        ic = find(cc.word(i2) == -cc.word(i2+1));
        if ~isempty(ic), shorter = true; end
        cc.word(i2(ic)) = 0; cc.word(i2(ic)+1) = 0;

        i0 = find(cc.word ~= 0);
        cc.word = cc.word(i0);
        cc.tcross = cc.tcross(i0);
      end

      % Keep cancelling until nothing changes.
      shorter = true;
      while shorter
        [c,shorter] = canceladj(c);
      end
    end

    function bt = trunc(b,interval)
    %TRUNC   Truncate databraid by choosing crossings from a time subinterval.
    %   BT = TRUNC(B,INTERVAL) Truncates the braid generators to those
    %   whose crossing times TCROSS lie in the interval
    %   INTERVAL(1) <= TCROSS <= INTERVAL(2).
    %   If INTERVAL is a single number, then selected crossings will have
    %   TCROSS <= INTERVAL.
    %
    %   This is a method for the DATABRAID class.

      bt = b;
      if nargin < 2 || ~isnumeric(interval)
        error('BRAIDLAB:databraid:trunc:badarg','Not enough input arguments.')
      end

      if isempty(interval) || numel(interval) < 1 || numel(interval) > 2
        error('BRAIDLAB:databraid:trunc:badarg',...
              'Interval has to be a non-empty 1 or 2 element vector.')
      end

      % select the desired crossing times
      if numel(interval) == 1
        sel = bt.tcross <= interval;
      else
        sel = bt.tcross >= interval(1) & bt.tcross <= interval(2);
      end

      bt.tcross = bt.tcross(sel);
      bt.word = bt.word(sel);
    end

    function E = ftbe(B,varargin)
    %FTBE   Finite Time Braiding Exponent of a databraid.
    %   E = FTBE(B) computes the Finite Time Braiding Exponent of a
    %   databraid B.  The FTBE is defined for data braids without relying on
    %   iteration of the braid on a given loop. Intuitively, its relation to
    %   braid entropy is analogous to that of Finite Time Lyapunov Exponents
    %   to entropy in a periodic flow.
    %
    %   The Finite Time Braiding Exponent is computed as
    %
    %      E = (1/T) * log(|B.l|/|l|)
    %
    %   where l is a generating set for the fundamental group, B.l denotes
    %   action of the braid on l, log is the natural logarithm, and T is the
    %   difference between crossing times of the first generator and the
    %   last generator in B.
    %
    %   E = FTBE(B,'Parameter',VALUE,...) is the same as above except it
    %   allows modification of the basic formula by specifying name-value
    %   pairs as follows.
    %
    %   * Method - [ {'proj'} | 'nonproj' ] - The algorithm for computing
    %     the length of the loop after action of the braid.
    %
    %     'proj' uses projectivized coordinates which makes it more suitable
    %     for very large braids, at the possible (small) expense in
    %     numerical accuracy.  (See braid.entropy for details.)
    %
    %     'nonproj' uses non-projectivized coordinates which may make it
    %     slow or unusable for very long braids, but its numerical precision
    %     should be dictated only by precision of evaluation of natural
    %     logarithm.  (See braid.complexity for details.)
    %
    %   * Length - The loop length function [ {'intaxis'} | 'minlength' |
    %     'l2norm' ]  See documentation of loop.intaxis, loop.minlength,
    %     loop.l2norm for details.
    %
    %   * T - [ real ] - Uses a custom value for length of interval over
    %     which FTBE is computed.  The default is the difference between
    %     first and last crossing time in the braid which might
    %     underestimate the time if the first generator appeared late, or if
    %     the last crossing did not appear at the end of the physical braid.
    %
    %   * Base - [ positive real ] - Use a custom base of
    %     logarithm instead of natural logarithm.
    %
    %   This is a method for the DATABRAID class
    %   See also BRAID.COMPLEXITY and BRAID.ENTROPY

    % flag validation
      import braidlab.util.validateflag

      parser = inputParser;

      parser.addRequired('B', @(x)isa(x,'braidlab.databraid') );

      parser.addParameter('method', 'proj', @ischar );
      parser.addParameter('T', nan, @(n)isnumeric(n) );
      parser.addParameter('base', nan, @(n)( isnumeric(n) && (n > ...
                                                        0) ) );
      parser.addParameter('length','intaxis',@ischar);

      parser.parse( B, varargin{:} );

      params = parser.Results;

      % determine type of algorithm
      params.method = validateflag(params.method, {'proj','entropy'}, ...
                                   {'nonproj', 'complexity'});

      % determine loop length function used
      params.length = validateflag(params.length, 'intaxis', ...
                                   'minlength','l2norm');

      % determine length of interval
      if isnan(params.T)
        params.T = max(B.tcross) - min(B.tcross);
      end

      % pick computation method
      switch params.method
        case 'proj', % projectivized uses entropy
          stretch = entropy(braid(B),'onestep','length',params.length);
        case 'nonproj', % non-projectivized uses complexity
          stretch = complexity(braid(B),'length',params.length);
      end

      % change base if needed
      if ~isnan(params.base)
        stretch = stretch/reallog( params.base );
      end

      % compute FTBE by dividing stretch by physical time length
      E = stretch / params.T;

    end

  end % methods block


  methods (Access = private)
    function check_tcross(br)

      % Must have as many times as the word length.
      if length(br.word) ~= length(br.tcross)
        error('BRAIDLAB:databraid:check_tcross:badtimes', ...
              'Must have as many crossing times as generators.')
      end

      % Cannot have decreasing times.
      dt = diff(br.tcross);
      if any(dt < 0)
        error('BRAIDLAB:databraid:check_tcross:badtimes', ...
              'Crossing times must be nondecreasing.')
      end

      % Check: if there are simultaneous crossings, they must
      % correspond to different generators.
      isim = find(~dt);
      if any(abs(br.word(isim+1) - br.word(isim)) <= 1)
        error('BRAIDLAB:databraid:check_tcross:badtimes', ...
              ['Cannot have simultaneous crossing times for noncommuting' ...
               ' generators.'])
      end
    end
  end % methods block


  % Some operations are not appropriate for databraids, since they break
  % chronology.  Hide these, though they can still be called and will
  % return an error message.
  methods (Hidden)
    function mpower(~,~)
      error('BRAIDLAB:databraid:mpower:undefined',...
            'This operation is not defined for databraids.')
    end

    function inv(~)
      error('BRAIDLAB:databraid:inv:undefined',...
            'This operation is not defined for databraids.')
    end

    function entropy(~)
      error('BRAIDLAB:databraid:entropy:undefined',...
            ['This operation is not defined for databraids.  ' ...
             'Use databraid.ftbe instead.'])
    end

    function complexity(~)
      error('BRAIDLAB:databraid:complexity:undefined',...
            ['This operation is not defined for databraids.  ' ...
             'Use databraid.ftbe instead.'])
    end
  end % methods block

end % databraid classdef