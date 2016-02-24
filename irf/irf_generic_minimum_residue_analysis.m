function [L,V,U]=irf_generic_minimum_residue_analysis(varargin)
% IRF_GENERIC_MINIMUM_RESIDUE_ANALYSIS implements different GMRA methods: MVAB, MFR,...
%
%  IRF_GENERIC_MINIMUM_RESIDUE_ANALYSIS is based on Sonnerup et al. 2006 JGR
%
%	 [L,V,U]=IRF_GENERIC_MINIMUM_RESIDUE_ANALYSIS('Q',Q) calculates
%	 eigenvalues L, eigenvectors V and velocity vector U.
%
%	 [L,V,U]=IRF_GENERIC_MINIMUM_RESIDUE_ANALYSIS('eta',eta,'q','q') calculates
%	 L, V and U given the density of conserved quantity eta and transport
%	 tensor q.
%
%  Inputs:
%       Q - [3,3] matrix
%     eta - [M,3] density of conserved quantity, M is number of points
%       q - [M,3,3] transport tensor
%  Output
%       L - [lmin,lmean,lmax] eigenvalues
%       V - V(:,1) eigenvector corresponding to lmin, V(:,2) - lmean, V(:,3) - lmax

%% Defaults
doCalculateVelocity = true;
doCalculateQ        = true;
%% Input check
if nargin == 0 && nargout == 0,
	help irf_generic_minimum_residue_analysis;
	return;
elseif nargin == 1 && isstruct(varargin{1}),
	InputParameters = varargin{1};
	inputParameterFields = fieldnames(InputParameters);
	for j=1:numel(inputParameterFields)
		fieldname = inputParameterFields{j};
		eval([fieldname ' = InputParameters.' fieldname ';']);
	end
elseif nargin > 1
	args = varargin;
	while numel(args)>=2
		switch args{1}
			case {'Q'}
				Q = args{2};
				doCalculateVelocity = false;
				doCalculateQ = false;
			case {'eta'}
				eta = args{2};
			case {'q'}
				q = args{2};
			otherwise
				irf.log('critical','unrecognized input');
				return;
		end
		args(1:2)=[];
	end
end
%% Check inputs
if numel(eta) == 1, % scalar
	eta = repmat(eta,size(q,1),1);
end
%% Calculate Q from eta and q
if doCalculateQ
	% U estimate
	% U = <deta dq>/<|deta|^2>
	deta = bsxfun(@minus,eta,irf.nanmean(eta,1)); % Eq. 10
	dq   = bsxfun(@minus,q,irf.nanmean(q,1));
	detadqAver = irf.nanmean(matrix_dot(deta,1,dq,1),1);
	deta2Aver  = irf.nanmean(dot(deta,deta,2),1);
	U = detadqAver/deta2Aver; % Eq. 12
	
	% Q estimate
	dqdqAver = shiftdim(irf.nanmean(matrix_dot(dq,1,dq,1),1),1);
	detadqAver2Matrix = detadqAver' *detadqAver;
	if eta==0,
		Q = dqdqAver; % Eq. 19
	else
		Q = (dqdqAver - detadqAver2Matrix) / deta2Aver; % Eq. 15b
	end
end


%% Calculate eigenvalues and eigenvectors from Q

[V,lArray]=eig(Q); % L is diagonal matrix of eigenvalues and V matrix with columns eigenvectors
L=[lArray(1,1) lArray(2,2) lArray(3,3)];

if ~doCalculateVelocity
	U = NaN;
	return;
end

%% Calculate velocity

X3 = V(1,:)';
un = dot(U,X3);

%% Print output
if nargout == 0
	disp(['Eigenvalues: ' sprintf('%5.2f ',L)]);
	disp(vector_disp('N',V(:,1)));
	disp(vector_disp('M',V(:,2)));
	disp(vector_disp('L',V(:,3)));
	disp(vector_disp('U',U,'km/s'));
end

%% Define output
if nargout == 0,
	clear L V U;
end

%% Functions
function out = vector_disp(vectSymbol,vect,vectUnit)
if nargin==2, vectUnit ='';end
	out = sprintf(['|' vectSymbol '| = %6.2f ' vectUnit ...
		', ' vectSymbol ' = [ %5.2f %5.2f %5.2f ] ' vectUnit],...
		norm(vect),vect(1),vect(2),vect(3));
	
function out = matrix_dot(inp1,ind1,inp2,ind2)
% MATRIX_DOT summation over one index multiplication
%
% MATRIX_DOT(inp1,ind1,inp2,ind2)
% inp1,inp2 are the matrixes and summation is over dimensions (ind1+1) and
% (ind2+1). +1 because first dimension is always time.
szinp1 = size(inp1);ndimsInp1 = ndims(inp1)-1;
szinp2 = size(inp2);ndimsInp2 = ndims(inp2)-1;
szout1 = szinp1; szout1(ind1+1)=[];
szout2 = szinp2; szout2([1 ind2+1])=[];
szout = [szout1 szout2];
out = zeros(szout);
if ndimsInp1 == 1
	if ndimsInp2 == 1
		out = sum(inp1.*inp2,2);
	elseif ndimsInp2 == 2 && ind2 == 1
		for jj = 1:szinp2(2)
			for kk = 1:szinp1(2)
				out(:,jj) = out(:,jj) + inp1(:,kk).*inp2(:,kk,jj);
			end
		end
	elseif ndimsInp2 == 2 && ind2 == 2
		for jj = 1:szinp2(2)
			for kk = 1:szinp1(2)
				out(:,jj) = out(:,jj) + inp1(:,kk).*inp2(:,jj,kk);
			end
		end
	else
		error; % not implemented
	end
elseif ndimsInp1 == 2 && ndimsInp2 == 1 && ind1 == 1
	for jj = 1:szinp1(2)
		for kk = 1:szinp2(2)
			out(:,jj) = out(:,jj) + inp1(:,kk,jj).*inp2(:,kk);
		end
	end
elseif ndimsInp1 == 2 && ndimsInp2 == 1 && ind1 == 2
	for jj = 1:szinp1(2)
		for kk = 1:szinp2(2)
			out(:,jj) = out(:,jj) + inp1(:,jj,kk).*inp2(:,kk);
		end
	end
elseif ndimsInp1 == 2 && ndimsInp2 == 2 && ind1 == 1 && ind2 == 1
	for jj = 1:szinp1(3)
		for kk = 1:szinp2(3)
			for ss = 1:szinp1(ind1+1)
				out(:,jj,kk) = out(:,jj,kk) + inp1(:,ss,jj).*inp2(:,ss,kk);
			end
		end
	end
else
	error; % not implemented
end