function Sr=RotY(S,theta);
%RotY - Rotate around the Y axis.
%
%Arguments:
%  S     - 3-D position vector to be rotated.
%          [X;Y;Z] - row vector.
%  theta - Rotation angle (deg).
%
%Returns:
%  Sr    - Rotated position vector.
theta=theta*pi/180;
R=[cos(theta), 0, -sin(theta);
   0         , 1, 0;
   sin(theta), 0, cos(theta)];
Sr=zeros(size(S));
for i=1:size(S,1)
    Sr(i,:)=(R*S(i,:)')';
end
end