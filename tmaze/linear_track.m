function code = tmaze
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;

% INIT
function vr = initializationCodeFun(vr)
    
    % import gui variables
    vr.startPosition = [0, eval(vr.exper.variables.startPositionY), eval(vr.exper.variables.startPositionZ), 0];
    vr.trackLength = eval(vr.exper.variables.trackLength);
    vr.resetPerc = 0.9;
    vr.runStart = now;

% RUNTIME
function vr = runtimeCodeFun(vr)
    
    ypos = vr.position(2);
    xpos = vr.position(1);

    % determine position
    if (ypos > vr.trackLength*vr.resetPerc)
        % give reward here
        vr.worlds{vr.currentWorld}.surface.visible(:) = false; % make whole world black
        vr = goToStart(vr);
        vr.worlds{vr.currentWorld}.surface.visible(:) = true; % make whole world visible
    end

    vr.text(1).string = ['TIME ' datestr(now-vr.runStart,'MM.SS')];

% END
function vr = terminationCodeFun(vr)
    
% OTHER
function vr = goToStart(vr)
    for i = 1:length(vr.position)
        vr.position(i) = vr.startPosition(i);
    end
