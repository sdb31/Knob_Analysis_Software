function MotoTrak_Supination_Viewer_SB

[files, path] = uigetfile('*.ArdyMotor','Select MotoTrak Files',...
    'multiselect','on');                                                    %Have the user pick an input *.ArdyMotor file or files.
if ~iscell(files) && files(1) == 0                                          %If no file was selected...
    return                                                                  %Exit the function.
end
cd(path);                                                                   %Change the current directory to the specified folder.
if ischar(files)                                                            %If only one file was selected...
    files = {files};                                                        %Convert the string to a cell array.
end

for f = 1:length(files)                                                     %Step through each file.
    handles = ArdyMotorFileRead(files{f});                                  %Read in the data from the *.ArdyMotor file.
    if ~isfield(handles,'trial') || isempty(handles.trial)                  %If there's no trials in this data file...
        warning('ARDYMOTOR2TEXT:NoTrials',['WARNING FROM '...
            'ARDYMOTOR2TEXT: The file "' files{f} '" has zero trials '...
            'and will be skipped.']);                                       %Show a warning.
        continue                                                            %Skip to the next file.
    end
    handles.file = files{f};                                                %Save the filename.
    handles.ir_thresh = [1023, 0];                                          %Create a matrix to hold the IR signal bounds.
    for t = 1:length(handles.trial)                                         %Step through each trial.
        handles.ir_thresh(1) = ...
            min([handles.trial(t).ir; handles.ir_thresh(1)]);               %Find the new minimum for each trial.
        handles.ir_thresh(2) = ...
            max([handles.trial(t).ir; handles.ir_thresh(2)]);               %Find the new maximum for each trial.
        s = median(double(diff(handles.trial(t).sample_times)));            %Find the median inter-sample interval for each trial.
        if s == 0                                                           %If all the inter-sample intervals are the same...
            handles.trial(t).sample_times = ...
                (10*(1:length(handles.trial(t).signal)) - 1010)';           %Use the sample times from a different trial in place of the bad times on the curren trial.
        end
    end
    handles.cur_trial = 1;                                                  %Set the current trial to 1.
    handles.num_trials = length(handles.trial);                             %Grab the number of trials.
    handles = Make_GUI(handles);                                            %Create the GUI.
    ShowTrial(handles,handles.cur_trial);                                   %Show the first trial.
    set(handles.slider,'callback',@SliderClick);                            %Set the callback for action on the slider.
    set(handles.savebutton,'callback',@SavePlot);                           %Set the callback for the save plot pushbutton.
    guidata(handles.fig,handles);                                           %Pin the handles structure to the GUI.
end


%% This function displays the force and IR traces from the selected trial.
function ShowTrial(handles,t)
pos = get(handles.fig,'position');                                          %Grab the main figure position.
area(handles.trial(t).sample_times,handles.trial(t).ir,...
    'linewidth',2,'facecolor',[1 0.5 0.5],'parent',handles.ir_axes,...
    'basevalue',handles.ir_thresh(2));                                      %Show the IR signal as an area plot.
set(handles.ir_axes,'ylim',handles.ir_thresh,'ydir','reverse',...
    'xlim',handles.trial(t).sample_times([1,end]),'xticklabel',[],...
    'ytick',[]);                                                            %Set the IR axes properties.
ylabel('IR Signal','parent',handles.ir_axes,'fontsize',0.75*pos(4),...
    'rotation',0,'verticalalignment','middle',...
    'horizontalalignment','right');                                         %Label the IR signal.
set(handles.label,'string',['Subject: ' handles.rat ', Trial ' ...
    num2str(t) '/' num2str(handles.num_trials) ', ' ...
    datestr(handles.trial(t).starttime,'HH:MM:SS, mm/dd/yy')],...
    'fontsize',0.75*pos(4));                                                %Update the trial label.
area(handles.trial(t).sample_times,handles.trial(t).signal,...
    'linewidth',2,'facecolor',[0.5 0.5 1],'parent',handles.force_axes);     %Show the force signal as an area plot.

% [pks, sig] = Knob_Peak_Finder(handles.trial(t).signal);                     %find peaks
% set(sig, pks, '*r', 'parent', handles.force_axes);

min_max = [min(handles.trial(t).signal), max(handles.trial(t).signal)];     %Grab the minimum and maximum of the signal.
set(handles.force_axes,'xlim',handles.trial(t).sample_times([1,end]),...
    'ylim',min_max + [-0.05,0.1]*range(min_max),'fontsize',0.5*pos(4));     %Set the force axes properties.
line([0,0],min_max(2)+[0.02,0.08]*range(min_max),'color','k',...
    'parent',handles.force_axes,'linewidth',2);                             %Draw a line to show the start of the hit window.
