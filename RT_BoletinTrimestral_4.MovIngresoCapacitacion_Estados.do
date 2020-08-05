********************
version 15
clear all
set more off
cls
********************
 
/*********************************************************************************************
* Nombre archivo: 		RT_BoletinTrimestral_4.MovIngresoCapacitacion_Estados.do
* Autor:          		Javier Valverde
* Archivos usados:     
	- ENOE_Base Global_Dinamica.dta
* Archivos creados:  
	- RT_BoletinTrimestral_Datos.xlsx
* Propósito:
	- Éste archivo genera y exporta los cálculos de movilidad en ingreso segmentados
	  por si recibieron capacitación o no
*********************************************************************************************/

******************************
* (1): Definimos directorios *
******************************
/* (1.1): Definimos el directorio en donde se encuentra la base de datos que utilizaremos y donde estará el excel que exportemos. */
*gl docs  = "$oldroot"
gl docs = "D:\Javier\Documents\CEEY\3-BoletinTrimestral-MMT\Calculos"
gl oldroot = "D:\Javier\Documents\CEEY\3-BoletinTrimestral-MMT\Calculos"


*******************************
* (2): Importar datos de INPC *
*******************************
/* (2.1): Creamos directorio temporal y cambiamos directorio actual. */
capture mkdir "$docs/INPC"
cd "$docs/INPC"

/* (2.2): Descargamos e importamos base de datos INPC. */
copy "https://www.inegi.org.mx/contenidos/programas/inpc/2018/datosabiertos/inpc_indicador_mensual_csv.zip" inpc_indicador_mensual_csv.zip
unzipfile inpc_indicador_mensual_csv.zip
import delimited "$docs\INPC\conjunto_de_datos\conjunto_de_datos_inpc_mensual.csv", encoding(ISO-8859-1)
tempfile inpc
save "`inpc'", replace

/* (2.3): Revisamos tipo de sistema operativo y borramos carpeta. */
if c(os) == "MacOSX" {
	shell rm -r "$docs/INPC/"
} 
else {
	shell rd "$docs/INPC/" /s /q
}

/* (2.4): Encontramos mes de INPC. */
rename fecha fechas
gen mes = substr(fechas,7,2)
destring mes, replace
keep if concepto=="Ãndice nacional de precios al consumidor (mensual), Resumen, SubÃ­ndices subyacente y complementarios, Precios al Consumidor (INPC)"

keep if mes==3 | mes==6 | mes==9 | mes==12
keep valor fechas mes

/* (2.5): Generamos variables con las que se harán merge. */
gen year = substr(fechas,4,2)
gen byte trim = mes/3
egen int yeartrim = concat(year trim)
rename valor INPC_4t

/* (2.5): Calculamos INPC con lag. */
destring yeartrim, replace
gen int yeartrim_lag = .
replace yeartrim_lag = yeartrim - 9
replace yeartrim_lag = yeartrim_lag + 6 if real(substr(string(yeartrim_lag), 2,1))==5 & yeartrim_lag<102
replace yeartrim_lag = yeartrim_lag + 6 if real(substr(string(yeartrim_lag), 3,1))==5 & yeartrim_lag>100
save "`inpc'", replace

tempfile lag
drop yeartrim_lag
rename yeartrim yeartrim_lag
rename INPC_4t INPC_1t
save "`lag'", replace

use "`inpc'", clear
merge 1:1 yeartrim_lag using "`lag'"
drop _merge
keep if yeartrim_lag > 24 & INPC_4t!= .

order yeartrim INPC_1t INPC_4t
rename mes month
rename trim trimestre
rename year anyo
save, replace

*******************************************
* (3): Generación de variables importantes *
********************************************
/* (3.1): Seleccionamos base de datos a utilizar. */
use "$oldroot/ENOE_Base Global_Dinamica.dta", clear

/* (3.2): Seleccionamos el periodo a trabajar. */
keep if yeartrim<201 		/* Para cálcular el promedio de 2006-2019 */
*keep if yeartrim==194 		/* Para cálcular el promedio del 4T 2019 */

/* (3.3): Hacemos merge con base de datos INPC para deflactar */
* Hacemos merge
capture drop _merge
sort yeartrim
merge m:1 yeartrim using "`inpc'"
keep if _merge==3
drop _merge fechas month anyo trimestre

* Ahora deflactamos
gen double defl = INPC_4t/INPC_1t
replace ingocup2 = ingocup2/defl

