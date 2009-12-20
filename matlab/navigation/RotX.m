function Sr=RotX(S,theta);
%RotX - Rotate around the X axis.
%
%Arguments:
%  S     - 3-D position vector to be rotated.
%          [X Y Z] - row vector.
%  theta - Rotation angle (deg).
%
%Returns:
%  Sr    - Rotated position vector.
theta=theta*pi/180;
R=[1, 0          , 0;
   0, cos(theta) , sin(theta);
   0, -sin(theta), cos(theta)];
Sr=zeros(size(S));
for i=1:size(S,1)
    Sr(i,:)=(R*S(i,:)')';
end
end