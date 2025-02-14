/*Compares various SAS 9 tasks to CAS enabled procedures to CASL (PROC CAS, CAS language*/

/****Start a CAS session, map all default libraries to your session, add additional
information to the lo (times)****/
cas mysess sessopts=(timeout=10800 metrics=true) ;
caslib _all_ assign;


/****Create a local library****/
/*Local SAS 9 libraries can be created that point to data on your NFS mount*/ 
/***USER TO REPLACE PATH FOR THEIR OWN****/
libname locallib '/export/canada/homes/lorne.r/casuser/data' ;


/*LOAD local data into in-memory CAS library*/ 
data casuser.imp_lbwt;
	set locallib.imp_lbwt;
run;


/*... or use PROC CASUTIL */

/*
proc casutil;
	load data=locallib.imp_lbwt casout="imp_lbwt" outcaslib=casuser replace;
run;
*/


/************************************************************************************/
/*CAS IS FASTER*/
/***********DATA STEP ***********/


data imp_lbwt;
	set locallib.imp_lbwt locallib.imp_lbwt locallib.imp_lbwt locallib.imp_lbwt
		locallib.imp_lbwt;
	newvar=fage-mage;
run;

data casuser.tmp;
	set casuser.imp_lbwt casuser.imp_lbwt casuser.imp_lbwt casuser.imp_lbwt 
		casuser.imp_lbwt;
	newvar=fage-mage;
run;


/******************************************Summary means**/
/*Run in  SAS9  */
proc means data=imp_lbwt noprint;
	var feduc mage;
	class lbwt hyperch;
	output out=casuser.summaryMEANScas sum(feduc)=sumfeduc sum(mage)=summmage;
run;

/*CAS-ENABLED PROC*/
proc mdsummary data=casuser.tmp;
	var feduc mage;
	groupby lbwt hyperch/ out=casuser.mds;
run;

/*CASL*/
proc cas;
	simple.summary result=r status=s / inputs=${feduc mage}, subSet={"SUM"}, 
		table={name="tmp" caslib="casuser", groupBy={"lbwt", "hyperch"}}, 
		casout={name="summaryCAS", caslib="casuser", replace=True, replication=0};
	run;
quit;

proc print data=casuser.mds;
run;

/*******************************************************Moments, Percentiles**/
/*SAS9*/
proc univariate data=imp_lbwt;
	var feduc mage;
	output out=UniWidePctls pctlpre=ddaP_ avgP_ pctlpts=5, 25, 75, 95;
run;

/*CASL*/
proc cas;
	dataPreprocess.rustats / table={caslib="casuser", name="tmp"} , 
		inputs=${feduc mage}, requestPackages={{percentiles={"5", "25", "75", "95"}}, 
		{allLocations=True}, {allScales=True}}, casout={name="perc", 
		caslib="casuser", replace=True};
	run;
quit;

proc print data=casuser.perc;
run;

/***********************************************Frequencies*/
/*SAS 9 Procedure*/
proc freq data=imp_lbwt;
	tables prenatal lbwt prenatal*lbwt;
run;

/*CAS Procedure*/
proc freqtab data=casuser.tmp;
	tables prenatal lbwt prenatal*lbwt;
run;

/*CASL*/
proc cas;
	action freqTab.freqTab / table={caslib="casuser", name="tmp"} , 
		tabulate={'lbwt', 'prenatal', {vars={'lbwt', 'prenatal'}}};
	run;
quit;

/*DEFINE INPUT VARIABLES */
%let cvars=ACLUNG AMNIO ANEMIA CARDIAC CERVIX /*racedad*/ racemom 
uterine loutcome marital pinfant renal rhsen  diabetes herpes hydram hemoglob
hyperch hyperpr eclamp ultra
;
%let nvars=fage mage feduc meduc bdead totalp terms prenatal YrsLastLiveBirth
YrsLastFetalDeath drinker smoker preterm children cignum drinknum ;

/*CORRELATION*/
/*SAS 9*/
proc corr data=imp_lbwt;
	var &nvars;
run;

/*CAS ENABLED PROC*/
proc correlation data=casuser.tmp;
	var &nvars;
run;

/*CASL*/
proc cas;
	simple.correlation / inputs=${&nvars}, pairWithInput=${&nvars}, 
		table={name="tmp" caslib="casuser"};
	run;
quit;

/*SAS 9 . With fast' option */
PROC LOGISTIC data=imp_lbwt DESCENDING;
	class &cvars;
	MODEL lbwt=&nvars &cvars/selection=backward fast stb;
RUN;

/*CAS ENABLED PROC*/
Proc logselect data=casuser.tmp STB ASSOCIATION;
	class &cvars;
	model lbwt(event='1')=&nvars &cvars / link=logit type3;
	selection method=backward(fast stop=sl select=sl) hierarchy=none;
run;

/*CASL*/
proc cas;
	regression.logistic / class=${&cvars}, display={traceNames="true"}, 
		model={depvar="lbwt", effects=${&cvars &nvars}}, selection={method="backward" 
		fast=TRUE}, table={name="tmp" caslib="casuser"};
quit;

/*POISSON Regression. Generalized Linear Model*/
/*SAS9*/

%let nvars=fage mage feduc meduc  bdead terms YrsLastLiveBirth
YrsLastFetalDeath drinker smoker preterm;

proc hpgenselect data=imp_lbwt;
	class &cvars;
	model totalp=&nvars &cvars/ Distribution=poisson;
	selection method=stepwise details=all;
run;

/*CAS*/
proc genselect data=casuser.tmp;
	class &cvars;
	model totalp=&nvars &cvars/ Distribution=poisson;
	selection method=stepwise details=all;
run;





/*PROMOTE to global scopre from session scope, SAVE to dics, DROPTABLE from 
memory, DELTESOURCE--delete sashadat table from disc */
/*
proc casutil outcaslib="casuser";
promote casdata="scores" incaslib="casuser";
save casdata="scores" incaslib="casuser";
run;

proc casutil;
droptable casdata="scores" incaslib="casuser" quiet;
run;

proc casutil;
deletesource casdata="scores.sashdat" incaslib="casuser" quiet;
run;
*/