* Hacemos transformación de ingresos
gen double ln_ingocup2 = .
replace ln_ingocup2 = log(ingocup2) if ingocup1!=0 & ingocup2!=0
gen double ln_ingocup1 = .
replace ln_ingocup1 = log(ingocup1) if ingocup1!=0 & ingocup2!=0


/* (3.4): Generamos indicador de movilidad individual */
gen double ImInd = .
replace ImInd = ln_ingocup2-ln_ingocup1 if ingocup1!=0 & ingocup2!=0


*Desechamos si alguno de los periodos no aplica:
drop if emp_ppal1 == 0 | emp_ppal2 == 0

decode ent, gen(nombres)
replace nombres = "Ciudad de México" if nombres == "Distrito Federal" //Cambiamos DF por CDMX

/* Variable indicando si recibieron capacitacion (con variante laxa). */
gen byte capacitacion_lax = .
replace capacitacion_lax = p9_1 if p11_1==.
replace capacitacion_lax = p11_1 if p9_1==.
replace capacitacion_lax = 1 if p1c==4
replace capacitacion_lax = 0 if capacitacion_lax==.

*Cambiamos los valores de capacitacion_lax por 1 y 2 para usarla como indicador en la columna de la matriz output más adelante
replace capacitacion_lax = 2 if capacitacion_lax == 1
replace capacitacion_lax = 1 if capacitacion_lax == 0


*******************************************
* (4): Calcular variables de interés nacionales y por estado por cada tipo de capacitación
********************************************

*Generamos la matriz de ouptut
capture rename fac factor
quietly tab ent
scalar st = r(r)
mat output_matrix = J(st+1,14,0)

*Calculamos los 7 valores de movilidad de ingreso para cada tipo de capacitación, y añadimos a la matriz output

