filename inft "/home/sasdemo/dmcx_codigos/imp_analisis/inft/*sas";
filename scap "/home/sasdemo/dmcx_codigos/imp_analisis/inft/scaproc.txt";

%*dmcxm_borra_comentarios(inft);
data work.imp_analisis_010;
	infile scap truncover;
	length categoria $ 46  consulta $ 32767 tabla $ 32 procedimiento $ 10;
	retain paso 1 flag  inicio 0 tabla consulta procedimiento '';
	input;
	put _infile_;

	if _infile_=:'/* JOBSPLIT: ' then
		do;
			categoria=scan(_infile_,3,' ');

			if categoria="TASKSTARTTIME" then
				do;
					inicio=input(substr(_infile_,28,22),datetime22.2);

					*output;
				end;

			if categoria="DATASET" then
				do;
					tabla=scan(_infile_,6);
					io_tabla=scan(_infile_,3);
					libreria=scan(_infile_,5);
					output;
				end;

			if categoria="ATTR" then
				do;
					tabla=scan(_infile_,4);
					io=scan(_infile_,6);
					libreria=scan(_infile_,3);
					variable=upcase(scan(_infile_,7," :"));
					output;
				end;

			if categoria="PROCNAME" then
				do;
					procedimiento=scan(_infile_,3);
				end;
		end;
	else
		do;
			if index(upcase(_infile_),'PROC') or index(upcase(_infile_),'DATA') then
				flag=1;

			if flag;
			consulta=catx(" ",consulta,_infile_);

			if index(upcase(_infile_),'QUIT;') or index(upcase(_infile_),'RUN;') then
				do;
					categoria="CONSULTA";
					output;
					paso+1;
					flag=0;
					consulta='';
					procedimiento='';
				end;
		end;

	format inicio datetime22.2;
	drop flag;
run;

proc sql;
	create table work.imp_analisis_020 as
		select vr.paso,
			c.procedimiento,
			vr.inicio,
			vr.libreria,
			vr.tabla,
			ds.io_tabla,
			vr.variable,
			vr.io,
			c.consulta
		from
			work.imp_analisis_010(where=(categoria='ATTR')) as vr
		left join
			work.imp_analisis_010(where=(categoria='CONSULTA')) as c
			on vr.paso=c.paso
		left join
			work.imp_analisis_010(where=(categoria='DATASET')) as ds
			on vr.paso=ds.paso and vr.libreria=ds.libreria and vr.tabla=ds.tabla;
quit;

