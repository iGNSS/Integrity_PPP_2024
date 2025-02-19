function sv=satposs(obs,nav,ephopt,rtk,FlagBRD2FINE)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%compute satellite position,clock bias,velocity,clock drift
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%input��obs   - observation
%       nav   - navigation message
%       ephopt- ephemeric option(0:using broadcast eph;1:using precise eph)
%output��sv   - space vehicle struct(record satellite position,clock bias,
%           velocity and clock drift)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%1.satellite position and clock are values at signal transmission time
%2.satellite position is referenced to antenna phase center
%3.satellite clock does not include code bias correction (tgd or bgd)
%4.any pseudorange and broadcast ephemeris are always needed to get signal
%  transmission time
%5.only surport broadcast/precise ephemeris,not RTCM-SSR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

global glc gls OptionSatnav2
global motionV2 satdataV1A2 OptionSatNavEph InitTime SkipTime ClockBias OptionSatnav %Elapsed_Time
%% MODMENZ
%% STD_BRDCCLK

% if isempty(Elapsed_Time)
%     Elapsed_Time=1;
% end

STD_BRDCCLK =gls.STD_BRDCCLK; time0=obs(1).time;
nobs=size(obs,1); % number of observation
sv=repmat(gls.sv,nobs,1);
opt=rtk.opt;

LEO_CONTER=1;

% %% Mod
% I_Filt=abs((motionV2.TimeGPS-time0.time))<10^-4;
% % I_Filt_2=motionV2.TimeGPS==time.time-1;
% % I_Filt_3=motionV2.TimeGPS==time.time-2;
% %
% GAL_GPS=motionV2.Sat_type(I_Filt);
% PRN=motionV2.Sat_PRN(I_Filt);
% Sat_Pos_X=motionV2.Sat_Pos_X(I_Filt);
% Sat_Pos_Y=motionV2.Sat_Pos_Y(I_Filt);
% Sat_Pos_Z=motionV2.Sat_Pos_Z(I_Filt);
% Sat_Vel_X=motionV2.Sat_Vel_X(I_Filt);
% Sat_Vel_Y=motionV2.Sat_Vel_Y(I_Filt);
% Sat_Vel_Z=motionV2.Sat_Vel_Z(I_Filt);
% Sat_Acc_X=motionV2.Sat_Acc_X(I_Filt);
% Sat_Acc_Y=motionV2.Sat_Acc_Y(I_Filt);
% Sat_Acc_Z=motionV2.Sat_Acc_Z(I_Filt);



% ID_GAL=GAL_GPS=='GALILEO';
% ID=vertcat(obs.sat);
% sv_old=sv;
% KKK=60;OptionSatNavEph
% %% Mod

% if OptionSatNavEph

if (time0.time-InitTime.time)<0 || time0.time<=SkipTime.time
    for ii=1:nobs
        sv(ii).pos=zeros(3,1);
        sv(ii).vel=zeros(3,1);
        sv(ii).svh=-1;
    end
    satdataV1A2(isnan(satdataV1A2.Time_ms),:)=[];
    return
else
    %% Search
    Index_time=(round(satdataV1A2.Time_ms/1000))==time0.time-InitTime.time;

    SAT_POS=[satdataV1A2.Sat_Pos_X(Index_time),satdataV1A2.Sat_Pos_Y(Index_time),satdataV1A2.Sat_Pos_Z(Index_time)].';
    SAT_VEL=[satdataV1A2.Sat_Vel_X(Index_time),satdataV1A2.Sat_Vel_Y(Index_time),satdataV1A2.Sat_Vel_Z(Index_time)].';
    pseudorange=satdataV1A2.PRangeGroupA(Index_time);
    range=satdataV1A2.Range(Index_time);

    tropo=satdataV1A2.Tropo_delay(Index_time)*glc.CLIGHT;
    iono=satdataV1A2.Iono_delayGroupA(Index_time)*glc.CLIGHT;

    IndexClockBias=time0.time==ClockBias.TimeTag;
    ClkBia=ClockBias.Bias(IndexClockBias);
end



% end

