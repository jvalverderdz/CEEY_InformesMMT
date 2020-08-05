********************
version 15
clear all
set more off
cls
********************
 
/*********************************************************************************************
* Nombre archivo: 		RT_BoletinTrimestral_1.MasterDoAllFormalidad_Estados
* Autor:				Javier Valverde
* Propósito:
	- Éste archivo define el directorio global en donde se guardarán las bases de datos de 
	  cálculos por formalidad y corre el resto de las do files.
	  Es necesario correr el archivo antes que el resto.
*********************************************************************************************/

******************************
* (1): Definimos directorios *
******************************
/* (1.1): Definimos el directorio principal. */
gl root  = "D:\Javier\Documents\CEEY\3-BoletinTrimestral-MMT\Calculos\Entidades Federativas\Calculos_2"
/* (1.2): Cambiamos el directorio de trabajo. */
cd "$root"

/* (1.3): Definimos directorio previo. */
gl oldroot  = "D:\Javier\Documents\CEEY\3-BoletinTrimestral-MMT\Calculos"

**************************
* (2): Corremos do files *
**************************
*do "RT_BoletinTrimestral_3.TransCapacitacionFormalidad_Estados"
*cd "$root"
do "RT_BoletinTrimestral_4.MovIngresoFormalidad_Estados.do"

exit, clear