data work.imp_analisis_030;
	set work.imp_analisis_010(where=(procedimiento in ("SQL","DATASTEP")) keep=procedimiento inicio paso consulta);
	length calculo calculo_c $32767;

	if last.paso;

	/*SQL*/
	if procedimiento="SQL" then
		do;
			count = count(upcase(consulta),"SELECT");
			fr=1;

			/*	Revisar todas las subconsultas*/
			do i=1 to count;
				subconsulta=i;
				sel=find(upcase(consulta),'SELECT',fr);
				fr=find(upcase(consulta),'FROM',sel);
				consulta_a=substrn(consulta,sel,fr-sel);
				countas = count(upcase(consulta_a)," AS ");
				pos=1;
				as=0;

				do j=1 to countas;
					as=as+findw(consulta_a,'as',', ', 'ie',pos);
					pos=1+findw(consulta_a,'as',', ', 'i',pos);
					variable=upcase(scan(consulta_a,as+1,', '));
					l=length(variable);
					flag=1;
					in=index(upcase(consulta_a),"AS "||trim(variable));

					/*	Revisar que esta en la subconsulta*/
					if in>0 then
						do;
							com=findc(consulta_a,',','b',-in);

							/*	Revisar esa subconsulta*/
							if com>0 then
								do;
									calculo_c=substrn(consulta_a,com+1,in-com+l+2);
									par1=countc(calculo_c, '(');
									par2=countc(calculo_c, ')');

									/*	Revisar parentesis*/
									if par1 ne par2 then
										do;
											do while(par1 ne par2);
												com=findc(consulta_a,',','b',-com+1);
												calculo_c=substrn(consulta_a,com+1,in-com+l+2);
												kw=scan(upcase(calculo_c),1);

												if kw='SELECT' then
													do;
														kw2=scan(upcase(calculo_c),2);

														if kw2='DISTINCT' then
															calculo_c=substrn(calculo_c,17);
													end;

												par1=countc(calculo_c, '(');
												par2=countc(calculo_c, ')');
											end;
										end;

									calculo=catx(",",calculo,calculo_c);

									/*	Fin revisar parentesis*/
								end;

							/*	Fin revisar subconsulta*/
						end;

					output;
					calculo='';
				end;
			end;
		end;

	/*Fin SQL*/
	*run;
	*data work.imp_analisis_030;
	*set work.imp_analisis_010(where=(procedimiento in ("DATASTEP")) keep=procedimiento paso consulta);
	*	if last.paso;
	/*	Calculos en DATA STEP*/
	if procedimiento = 'DATASTEP' then
		do;
			count = countc(consulta,';');

			do i=1 to count;
				/*pyc2=findc(consulta,';',pyc1);*/
				*consulta_a=substrn(consulta,pyc1,pyc2-pyc1);
				consulta_a=scan(consulta,i,';');

				/*	Verificar que la expresion este en la consulta*/
				in=findc(consulta_a,"=");
				count_c = countc(consulta_a,'=');
				kw=upcase(scan(consulta_a,1));

				if kw not in ("SET","MERGE","RENAME","LABEL","INFILE","ARRAY") then
					do;
						if in>0 then
							do;
								do j=1 to count_c;
									consulta_b=scan(consulta_a,j,'=');
									variable=upcase(scan(consulta_b,-1));
									l=length(variable);
									last_c=substrn(variable,l,1);

									if last_c not in ("<",">","]") then
										do;
											flag=1;
											calculo=consulta_a;
											output;
										end;
								end;
							end;
					end;
			end;
		end;

	/*	Fin DATASTEP*/
	by paso;
	drop calculo_c count: fr i subconsulta sel consulta_: pos as j l in com par: kw: last_c;
run;

proc sort data=work.imp_analisis_030;
	by paso variable;
run;

data work.imp_analisis_040;
	set work.imp_analisis_030(rename=(calculo=calculo_c));
	by paso variable;
	length calculo $32767;
	retain calculo '';

	if first.variable then
		calculo='';

	if calculo_c ne '' then
		calculo=catx(';',calculo,calculo_c);

	if last.variable;
	drop calculo_c;
run;

proc sql;
	create table work.imp_analisis_050 as
		select coalesce(a.paso,b.paso) as paso,
			coalescec(a.procedimiento,b.procedimiento) as procedimiento,
			coalesce(a.inicio,b.inicio) as inicio format = datetime22.,
			a.libreria,
			a.tabla,
			a.io_tabla,
			coalescec(a.variable,b.variable) as variable,
			a.io,
			coalescec(a.consulta,b.consulta) as consulta length = 32767,
		case 
			when calculated procedimiento in ("SQL","DATASTEP") then b.calculo
			else a.consulta 
		end 
	as calculo,
		b.flag
	from work.imp_analisis_020 a
		full join work.imp_analisis_040 b
			on a.paso=b.paso and a.variable=b.variable;
quit;

