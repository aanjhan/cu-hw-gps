function iq_plot(data)
    figure('Name','I/Q Accumulation Plot','Numbertitle','off');
    hold on;
    for i=1:size(data,1)
        plot(data(i,1),data(i,2),'x',...
            'color',[i / size(data,1) 0 1-(i / size(data,1))],...
            'linewidth',1.5);
    end
    hold off;
    title({'I/Q Accumulation Plot';'Varies from blue to red with increasing t.'});
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    
    xmax=max(abs(data(:,1)));
    ymax=max(abs(data(:,2)));
    axis_limit=max(xmax,ymax);
    
    axis([-axis_limit axis_limit -axis_limit axis_limit]);
    
    return;