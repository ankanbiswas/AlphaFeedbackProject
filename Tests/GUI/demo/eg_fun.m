%eg_fun code ---------------------------------------------------
%copy paste this code into a file called eg_fun.m
function eg_fun(object_handle, event)
    disp('hi')
end


% function eg_fun(object_handle, event, edit_handle, ellipse_handle)
%     str_entered = get(edit_handle, 'string');
%      
%     if strcmp(str_entered, 'red')
%         col_val = [1 0 0];
%     elseif strcmp(str_entered, 'green')
%         col_val = [0 1 0];
%     elseif strcmp(str_entered, 'blue')
%          col_val = [0 0 1];
%     else
%         col_val = [0 0  0];
%     end
%     set(ellipse_handle, 'facecolor', col_val);
% end