data work.imp_analisis_060;
	set work.imp_analisis_050;
	length filtro filtro_dso filtro_s $32767;

	/*	PROC*/

	*	if procedimiento = 'SQL' then
	do;
	count = count(upcase(consulta),' WHERE ');

	/*	Checar subconsultas*/
	if count > 0 then
		do;
			do i=1 to count;
				par1=find(upcase(consulta),' WHERE ');
				par2=find(consulta,')',par1);
				parc1=1;
				pyc=find(consulta,';',par1);

				if  par2 < pyc then
					do;
						filtro_c=substrn(consulta,par1,pyc-par1);
					end;
				else
					do;
						do while (parc1 = parc2);
							filtro_c=substrn(consulta,par1,par2-par1);
							parc1=countc(filtro_c, '(');
							parc2=countc(filtro_c, ')');
							par2=find(consulta,')',par2+1);
						end;
					end;

				array nn (3) $ 10 _temporary_ ("GROUP BY", "HAVING BY", "ORDER BY");

				do i=1 to dim(nn);
					kw = find(upcase(filtro_c),trim(nn[i]));

					if kw>0 then
						do;
							filtro_c=substrn(filtro_c,1,kw-1);
							match=nn[i];
							leave;
						end;
				end;

				filtro_s=catx(',',filtro_s,filtro_c);
			end;
		end;

	/* Fin de WHERE en PROC*/
	/*	Dataset Options*/
	/*	Conteo de Where	*/
	count = count(upcase(consulta),'(WHERE=(','t');

	do i=1 to count;
		par1=find(upcase(consulta),'WHERE=(');
		par2=find(consulta,')',par1);
		parc1=1;

		do while (parc1 ne parc2);
			filtro_c=substrn(consulta,par1,par2-par1);
			parc1=countc(filtro_c, '(');
			parc2=countc(filtro_c, ')');
			par2=find(consulta,')',par2+1);
		end;

		filtro_dso=catx(',',filtro,filtro_c);
	end;

	/*	Fin de Dataset Options*/
	filtro=catx(';',filtro_dso,filtro_s);
	in = find(upcase(filtro),trim(variable));

	if in > 0 then
		flag_f = 1;
	filtro=substrn(filtro,7);
	drop count i pyc par: in filtro_: kw match;
run;

proc sql;
	create table work.imp_analisis_070 as
		select distinct paso as paso_c,
			libreria as libreria_c,
			tabla as tabla_c,
			variable as variable_c,
			calculo as calculo_c
		from work.imp_analisis_060
			where procedimiento in ("SQL","DATASTEP") and calculo ne '';
quit;

proc sort data=work.imp_analisis_060;
	by paso variable io;
run;

proc sql;
	create table work.imp_analisis_080 as
		select coalesce(a.paso,b.paso) as paso,
			coalescec(a.procedimiento,b.procedimiento) as procedimiento,
			coalesce(a.inicio,b.inicio) as inicio format = datetime22.,
			a.libreria as libreria_in,
			a.tabla as tabla_in,
			a.io_tabla,
			a.variable as variable_in,
			b.libreria as libreria_out,
			b.tabla as tabla_out,
			b.variable as variable_out,
			coalescec(a.consulta,b.consulta) as consulta length = 32767,
			coalescec(a.calculo,b.calculo) as calculo length = 32767,
			coalescec(a.filtro,b.filtro) as filtro length = 32767
		from work.imp_analisis_060(where =(io in ('INPUT',''))) a
			full join work.imp_analisis_060(where =(io in ('OUTPUT',''))) b
				on a.paso=b.paso and a.variable=b.variable;
quit;

data work.imp_analisis_090;
	set work.imp_analisis_080;

	if procedimiento in ("SQL","DATASTEP") then
		do;
			count=0;

			do i=1 to n;
				set work.imp_analisis_070 point=i nobs=n;

				if paso=paso_c and coalescec(variable_in,variable_out) ne variable_c then
					do;
						in = find(upcase(calculo_c),trim(coalescec(variable_in,variable_out)));

						if in > 0 then
							do;
								count+1;
								variable_out=variable_c;
								libreria_out=libreria_c;
								tabla_out=tabla_c;
								output;
							end;
					end;
			end;

			if count=0 then
				output;
		end;
	else output;
	drop count paso_c variable_c calculo_c libreria_c tabla_c in;
run;

proc sql;
	create table work.imp_analisis_100 as
		select distinct paso,
			calculo,
			variable_out
		from work.imp_analisis_090
			where calculo ne '';
quit;

proc sql;
	create table work.imp_analisis_110(drop=calculo_c) as
		select a.*,
			b.calculo as calculo
		from work.imp_analisis_090(rename=(calculo=calculo_c)) a
			left join work.imp_analisis_100 b
				on a.paso=b.paso and a.variable_out=b.variable_out;
quit;

proc sql;
	create table work.imp_analisis_120 as
		select *,
			sum(not missing(calculo)) as count
		from work.imp_analisis_110
			group by paso, calculo;
quit;

data work.imp_analisis_130;
	set work.imp_analisis_120;

	if variable_in = '' and count >1 then
		delete;

	*if flag_c = 1 and variable_in=variable_out then delete;
	drop count;
run;