line(1000*[1,1]*handles.trial(t).hitwin,...
    min_max(2)+[0.02,0.08]*range(min_max),'color','k',...
    'parent',handles.force_axes,'linewidth',2);                             %Draw a line to show the end of the hit window.
line([0,1000*handles.trial(t).hitwin],...
    min_max(2)+0.05*range(min_max)*[1,1],'color','k',...
    'parent',handles.force_axes,'linestyle','--','linewidth',2);            %Draw a line to show the length of the hit window.
text(500*handles.trial(t).hitwin,min_max(2)+0.05*range(min_max),...
    'Hit Window','margin',2,'edgecolor','w','backgroundcolor','w',...
    'fontsize',0.5*pos(4),'fontweight','bold',...
    'parent',handles.force_axes,'horizontalalignment','center',...
    'verticalalignment','middle');                                          %Label the hit window.
a = line([0,0],get(handles.force_axes,'ylim'),'color',[0.5 0.5 0.5],...
    'parent',handles.force_axes,'linewidth',2,'linestyle','--');            %Draw a gray dotted line to show the start of the hit window.
uistack(a,'bottom');                                                        %Move the dotted line to the bottom of the stack.
a = line(1000*[1,1]*handles.trial(t).hitwin,...
    get(handles.force_axes,'ylim'),'color',[0.5 0.5 0.5],...
    'parent',handles.force_axes,'linewidth',2,'linestyle','--');            %Draw a gray dotted line to show the end of the hit window.
uistack(a,'bottom');                                                        %Move the dotted line to the bottom of the stack.
if max(get(handles.force_axes,'ylim')) > handles.trial(t).init              %If the y-axis scale is large enough to show the initiation threshold...
    line([-100,max(get(handles.force_axes,'xlim'))],...
        handles.trial(t).init*[1,1],'color',[0 0.5 0],...
        'parent',handles.force_axes,'linewidth',2,'linestyle','--');        %Draw a line showing the initiation threshold.
    text(-100,handles.trial(t).init,'Initiation ','color',[0 0.5 0],...
        'fontsize',0.5*pos(4),'fontweight','bold',...
        'parent',handles.force_axes,'horizontalalignment','right',...
        'verticalalignment','middle');                                      %Label the initiation threshold.
end
if max(get(handles.force_axes,'ylim')) > handles.trial(t).thresh            %If the y-axis scale is large enough to show the hit threshold...
    line([-100,max(get(handles.force_axes,'xlim'))],...
        handles.trial(t).thresh*[1,1],'color',[0.5 0 0],...
        'parent',handles.force_axes,'linewidth',2,'linestyle','--');        %Draw a line showing the hit threshold.
    text(-100,handles.trial(t).thresh,'Hit Threshold ',...
        'color',[0.5 0 0],'fontsize',0.5*pos(4),'fontweight','bold',...
        'parent',handles.force_axes,'horizontalalignment','right',...
        'verticalalignment','middle');                                      %Label the hit threshold.
end
ylabel('Angle (degrees)','parent',handles.force_axes,'fontsize',0.75*pos(4));%Label the force signal.
xlabel('Time (ms)','parent',handles.force_axes,'fontsize',0.75*pos(4));     %Label the time axis.


%% This function executes when the user interacts with the slider.
function SliderClick(hObject,~)
handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
handles.cur_trial = round(get(hObject,'value'));                            %Set the current trial to the value of the slider.
if handles.cur_trial < 1                                                    %If the current trial is less than 1...
    handles.cur_trial = 1;                                                  %Set the current trial to 1.
elseif handles.cur_trial > handles.num_trials                               %Otherwise, if the current trials is greater than the total number of trials.
    handles.cur_trial = handles.num_trials;                                 %Set the current trial to the last trial.
end
set(hObject,'value',handles.cur_trial);                                     %Update the value of the slider.
ShowTrial(handles,handles.cur_trial);                                       %Show the current trial.
guidata(hObject,handles);                                                   %Pin the handles structure back to the GUI.


%% This function executes when the user interacts with the slider.
function SavePlot(hObject,~)
handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
filename = [handles.file(1:end-10) '_TRIAL' ...
    num2str(handles.cur_trial,'%03.0f') '.png'];                            %Create a default filename for the PNG file.
[filename, path] = uiputfile('*.png','Name Image File',filename);           %Ask the user for a new filename.
if filename(1) == 0                                                         %If the user selected cancel...
    return                                                                  %Exit the function.
end
set([handles.slider,handles.savebutton],'visible','off','enable','off');    %Make the uicontrols invisible and disable them.
% fix_dotted_line_export(handles.force_axes);                                 %Fix the dotted lines in the force axes.
pos = get(handles.fig,'position');                                          %Grab the figure position.
temp = get(handles.fig,'color');                                            %Grab the starting color of the figure.
set(handles.fig,'paperpositionmode','auto',...
    'inverthardcopy','off',...
    'paperunits',get(handles.fig,'units'),...
    'papersize',pos(3:4),...
    'color','w');                                                           %Set the figure properties for printing.
