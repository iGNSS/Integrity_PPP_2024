function [v,H,R,azel,exc,stat,rtk,PRN_comp,v_tot,...
    v_tot_2,v_tot_3,v_tot_4,v_tot_5,v_tot_6]=ppp_res(post,x,rtk,obs,nav,sv,dr,exc)

global glc tr_new qq gls OptionSatnav OptionClock Cumdtr

if isempty(tr_new)
    tr_new=NaN(1,glc.Prealloc);
    qq=1;
end


stat=1; opt=rtk.opt; MAXSAT=glc.MAXSAT; VAR_GLO_IFB=0.6^2;%#ok
nobs=size(obs,1); nf=rtk.NF;
v=zeros(2*nobs*nf,1); H=zeros(2*nobs*nf,rtk.nx); var=zeros(2*nobs*nf,1);
azel=zeros(nobs,2); dants=zeros(3,1); dgrav=0;
obsi=zeros(64,1); frqi=zeros(64,1); ve=zeros(64,1);
v_tot=v;
v_new=v;
v_new_2=v;
v_new_3=v;
v_new_4=v;
v_new_5=v;


v_tot_2=v;
v_tot_3=v;
v_tot_4=v;
v_tot_5=v;
v_tot_6=v;


for i=1:glc.MAXSAT
    for j=1:opt.nf
        rtk.sat(i).vsat(j)=0;
    end
end

% earth tide correction
rr=x(1:3)+dr;
pos=ecef2pos(rr);