for i=1:nobs

    if ~OptionSatNavEph

        for j=1:glc.NFREQ
            pr=obs(i).P(j);
            if pr~=0,break;end
        end
        if pr==0,continue;end

        time=timeadd(time0,-pr/glc.CLIGHT); %raw single transition time

        [dts,stat1]=ephclk(time,obs(i),nav);
        if stat1==0,continue;end

        time=timeadd(time,-dts); %signal transition time


        [sv(i),stat2]=satpos(time,obs(i),nav,ephopt,sv(i));

        if stat2==0,continue;end

        if sv(i).dts==0
            [dts,stat1]=ephclk(time,obs(i),nav);
            if stat1==0,continue;end
            sv(i).dtsd=dts; sv(i).dtsd=0;
            sv(i).vars=sv(i).vars+STD_BRDCCLK^2;
        end

        %% MODMENZ

        % glc.ADDEPHERR_SPP_GPS=[0;0;0];
        % glc.ADDEPHERR_SPP_GAL=[0;0;0];
        % glc.ADDEPHERR_SPP_LEO=[0;0;0];

        if OptionSatnav

            if (time0.time-InitTime.time)>0 && time0.time>SkipTime.time
                %             sv(i).pos=zeros(3,1);
                %             sv(i).vel=zeros(3,1);
                %             satdataV1A2(isnan(satdataV1A2.Time_ms),:)=[];
                %         else
                %% Search
                %             Index_time=(satdataV1A2.Time_ms/1000)==time0.time-InitTime;
                if obs(i).sat>=60
                    %% Gal
                    Index_Gal=(satdataV1A2.Sat_type(Index_time)=="GALILEO");
                    Index_fin=Index_Gal & (satdataV1A2.Sat_ID(Index_time))==(obs(i).sat-59);

                else
                    Index_GPS=(satdataV1A2.Sat_type(Index_time)=="GPS");
                    Index_fin=Index_GPS &  (satdataV1A2.Sat_ID(Index_time))==obs(i).sat;
                end

                if OptionSatnav2
                    sv(i).pseudorange=0;
                    sv(i).range=0;

                    sv(i).tropo=0;
                    sv(i).iono=0;
                    sv(i).ClkBia=0;
                    sv(i).Err_SAT_POS=zeros(3,1);
                else

                    if any(Index_fin)
                        sv(i).pseudorange=pseudorange(Index_fin);
                        sv(i).range=range(Index_fin);

                        sv(i).tropo=tropo(Index_fin);
                        sv(i).iono=iono(Index_fin);
                        sv(i).ClkBia=ClkBia;
                        sv(i).Err_SAT_POS=SAT_POS(:,Index_fin)-sv(i).pos;
                    else
                        sv(i).pseudorange=0;
                        sv(i).range=0;

                        sv(i).tropo=0;
                        sv(i).iono=0;
                        sv(i).ClkBia=0;
                        sv(i).Err_SAT_POS=zeros(3,1);

                    end

                end

            end

        end


        if any(obs(i).sat==glc.ID_BAN)
            sv(i).pos=zeros(3,1);
            sv(i).vel=zeros(3,1);
            sv(i).svh=-1;
            disp(['BAN_out',num2str(obs(i).sat)]);
            continue
            %                 else
            %                     disp(['BAN_in',num2str(obs(i).sat)]);
        end


        if any(obs(i).sat==glc.ID_LEO)
            if  opt.LEO_Aug==0
                disp(norm(sv(i).vel));
                sv(i).pos=zeros(3,1);
                sv(i).vel=zeros(3,1);
                sv(i).svh=-1;
                disp(['LEO_out',num2str(obs(i).sat)]);

            else
                disp(['LEO_in',num2str(obs(i).sat)]);
                if LEO_CONTER>opt.MAXLEO
                    disp(norm(sv(i).vel));
                    sv(i).pos=zeros(3,1);
                    sv(i).vel=zeros(3,1);
                    sv(i).svh=-1;
                    disp(['MAXLEO_removed',num2str(obs(i).sat)]);

                end
                % satellite information
                rs=sv(i).pos; 
                rr=rtk.x(1:3,1);
                pos=ecef2pos(rr);
                % distance/light of sight/azimuth/elevation
                [r,LOS]=geodist(rs,rr); azel=satazel(pos,LOS);
                if azel>=opt.elmin
                LEO_CONTER=LEO_CONTER+1;
                end

            end

        end

        %% LEO_Filter


        if any(obs(i).sat==glc.ID_BAN)
            sv(i).pos=zeros(3,1);
            sv(i).vel=zeros(3,1);
            sv(i).svh=-1;
            disp(['BAN_out',num2str(obs(i).sat)]);
            %                 else
            %                     disp(['BAN_in',num2str(obs(i).sat)]);
        end




    else

        for j=1:glc.NFREQ
            pr=obs(i).P(j);
            if pr~=0,break;end
        end
        if pr==0,continue;end

        time=timeadd(time0,0);

        if (time0.time-InitTime.time)>0 && time0.time>SkipTime.time
            %             sv(i).pos=zeros(3,1);
            %             sv(i).vel=zeros(3,1);
            %             satdataV1A2(isnan(satdataV1A2.Time_ms),:)=[];
            %         else
            %% Search
            %             Index_time=(satdataV1A2.Time_ms/1000)==time0.time-InitTime;
            if obs(i).sat>=60
                %% Gal
                Index_Gal=(satdataV1A2.Sat_type(Index_time)=="GALILEO");
                Index_fin=Index_Gal & (satdataV1A2.Sat_ID(Index_time))==(obs(i).sat-59);

            else
                Index_GPS=(satdataV1A2.Sat_type(Index_time)=="GPS");
                Index_fin=Index_GPS &  (satdataV1A2.Sat_ID(Index_time))==obs(i).sat;
            end

            if any(Index_fin)
                sv(i).pos=SAT_POS(:,Index_fin);
                sv(i).vel=SAT_VEL(:,Index_fin);
                sv(i).svh=0;
                sv(i).pseudorange=pseudorange(Index_fin);
                sv(i).tropo=tropo(Index_fin);
                sv(i).iono=iono(Index_fin);
                sv(i).range=range(Index_fin);
                sv(i).Err_SAT_POS=SAT_POS(:,Index_fin)-sv(i).pos;

                sv(i).ClkBia=ClkBia;
            else
                sv(i).pos=zeros(3,1);
                sv(i).vel=zeros(3,1);
                sv(i).svh=-1;
                sv(i).pseudorange=0;
                sv(i).range=0;

                sv(i).tropo=0;
                sv(i).iono=0;
                sv(i).ClkBia=0;
                sv(i).Err_SAT_POS=zeros(3,1);

            end

            %% LEO_Filter
                        %% Filter SAT

            if any(obs(i).sat==glc.ID_BAN)
                sv(i).pos=zeros(3,1);
                sv(i).vel=zeros(3,1);
                sv(i).svh=-1;
                disp(['BAN_out',num2str(obs(i).sat)]);
                continue
                %                 else
                %                     disp(['BAN_in',num2str(obs(i).sat)]);
            end


            % if  norm(sv(i).pos)-glc.RE_WGS84<opt.LEO_thr_pos
            if any(obs(i).sat==glc.ID_LEO)
                if  opt.LEO_Aug==0

                    sv(i).pos=zeros(3,1);
                    sv(i).vel=zeros(3,1);
                    sv(i).svh=-1;
                    disp(['LEO_out',num2str(obs(i).sat)]);

                else
                    disp(['LEO_in',num2str(obs(i).sat)]);
                    if LEO_CONTER>opt.MAXLEO
                        %disp(norm(sv(i).vel));
                        sv(i).pos=zeros(3,1);
                        sv(i).vel=zeros(3,1);
                        sv(i).svh=-1;
                        disp(['MAXLEO_removed',num2str(obs(i).sat)]);

                    end
                    rs=sv(i).pos; 
                rr=rtk.x(1:3);
                pos=ecef2pos(rr);
                % distance/light of sight/azimuth/elevation
                [r,LOS]=geodist(rs,rr); azel=satazel(pos,LOS);
                if azel(1,2)>=opt.elmin
                LEO_CONTER=LEO_CONTER+1;
                end

                end

            end




        end

        %% ADD HAS/BRD Error

        stat1=1;
        stat2=1;

        %% ModMenz

        %         if glc.BRDperPrec
        %             sv(i).vars=glc.EphErrOverW;
        %         end


        %         %     %% Mod
        %         sv_old(i)=sv(i);
        %         [sys,~]=satsys(ID(i));
        %         PRN_GPS=PRN(~ID_GAL);
        %         PRN_GAL=PRN(ID_GAL);
        %         n_gps=length(PRN_GPS);
        %         n_gal=length(PRN_GAL);
        %
        %         if ID(i)<=32%sys==1
        %
        %             ID_Targ=[PRN_GPS==ID(i);zeros(n_gal,1)==1];
        %             %         ID_Targ=ID_Targ;
        %
        %         elseif ID(i)>=60
        %             ID_Targ=[zeros(n_gps,1)==1;(PRN_GAL+59)==ID(i)];
        %             %           ID_Targ=[zeros(1,n_gps),ID_Targ];
        %         else
        %             ID_Targ=0;
        %         end
        %
        %         if any(ID_Targ)
        %
        %             Ref_time=satdataV1A2.TimeGPS(I_Filt);
        %             Tau_prop=-((time.time+time.sec)-Ref_time(1));%-0.001;%+rtk.sol.dtr(1);
        %
        %             utc=gpst2utc(time);
        %             [Pos,Vel,Acc]=ecef2eci(time2epoch(utc),[Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)],[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)],...
        %                 [Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)]);
        %             Pos_Prop=Pos+Vel*Tau_prop+sign(Tau_prop)*Tau_prop^2*Acc;
        %             Vel_Prop=Vel+Acc*Tau_prop;
        %
        %             [sv(i).pos,sv(i).vel]=eci2ecef(time2epoch(utc),Pos_Prop,Vel_Prop);
        %
        %             %         sv(i).pos=[Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)];%-...
        %             %         [Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)]*Tau_prop-...
        %             %         sign(Tau_prop)*[Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)]*(Tau_prop^2)/2;
        %
        %         end

    end

    %% ADD Eph Error
    Elapsed_time=time0.time-InitTime.time;
    if glc.SPPBRD && FlagBRD2FINE==0
        sv(i).pos=sv(i).pos+squeeze(glc.POS_ERR_ECEF_SPP(obs(i).sat,Elapsed_time,:));
    elseif glc.SPPBRD && FlagBRD2FINE==1
        sv(i).pos=sv(i).pos+squeeze(glc.POS_ERR_ECEF(obs(i).sat,Elapsed_time,:));

    end


    %
    %     %% MOD
    %% MOD
    if gls.EPH_LEO_ERR
        if any(obs(i).sat==glc.ID_LEO)
            v(i).vars=sv(i).vars+glc.STD_LEO^2;
        end
    end



    %% Mod
    if FlagBRD2FINE
        sv(i).vars=glc.URA_FINE;
    else
        sv(i).vars=glc.URA_BRD;
    end