set(handles.label,'backgroundcolor','w');                                   %Set the label background color to white.
drawnow;                                                                    %Immediately update the figure.
print(gcf,[path, filename],'-dpng','-r300');                                %Save the current image as a PNG file.
set([handles.slider,handles.savebutton],'visible','on','enable','on');      %Make the uicontrols visible and enabled again.
set(handles.fig,'color',temp);                                              %Reset the figure color to the original color.
set(handles.label,'backgroundcolor',temp);                                  %Set the label background color to the original color.


%% This subfunction creates the GUI.
function handles = Make_GUI(handles)
set(0,'units','centimeters');                                               %Set the system units to centimeters.
pos = get(0,'screensize');                                                  %Grab the screen size.
h = 0.8*pos(4);                                                             %Calculate the height of the figure.
w = 4*h/3;                                                                  %Scale the width of the figure to the height.
handles.fig = figure('MenuBar','none',...
    'numbertitle','off',...
    'name',['Pull Viewer: ' handles.file],...
    'units','centimeters',...
    'resize','on',...
    'Position',[pos(3)/2-w/2, pos(4)/2-h/2, w, h]);                         %Create a figure.
handles.label =  uicontrol(handles.fig,'style','text',...
    'units','normalized',...
    'position',[0.01,0.95,0.98,0.04],...
    'string',[],...
    'fontsize',0.5*h,...
    'backgroundcolor',get(handles.fig,'color'),...
    'horizontalalignment','left',...
    'fontweight','bold');                                                   %Create a text label for showing the trial number and time.
handles.ir_axes = axes('units','normalized',...
    'position',[0.1,0.85,0.89,0.09],...
    'box','on',...
    'linewidth',2);                                                         %Create axes for showing the IR signal.
handles.force_axes = axes('units','normalized',...
    'position',[0.1,0.12,0.89,0.72],...
    'box','on',...
    'linewidth',2);                                                         %Create axes for showing the IR signal.
handles.slider = uicontrol(handles.fig,'style','slider',...
    'units','normalized',...
    'position',[0.01,0.01,0.78,0.04],...
    'value',1,...
    'min',1,...
    'max',handles.num_trials,...
    'SliderStep',[1/handles.num_trials, 0.1]);                              %Create a trial slider.
handles.savebutton = uicontrol(handles.fig,'style','pushbutton',...
    'units','normalized',...
    'position',[0.80,0.01,0.19,0.04],...
    'string','Save Plot (PNG)',...
    'fontsize',0.75*h);                                                     %Create a button for saving a plot image.


%% This function is called whenever the main figure is resized.
function Resize(hObject,~)
handles = guidata(hObject);                                                 %Grab the handles structure from the GUI.
pos = get(handles.fig,'position');                                          %Grab the main figure position.
ylabel('IR Signal','parent',handles.ir_axes,'fontsize',0.75*pos(4),...
    'rotation',0,'verticalalignment','middle',...
    'horizontalalignment','right');                                         %Label the IR signal with the new fontsize.
set([handles.label,handles.savebutton],'fontsize',0.75*pos(4));             %Update the trial label and savebutton fontsize.
objs = get(handles.force_axes,'children');                                  %Grab all children of the force axes.
objs(~strcmpi('text',get(objs,'type'))) = [];                               %Kick out all non-text objects.
set(objs,'fontsize',0.5*pos(4));                                            %Update the fontsize of all text objects.
ylabel('Angle (degrees)','parent',handles.force_axes,'fontsize',0.75*pos(4));     %Label the force signal.
xlabel('Time (ms)','parent',handles.force_axes,'fontsize',0.75*pos(4));     %Label the time axis.

%% This function finds peaks in the signal, accounting for equality of contiguous samples.
function [pks, sig] = Knob_Peak_Finder(signal)
    %This code finds and kicks out peaks that have a std dev between 
    %them less than 1
    
    smoothed_signal = boxsmooth(signal);                                        %smooth out the trial signal
    [pks, sig] = findpeaks(smoothed_signal, 'MINPEAKHEIGHT', 5, ...
        'MINPEAKDISTANCE', 10);                                            %Find local maximma
    n = length(pks);
    j = 1;
    if n>1
        while j <= n-1
            if (abs(pks(j)-pks(j+1)) <= 5)                                 % if the diff between 2 peaks is less than or equal to 5
                start_sig = sig(j);
                end_sig = sig(j+1);

                signal_interest = smoothed_signal(start_sig:end_sig);
                deviation_signal = std(signal_interest);

                if deviation_signal < 1
                    pks(j+1) = [];
                    sig(j+1) = [];
                    j = j-1;
                end

            end
            n = length(pks);
            j = j+1;
        end
    end