nv=1;ne=0;
PRN_comp=zeros(2*nobs*nf,1);
for i=1:nobs

    LEOFlag=0;

    sat=obs(i).sat; lam=nav.lam(sat,:);lam_=[nav.lam(sat,:),nav.lam(sat+1,:)];
    if lam_(fix(j/2)+1)==0||lam(1)==0,continue;end

    % satellite information
    rs=sv(i).pos; dts=sv(i).dts; var_rs=sv(i).vars; vs=sv(i).vel; svh=sv(i).svh;

    % distance/light of sight/azimuth/elevation
    [r,LOS]=geodist(rs,rr); azel(i,:)=satazel(pos,LOS);


    if r<=0||azel(i,2)<opt.elmin,continue;end

    [sys,~]=satsys(sat);
    if sys==0||rtk.sat(sat).vs==0||satexclude(sat,var_rs,svh,opt)==0||exc(i)==1
        exc(i)=1; continue;
    end

    dtdx=0;dtrop=0;vart=0;stat_t=1;    % tropospheric and ionospheric model
    diono=0;vari=0;stat_i=1;
    if opt.tropopt~=0
        [dtdx,dtrop,vart,stat_t]=model_trop(obs(i).time,pos,azel(i,:),rtk,x,nav);
    end
    if opt.ionoopt~=0
        if any(obs(i).sat==glc.ID_LEO) && opt.LEO_IONO_MODEL==1
            rtk_2=rtk;
            rtk_2.opt.ionoopt=glc.IONOOPT_BRDC;
            [diono,vari,stat_i]    =model_iono(obs(i).time,pos,azel(i,:),rtk_2,x,nav,sat);

        else
            [diono,vari,stat_i]    =model_iono(obs(i).time,pos,azel(i,:),rtk,x,nav,sat);
        end
    end
    if stat_t==0||stat_i==0,continue;end

    % satellite and receiver antenna model
    if opt.posopt(1)==1
        dants=satantpcv(rs,rr,nav.pcvs(sat));
    end
    dantr=antmodel(sat,opt.pcvr,opt.antdel(1,:),azel(i,:),opt.posopt(2));

    % phase windup model
    [rtk.sat(sat).phw,stat_tmp]=model_phw(rtk.sol.time,sat,nav.pcvs(sat).type,opt.posopt(3),rs,rr,vs,rtk.sat(sat).phw);
    if opt.posopt(3)
    if stat_tmp==0,continue;end
    end

    % gravitational delay correction
    if opt.posopt(7)==1
        dgrav=model_grav(sys,rr,rs);
    end

    % corrected phase and code measurements
    [L,P,Lc,Pc]=corr_meas(rtk,obs(i),nav,dantr,dants,rtk.sat(sat).phw);

    if any(obs(i).sat==glc.ID_LEO) && opt.LEO_Aug
        disp(['LEO_used',num2str(obs(i).sat)]);
        LEOFlag=1;
    end
    %% Menz
    if glc.Relativity==1

        rel=2*((sv(i).pos.'*sv(i).vel)/glc.CLIGHT);
        L(L~=0)=L(L~=0)-rel;
        P(P~=0)=P(P~=0)-rel;
        if Lc~=0
            Lc=Lc-rel;
            Pc=Pc-rel;
        end
    else
        rel=0;

    end


    j=0;

    if opt.LEOsingleFreq==1 && LEOFlag==1

        nf_appo=1;
    else

        nf_appo=nf;

    end


    while j<2*nf_appo
        dcb=0; bias=0;



        if opt.ionoopt==glc.IONOOPT_IFLC
            if rem(j,2)==0,y=Lc;else,y=Pc;end
            if y==0,j=j+1;continue;end
        else
            if rem(j,2)==0,y=L(fix(j/2)+1);else,y=P(fix(j/2)+1);end
            if y==0,j=j+1;continue;end
            if sys==glc.SYS_GLO,mm=2;else,mm=1;end
            if fix(j/2)==1,dcb=-nav.rbias(mm,1);end
        end

        %% LEO_pseudoonly Filter
        if rem(j,2)==0 && opt.LEO_pseudoonly && opt.LEO_Aug==1
            if any(obs(i).sat==glc.ID_LEO)
                j=j+1;continue;
            end
        end

        %         %% LEO Filter
        %         if y==0,continue;end
        %         if opt.LEO_Aug==0
        %             if abs(y)<1e7||abs(y)>5e7
        %                 continue;
        %             end
        %         else
        %             if abs(y)>5e7,continue;end
        %         end

        if rem(j,2)==0,C_K1=-1;else,C_K1=1;end
        gama=(lam(fix(j/2)+1)/lam(1))^2;
        if opt.Slant_TEC
            C=gama*C_K1;

        else
            C=gama*ionmapf(pos,azel(i,:))*C_K1;

        end

        H(nv,:)=zeros(1,rtk.nx);
        H(nv,1:3)=-LOS;

        % receiver clock
        dtr=0;
        if  sys==glc.SYS_GPS
            if ~opt.Galileo_REF
            dtr=x(rtk.ic+1);                
            H(nv,rtk.ic+1)=1;%H(nv,rtk.ic+3)=1;
            else
            dtr=x(rtk.ic+1)+x(rtk.ic+3);                
            H(nv,rtk.ic+1)=1;H(nv,rtk.ic+3)=1;          
            end
        elseif sys==glc.SYS_GLO
            dtr=x(rtk.ic+1)+x(rtk.ic+2);
            H(nv,rtk.ic+1)=1; H(nv,rtk.ic+2)=1;
            % for GLONASS icb
            if opt.gloicb==glc.GLOICB_LNF
                if (nf_appo==1&&(fix(j/2)==0&&rem(j,2)==1))||(nf_appo==2&&(fix(j/2)==1&&rem(j,2)==1))
                    frq=get_glo_fcn(sat,nav);
                    dtr=dtr+frq*x(rtk.iicb+1);
                    H(nv,rtk.iicb+1)=frq;
                end
            elseif opt.gloicb==glc.GLOICB_QUAD
                if (nf_appo==1&&(fix(j/2)==0&&rem(j,2)==1))||(nf_appo==2&&(fix(j/2)==1&&rem(j,2)==1))
                    frq=get_glo_fcn(sat,nav);
                    dtr=dtr+frq*x(rtk.iicb+1);
                    H(nv,rtk.iicb+1)=frq;
                    dtr=dtr+frq^2*x(rtk.iicb+2);
                    H(nv,rtk.iicb+2)=frq^2;
                end
            end
        elseif sys==glc.SYS_GAL
            if ~opt.Galileo_REF
            dtr=x(rtk.ic+1)+x(rtk.ic+3);                
            H(nv,rtk.ic+3)=1;H(nv,rtk.ic+1)=1;
            else
            dtr=x(rtk.ic+3);                
            H(nv,rtk.ic+3)=1;          
            end
        elseif sys==glc.SYS_BDS
            dtr=x(rtk.ic+1)+x(rtk.ic+4);
            H(nv,rtk.ic+1)=1; H(nv,rtk.ic+4)=1;
        elseif sys==glc.SYS_QZS
            dtr=x(rtk.ic+1)+x(rtk.ic+5);
            H(nv,rtk.ic+1)=1; H(nv,rtk.ic+5)=1;
        end

        % troposphere
        if opt.tropopt==glc.TROPOPT_EST||opt.tropopt==glc.TROPOPT_ESTG
            H(nv,rtk.it+1)=dtdx(1);
            if opt.tropopt==glc.TROPOPT_ESTG
                H(nv,rtk.it+2)=dtdx(2);H(nv,rtk.it+3)=dtdx(3);
            end
        end

        % ionosphere
        if opt.ionoopt==glc.IONOOPT_EST
%             if ~(any(obs(i).sat==glc.ID_LEO) && opt.LEO_IONO_MODEL==1)

                %             if rtk.x(rtk.ii+sat)==0,j=j+1;continue;end
%                 H(nv,rtk.ii+sat)=C;
%             end
                if rtk.x(rtk.ii+sat)==0,j=j+1;continue;end
                H(nv,rtk.ii+sat)=C;

        end

        % L5-receiver-dcb
        if fix(j/2)==2&&rem(j,2)==1
            dcb=dcb+rtk.x(rtk.id+1);
            H(nv,rtk.id+1)=1;
        end

        % ambiguity
        if rem(j,2)==0
            bias=x(rtk.ib+fix(j/2)*MAXSAT+sat);
            %             if bias==0,j=j+1;continue;end
            H(nv,rtk.ib+fix(j/2)*MAXSAT+sat)=1;
        end

        % residual
        dtS=dts*glc.CLIGHT;

        if OptionSatnav
        
        % v_new Error range/pseudorange_a vs measurement in rinex
        % Expected dummy 10^-4
        if opt.ionoopt==glc.IONOOPT_IFLC
        v_new(nv,1)=y-(sv(i).range+sv(i).tropo)-rel-sv(i).ClkBia;%+sv(i).tropo-sv(i).ClkBia-rel-bias;%0*(dtr-dtS+C*diono+dcb+bias-dgrav);
        else
        v_new(nv,1)=y-sv(i).pseudorange-rel-sv(i).ClkBia;%+sv(i).tropo-sv(i).ClkBia-rel-bias;%0*(dtr-dtS+C*diono+dcb+bias-dgrav);
        end
        %% Calibration
            if OptionClock
                y=y-sv(i).ClkBia;
            end
        end
        % v Residuals measurements
        % Expected dummy 10^-4
        %v(nv,1)=y-(r+dtr-dtS+dtrop+C*diono+dcb+bias-dgrav);
 
        v(nv,1)=y-(r+dtr-dtS+dtrop+C*diono+dcb+bias-dgrav);


        if OptionSatnav
        % Clock Bias Residuals
        v_new_2(nv,1)=dtr-sv(i).ClkBia;%0*(dtr-dtS+C*diono+dcb+bias-dgrav);
        % Tropo Residuals
        v_new_3(nv,1)=dtrop-sv(i).tropo;
        % Iono Residuals        
        v_new_4(nv,1)=C*diono-sv(i).iono;
        % Satnav vs Eph        
        v_new_5(nv,1)=norm(sv(i).Err_SAT_POS);

        end
        v_tot((i-1)*nf*2+(j+1))=v(nv,1);
        v_tot_2((i-1)*nf*2+(j+1))=v_new(nv,1);
        v_tot_3((i-1)*nf*2+(j+1))=v_new_2(nv,1);
        v_tot_4((i-1)*nf*2+(j+1))=v_new_3(nv,1);
        v_tot_5((i-1)*nf*2+(j+1))=v_new_4(nv,1);
        v_tot_6((i-1)*nf*2+(j+1))=v_new_5(nv,1);


        PRN_comp((i-1)*nf*2+(j+1))=obs(i).sat+MAXSAT*(j);

        if rem(j,2)==0,rtk.sat(sat).resc(fix(j/2)+1)=v(nv,1);
        else          ,rtk.sat(sat).resp(fix(j/2)+1)=v(nv,1);
        end

        % variance
        var_rr=varerr_ppp(sys,azel(i,2),fix(j/2),rem(j,2),opt);
        var(nv,1)=var_rr+var_rs+vart+C^2*vari;
        %if sys==glc.SYS_GLO&&rem(j,2)==1,var(nv,1)=var(nv,1)+VAR_GLO_IFB;end

        % reject satellite by pre-fit residuals
        if post==0&&opt.maxinno>0&&abs(v(nv))>opt.maxinno
            exc(i)=1;
            rtk.sat(sat).rejc(rem(j,2)+1)=rtk.sat(sat).rejc(rem(j,2)+1)+1;
            j=j+1; continue;
        end

        % record large post-fit residuals
        if post~=0&&abs(v(nv))>sqrt(var(nv))*4
            obsi(ne+1)=i;frqi(ne+1)=j;ve(ne+1)=v(nv);
            ne=ne+1;
        end

        if rem(j,2)==0,rtk.sat(sat).vsat(fix(j/2)+1)=1;end

        nv=nv+1;
        j=j+1;
    end

    %     if rem(nv-1,j)==0 || Pc~=0
    %     PRN_comp(i)=obs(i).sat;
    %     end

end

if nv-1==0
    v=NaN;H=NaN;var=NaN;
elseif nv-1<2*nobs*nf
    v(nv:end)=[]; H(nv:end,:)=[]; var(nv:end)=[];
end
obsi(ne+1:end,:)=[];frqi(ne+1:end,:)=[];ve(ne+1:end,:)=[];



% reject satellite with large and max post-fit residual
if post~=0 && ne>0
    vmax=ve(1);maxobs=obsi(1);maxfrqi=frqi(1);rej=1; %#ok
    j=2;
    while j<=ne
        if abs(vmax)>=abs(ve(j))
            j=j+1; continue;
        end
        vmax=ve(j);maxobs=obsi(j);maxfrqi=frqi(j);rej=j; %#ok
        j=j+1;
    end
    sat=obs(maxobs).sat;
    exc(maxobs)=1;
    rtk.sat(sat).rejc(rem(j,2)+1)=rtk.sat(sat).rejc(rem(j,2)+1)+1;
    stat=0;
    ve(rej)=0; %#ok
end

% measurement noise matrix
if nv-1>0
    R=zeros(nv-1,nv-1);
    for i=1:nv-1
        for j=1:nv-1
            if i==j
                R(i,j)=var(i);
            else
                R(i,j)=0;
            end
        end
    end
else
    R=NaN;
end

if post==0
    stat=nv-1;
end

if post~=0
    if qq/2>5
        tr_new(qq)=rtk.sol.dtrd;

        if ~isnan(gls.Log.PPP.STATE(12,qq-2)) && ~isnan(gls.Log.PPP.STATE(12,qq-3))
            if abs(gls.Log.PPP.STATE(12,qq-2)-gls.Log.PPP.STATE(12,qq-3))>100
                stat=0;
            end
        end
    end
    qq=qq+1;

end



return