end

% % if FlagBRD2FINE==1
% % Elapsed_Time=Elapsed_Time+1;
% % end


% for ii=1:length(ID)
%
%     [sys,~]=satsys(ID(ii));
%
%     if sys==1
%
%         PRN_GPS=PRN(~ID_GAL);
%         ID_Targ=PRN_GPS==ID(ii);
% %         ID_Targ=ID_Targ;
%
%     else
%         PRN_GAL=PRN(ID_GAL);
%         ID_Targ=(PRN_GAL+KKK)==ID(ii);
%         ID_Targ=0*ID_Targ;
%     end
% %
%     if any(ID_Targ)
%
%
%         Tau_prop=(motionV2.TimeGPS(I_Filt)-time.time);
%         sv(ii).pos=[Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)]+...
%         [Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)]*Tau_prop+...
%         [Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)]*(Tau_prop^2)/2;
%
%     end
%
% end
%             Vect_interp=[[Sat_Pos_X_3(ID_Targ);Sat_Pos_Y_3(ID_Targ);Sat_Pos_Z_3(ID_Targ)],...
%                 [Sat_Pos_X_2(ID_Targ);Sat_Pos_Y_2(ID_Targ);Sat_Pos_Z_2(ID_Targ)],...
%                 [Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)]];
%             Time_interp=[time.time-2,time.time-1,time.time];
%             %tau=time.time-rtk.sol.dtr(3);
%             tau=0*obs(ii).P(1)/299792458;
%
%             obs(ii).P(1)/299792458;
%
% %             sv(ii).pos=[interp1(Time_interp,Vect_interp(1,:),tau,'spline','extrap');
% %                 interp1(Time_interp,Vect_interp(2,:),tau,'spline','extrap');
% %                 interp1(Time_interp,Vect_interp(3,:),tau,'spline','extrap')];
% %             sv(ii).vel=[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)];
% %             sv(ii).acc=[Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)];
%
% %             sv(ii).pos=[Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)];
% %             sv(ii).vel=[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)];
% %             sv(ii).acc=[Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)];
%
%             sv(ii).pos=[Sat_Pos_X_2(ID_Targ);Sat_Pos_Y_2(ID_Targ);Sat_Pos_Z_2(ID_Targ)]-[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)]*tau;
%             sv(ii).vel=[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)];
%             sv(ii).acc=[Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)];
%     end

%             sv(ii).pos=[Sat_Pos_X(ID_Targ);Sat_Pos_Y(ID_Targ);Sat_Pos_Z(ID_Targ)];
%             sv(ii).vel=[Sat_Vel_X(ID_Targ);Sat_Vel_Y(ID_Targ);Sat_Vel_Z(ID_Targ)];
%             sv(ii).acc=[Sat_Acc_X(ID_Targ);Sat_Acc_Y(ID_Targ);Sat_Acc_Z(ID_Targ)];



return

