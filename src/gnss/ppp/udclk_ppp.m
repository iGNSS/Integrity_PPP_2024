function rtk=udclk_ppp(rtk)

global glc OptionClock


%VAR_CLK=10^2; 
opt=rtk.opt;
VAR_CLK=opt.std(4)^2;
CLIGHT=glc.CLIGHT; tt=abs(rtk.tt);

navsys=opt.navsys; mask=rtk.mask; prn=opt.prn(7);
if OptionClock
rtk.sol.dtr([1,3])=0;
end
% for single-system except GPS
if ~any(diag(rtk.P(rtk.ic+1:rtk.ic+5,rtk.ic+1:rtk.ic+5)))
if strcmp(navsys,'G')
    dtr=rtk.sol.dtr(1);
    if abs(dtr)<=1e-16,dtr=1e-16;end
    rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+1);
    return
end
if strcmp(navsys,'R')
    dtr=rtk.sol.dtr(2);
    if abs(dtr)<=1e-16,dtr=1e-16;end
    rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+2);
    
    % for GLONASS icb
    if opt.gloicb==glc.GLOICB_LNF
        if rtk.x(rtk.iicb+1)==0
            rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+1);
        end
    elseif opt.gloicb==glc.GLOICB_QUAD
        if rtk.x(rtk.iicb+1)==0
            rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+1);
        end
        if rtk.x(rtk.iicb+2)==0
            rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+2);
        end
    end
    return
elseif strcmp(navsys,'E')
    dtr=rtk.sol.dtr(3);
    if abs(dtr)<=1e-16,dtr=1e-16;end
    rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+3);
    return
elseif strcmp(navsys,'C')
    dtr=rtk.sol.dtr(4);
    if abs(dtr)<=1e-16,dtr=1e-16;end
    rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+4);
    return
elseif strcmp(navsys,'J')
    dtr=rtk.sol.dtr(5);
    if abs(dtr)<=1e-16,dtr=1e-16;end
    rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+5);
    return
end
end

% for GPS or multi-system
if ~opt.Galileo_REF
dtr=CLIGHT*rtk.sol.dtr(1);
rtk.x(rtk.ic+1)=dtr;
%dtr=rtk.x(rtk.ic+1);
if abs(dtr)<=1e-16,dtr=1e-16;end
%rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+1);
rtk.P(rtk.ic+1,rtk.ic+1)=rtk.P(rtk.ic+1,rtk.ic+1)+prn^2*tt;

vect=2:glc.NSYS;
else
dtr=CLIGHT*rtk.sol.dtr(3);
rtk.x(rtk.ic+3)=dtr;

%dtr=rtk.x(rtk.ic+3);
if abs(dtr)<=1e-16,dtr=1e-16;end
%rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+3);
rtk.P(rtk.ic+3,rtk.ic+3)=rtk.P(rtk.ic+3,rtk.ic+3)+prn^2*tt;
vect=[1,2,4,5];
end

%rtk.x(rtk.ic+1)=CLIGHT*dtr+rtk.sol.dtrd;

for i=vect
    if mask(i)==0,continue;end
    if i==glc.SYS_GLO
        dtr=rtk.sol.dtr(2);
        if rtk.x(rtk.ic+2)==0
            if abs(dtr)<=1e-16,dtr=1e-16;end
            rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+2);
        else
            rtk.P(rtk.ic+i,rtk.ic+i)=rtk.P(rtk.ic+i,rtk.ic+i)+prn^2*tt;
        end
        % for GLONASS icb
        if opt.gloicb==glc.GLOICB_LNF
            if rtk.x(rtk.iicb+1)==0
                rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+1);
            end
        elseif opt.gloicb==glc.GLOICB_QUAD
            if rtk.x(rtk.iicb+1)==0
                rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+1);
            end
            if rtk.x(rtk.iicb+2)==0
                rtk=initx(rtk,0.1,VAR_CLK,rtk.iicb+2);
            end
        end
    else
        dtr=CLIGHT*rtk.sol.dtr(i);
        %dtr=rtk.x(rtk.ic+i);
        rtk.x(rtk.ic+i)=dtr;

        if rtk.x(rtk.ic+i)==0
            if abs(dtr)<=1e-16,dtr=1e-16;end
            rtk=initx(rtk,CLIGHT*dtr,VAR_CLK,rtk.ic+i);
        else
            rtk.P(rtk.ic+i,rtk.ic+i)=rtk.P(rtk.ic+i,rtk.ic+i)+prn^2*tt;
        end
    end 
end

return

