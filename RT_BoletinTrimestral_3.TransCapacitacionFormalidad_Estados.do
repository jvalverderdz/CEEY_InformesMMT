********************
version 15
clear all
set more off
cls
********************
 
/*********************************************************************************************
* Nombre archivo: 		RT_BoletinTrimestral_3.TransCapacitacionFormalidad_Estados
* Autor:          		Javier Valverde	
* Archivos usados:     
	- ENOE_Base Global_Dinamica.dta
* Archivos creados:  
	- RT_BoletinTrimestral_Datos.xlsx
* Propósito:
	- Éste archivo genera y exporta los cálculos de porcentajes de trabajadores capacitados agrupados por tipo de formalidad
*********************************************************************************************/

******************************
* (1): Definimos directorios *
******************************
/* (1.1): Definimos el directorio en donde se encuentra la base de datos que utilizaremos y donde estará el excel que exportemos. */
gl docs  = "$root"

********************************************
* (2): Generación de variables importantes *
********************************************
/* (2.1): Seleccionamos base de datos a utilizar. */
use "$oldroot\ENOE_Base Global_Dinamica.dta", clear

/* (2.2): Seleccionamos el periodo a trabajar. */
keep if yeartrim<201		/* Para cálcular el promedio de 2006-2019 */
*keep if yeartrim==194 		/* Para cálcular el promedio del 4T 2019 */

/* (2.2): Nos quedamos con la PEA con, ya sea empleo formal o informal*/
keep if clase1fin == 1
drop if emp_ppal1 == 0 | emp_ppal2 == 0

decode ent, gen(nombres)
replace nombres = "Ciudad de México" if nombres == "Distrito Federal"


/* (2.3): Variable indicando si recibieron capacitacion (con variante laxa). */
gen byte capacitacion_lax = .
replace capacitacion_lax = p9_1 if p11_1==.
replace capacitacion_lax = p11_1 if p9_1==.
replace capacitacion_lax = 1 if p1c==4
replace capacitacion_lax = 0 if capacitacion_lax==.

/* (2.4): Variable de transición en el tipo de empleo. */
gen trans_empleo = .
replace trans_empleo = 1 if emp_ppal1 == 1 & emp_ppal2 == 1 // 1, si siempre tuvo empleo formal
replace trans_empleo = 2 if emp_ppal1 == 2 & emp_ppal2 == 1 // 2, si consiguió empleo formal
replace trans_empleo = 3 if emp_ppal1 == 1 & emp_ppal2 == 2 // 3, si perdió empleo formal
replace trans_empleo = 4 if emp_ppal1 == 2 & emp_ppal2 == 2 // 4, si siempre tuvo empleo formal


***************************************
* (3) Obtenemos la información promedio para el país y para todos los estados
***************************************
/*Definimos a dónde exportaremos los datos. */
putexcel set "$oldroot\Entidades Federativas\RT_BoletinTrimestral_Estados.xlsx", sheet("2.1. CAPACITACION Formalidades") modify


*Generamos la matriz de ouptut
capture rename fac factor
quietly tab ent
scalar st = r(r)
mat output_matrix = J(st+1,16,0)

*Calculamos los 4 valores de capacitación para cada tipo de empleo, y añadimos a la matriz output
scalar counter = 0
levelsof trans_empleo, local(formal)
foreach f of local formal{
	qui tab yeartrim capacitacion_lax [fw = factor] if trans_empleo == `f', column matcell(cap_nac)
	svmat cap_nac
	gen tot_nac = cap_nac1 + cap_nac2
	gen porc_cap_nac = cap_nac2 / tot_nac
	
	qui sum tot_nac
	mat output_matrix[1, `f' + `=counter'] = r(mean)	//Agregamos el valor de cada tipo de empleo para el total de trabajadores
	qui sum cap_nac2
	mat output_matrix[1, `f' + `=counter' + 1] = r(mean) 	//Agregamos el valor para cada tipo de empleo de el total de trabajadores con capacitación
	qui sum cap_nac1
	mat output_matrix[1,`f' + `=counter' + 2] = r(mean)	//Agregamos el valor para cada tipo de empleo de el total de trabajadores sin capacitación
	qui sum porc_cap_nac
	mat output_matrix[1,`f' + `=counter' + 3] = r(mean)	//Agregamos el valor para cada tipo de empleo del porcentaje de trabajadores con capacitación
	
	drop cap_nac1 cap_nac2 tot_nac porc_cap_nac
	scalar counter = counter + 3
}


*Calculamos para cada entidad
levelsof ent, local(estado)

foreach i of local estado{
	di "Trabajando para estado `i'"
	scalar counter = 0
	foreach f of local formal{
		qui tab yeartrim capacitacion_lax [fw = factor] if trans_empleo == `f' & ent == `i', column matcell(cap_ent)
		svmat cap_ent
		gen tot_ent = cap_ent1 + cap_ent2
		gen porc_cap_ent = cap_ent2 / tot_ent
		
		qui sum tot_ent
		mat output_matrix[`i'+1,`f' + `=counter'] = r(mean)	//Total de trabajadores
		
		qui sum cap_ent2
		mat output_matrix[`i'+1,`f' + `=counter' + 1] = r(mean)	//Total de trabajadores con capacitación
		
		qui sum cap_ent1
		mat output_matrix[`i'+1,`f' + `=counter' + 2] = r(mean)	//Total de trabajadores sin capacitación
		
		qui sum porc_cap_ent
		mat output_matrix[`i'+1,`f' + `=counter' + 3] = r(mean)	//Porcentaje de trabajadores con capacitación
		
		drop cap_ent1 cap_ent2 tot_ent porc_cap_ent
		scalar counter = counter + 3
	}
	scalar drop counter
	
	levelsof nombres if ent == `i', local(nombre)
	local a=`i' + 3
	putexcel B`a' = (`nombre')
}

***************************************
* (4) Escribimos los resultados en la hoja de Excel
***************************************

putexcel C3=matrix(output_matrix)
putexcel B3=("Nacional") 

putexcel C1=("Trabajadores que siempre tuvieron empleo formal")
putexcel C2=("Total de trabajadores")
putexcel D2=("Número de trabajadores con capacitación")
putexcel E2=("Número de trabajadores sin capacitación")
putexcel F2=("Porcentaje de trabajadores con capacitación")

putexcel G1=("Trabajadores que obtuvieron empleo formal")
putexcel H2=("Total de trabajadores")
putexcel H2=("Número de trabajadores con capacitación")
putexcel I2=("Número de trabajadores sin capacitación")
putexcel J2=("Porcentaje de trabajadores con capacitación")

putexcel K1=("Trabajadores que perdieron empleo formal")
putexcel K2=("Total de trabajadores")
putexcel L2=("Número de trabajadores con capacitación")
putexcel M2=("Número de trabajadores sin capacitación")
putexcel N2=("Porcentaje de trabajadores con capacitación")

putexcel O1=("Trabajadores que nunca tuvieron empleo formal")
putexcel O2=("Total de trabajadores")
putexcel P2=("Número de trabajadores con capacitación")
putexcel Q2=("Número de trabajadores sin capacitación")
putexcel R2=("Porcentaje de trabajadores con capacitación")