*Calculo para el valor Nacional
scalar counter = 0
levelsof capacitacion_lax, local(cptcn)
capture gen double ImIndExp = ImInd*factor
foreach f of local cptcn{
	gen long TOTcmovAsc`f' = .
	gen long TOTcmovDes`f' = .
	gen long TOTcmovNul`f' = .
	capture gen byte hola = 1
	
	qui sum ImInd if capacitacion_lax == `f' & ImInd > 0 & ImInd !=. [fw = factor]
	replace TOTcmovAsc`f' = r(sum_w) if capacitacion_lax == `f'
	
	qui sum ImInd if capacitacion_lax == `f' & ImInd < 0 [fw = factor]
	replace TOTcmovDes`f' = r(sum_w) if capacitacion_lax == `f'
	
	qui total hola if capacitacion_lax ==`f' & ImInd==. [fw=factor]
	replace TOTcmovNul`f' = e(N) if capacitacion_lax == `f'
	
	gen TOTtotalobs`f' = .
	replace TOTtotalobs`f' = TOTcmovAsc`f' + TOTcmovDes`f' + TOTcmovNul`f' if capacitacion_lax == `f'
	gen TOTpctmovAsc`f' = .
	replace TOTpctmovAsc`f' = TOTcmovAsc`f' / TOTtotalobs`f' if capacitacion_lax == `f'
	gen TOTpctmovDes`f' = .
	replace TOTpctmovDes`f' = TOTcmovDes`f' / TOTtotalobs`f' if capacitacion_lax == `f'
	gen TOTpctmovNul`f' = .
	replace TOTpctmovNul`f' = TOTcmovNul`f' / TOTtotalobs`f' if capacitacion_lax == `f'
	
	*Agregamos todo a la matriz
	qui sum TOTtotalobs`f' [fw = factor]
	mat output_matrix[1, `f' + `=counter'] = r(mean)
	
	qui sum TOTpctmovAsc`f' [fw = factor]
	mat output_matrix[1, `f' + `=counter' + 1] = r(mean)
	qui sum ImInd if ImInd>0 & ImInd != . & capacitacion_lax == `f' [fw=factor]
    mat output_matrix[1, `f' + `=counter' + 2] = r(mean)
	
	qui sum TOTpctmovDes`f' [fw = factor]
	mat output_matrix[1, `f' + `=counter' + 3] = r(mean)
	qui sum ImInd if ImInd<0 & capacitacion_lax == `f' [fw=factor]
    mat output_matrix[1, `f' + `=counter' + 4]= r(mean)
	
	qui sum TOTpctmovNul`f' [fw = factor]
	mat output_matrix[1, `f' + `=counter' + 5] = r(mean)
	qui sum ImInd if capacitacion_lax == `f' [fw=factor]
    mat output_matrix[1, `f' + `=counter' + 6] = r(mean)
	
	scalar counter = counter + 6
	drop TOTcmovAsc`f' TOTcmovDes`f' TOTcmovNul`f' TOTtotalobs`f' TOTpctmovAsc`f' TOTpctmovDes`f' TOTpctmovNul`f'
}


*Calculo para cada estado
levelsof ent, local(estado)

putexcel set "$oldroot\Entidades Federativas\RT_BoletinTrimestral_Estados.xlsx", sheet("3.2. Mov. INGRESO Capacitacion") modify

foreach i of local estado {
	di "Trabajando para estado `i'"
	scalar counter = 0
	preserve
	
	drop if ent!=`i'

	foreach f of local cptcn{
		gen long ENTcmovAsc`f' = .
		gen long ENTcmovDes`f' = .
		gen long ENTcmovNul`f' = .
		capture gen byte hola = 1
		
		qui sum ImInd if capacitacion_lax == `f' & ImInd > 0 & ImInd !=. [fw = factor]
		replace ENTcmovAsc`f' = r(sum_w) if capacitacion_lax == `f'
		
		qui sum ImInd if capacitacion_lax == `f' & ImInd < 0 [fw = factor]
		replace ENTcmovDes`f' = r(sum_w) if capacitacion_lax == `f'
		
		qui total hola if capacitacion_lax ==`f' & ImInd==. [fw=factor]
		replace ENTcmovNul`f' = e(N) if capacitacion_lax == `f'
		
		gen ENTtotalobs`f' = .
		replace ENTtotalobs`f' = ENTcmovAsc`f' + ENTcmovDes`f' + ENTcmovNul`f' if capacitacion_lax == `f'
		gen ENTpctmovAsc`f' = .
		replace ENTpctmovAsc`f' = ENTcmovAsc`f' / ENTtotalobs`f' if capacitacion_lax == `f'
		gen ENTpctmovDes`f' = .
		replace ENTpctmovDes`f' = ENTcmovDes`f' / ENTtotalobs`f' if capacitacion_lax == `f'
		gen ENTpctmovNul`f' = .
		replace ENTpctmovNul`f' = ENTcmovNul`f' / ENTtotalobs`f' if capacitacion_lax == `f'
	
	
		*Agregamos todo a la matriz
		qui sum ENTtotalobs`f' [fw = factor]
		mat output_matrix[`i' + 1, `f' + `=counter'] = r(mean)
		
		qui sum ENTpctmovAsc`f' [fw = factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 1] = r(mean)
		qui sum ImInd if ImInd>0 & ImInd != . & capacitacion_lax == `f' [fw=factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 2] = r(mean)
		
		qui sum ENTpctmovDes`f' [fw = factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 3] = r(mean)
		qui sum ImInd if ImInd<0 & capacitacion_lax == `f' [fw=factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 4]= r(mean)
		
		qui sum ENTpctmovNul`f' [fw = factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 5] = r(mean)
		qui sum ImInd if capacitacion_lax == `f' [fw=factor]
		mat output_matrix[`i' + 1, `f' + `=counter' + 6] = r(mean)
		
		scalar counter = counter + 6
		drop ENTcmovAsc`f' ENTcmovDes`f' ENTcmovNul`f' ENTtotalobs`f' ENTpctmovAsc`f' ENTpctmovDes`f' ENTpctmovNul`f'
	}
	levelsof nombres, local(nombre)
	local a=`i' + 3
	putexcel B`a' = (`nombre')
	
	
	restore
}

**Agregamos todo a Excel
putexcel C3=matrix(output_matrix)
putexcel B3=("Nacional")

putexcel C1=("Trabajadores que recibieron Capacitación")
putexcel C2=("Total de observaciones")
putexcel D2=("Porcentaje de ascenso")
putexcel E2=("Promedio de ascenso")
putexcel F2=("Porcentaje de descenso")
putexcel G2=("Promedio de descenso")
putexcel H2=("Porcentaje sin cambio")
putexcel I2=("Promedio general")

putexcel J1=("Trabajadores que no recibieron Capacitación")
putexcel J2=("Total de observaciones")
putexcel K2=("Porcentaje de ascenso")
putexcel L2=("Promedio de ascenso")
putexcel M2=("Porcentaje de descenso")
putexcel N2=("Promedio de descenso")
putexcel O2=("Porcentaje sin cambio")
putexcel P2=("Promedio general")
