% Layout:

% Create a figure to house the GUI
figure

%create an annotation object:

ellipse_position = [0.4 0.6 0.1 0.2];
ellipse_h = annotation('ellipse',ellipse_position,...
                 'facecolor',[1 0 1]);
             
% create an editable toonlbox object
edit_box_h = uicontrol('style','edit',...
                        'units','normalized',...
                        'position',[0.3 0.4 0.4 0.1]);
                    
%create a "push button" user interface (UI) onject                    