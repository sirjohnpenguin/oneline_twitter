#!/bin/bash

#
# Get the latest tweets from your account.
#
# This script is based on a solution proposed by Mike Bounds
#  in the twitter discussion forum: https://dev.twitter.com/discussions/14460


# 
# Modified to show timeline, mentions, ¿etc?
# Requeriments: 
# 
# curl, openssl
# jq http://stedolan.github.io/jq/ 
#
##############


# set timezone (usr/shared/timezone)
timezone=env TZ=America/Argentina

# twitterv2.sh data_dir
data_dir=$HOME/oneline_twitter

# config location
config_file=$data_dir/oneline.conf

# mentions cache 
mentions_cache=$data_dir/mentions.cache

# timeline cache
timeline_cache=$data_dir/timeline.cache

# jq path
JQ_PATH=$HOME/oneline_twitter/jq

# the number of tweets you want to retrieve (by default, use -c option to change it)
tweet_count=20

# check every x seconds (3 minutes)
check_in_seconds=180

# twitter app data
consumer_key=''
consumer_secret=''
oauth_token=''
oauth_secret=''




#
#
#
#
#

######
# Funciones
#######


# fecha actual en formato unix
timestamp=`date +%s`

# funcion para chequear que exista el archivo de configuracion
# si no existe, lo crea...y se va.
crear_variables_inicio(){

if [ ! -f $config_file ]; then
	#echo "El archivo \"$data_dir/twitterv2.variables.file\" no existe...creando uno nuevo."
	touch $config_file
	echo 'LAST_CHECK_T='"$(($timestamp - $check_in_seconds))"'' >> $config_file
	echo 'LAST_CHECK_M='"$(($timestamp - $check_in_seconds))"'' >> $config_file

	echo 'LAST_SEEN_T="425363230551470080"' >> $config_file
	echo 'LAST_SEEN_M="425363230551470080"' >> $config_file


	echo 'LATEST_TWEET_T="LATEST_TWEET_T"' >> $config_file
	echo 'LATEST_TWEET_M="LATEST_TWEET_M"' >> $config_file

fi

}

# funcion para borrar variables del archivo
# para evitar que se agreguen dos variables iguales
# antes las borramos.
borrar_variable(){
if [ ! -f $config_file ]; then
	#echo "File not found!"
exit
fi

n=$RANDOM
archivo_variables=`cat $config_file | grep -v "$1" $config_file > $n.temp && mv $n.temp $config_file`

}


# funcion para agregar variables al arhivo
# LATEST_TWEET_T y LATEST_TWEET_M van con comillas simples
agregar_variable(){
if [ ! -f $config_file ]; then
	#echo "File not found!"
exit
fi

case $1 in
LAST_CHECK_T) echo $1='"'"$2"'"'  >> $config_file ;; # ultima conexion al api (timeline)
LAST_CHECK_M) echo $1='"'"$2"'"'  >> $config_file ;; # ultima conexion al api (mentions)
LAST_SEEN_T) echo $1='"'"$2"'"'  >> $config_file ;; # id_str del ultimo tweet visto (timeline)
LAST_SEEN_M) echo $1='"'"$2"'"'  >> $config_file ;; # id_str del ultimo tweet visto (mentions)

# ultimo tweet (completo)
LATEST_TWEET_T) echo $1=''\'"$2"''\'  >> $config_file ;; # comillas simples
LATEST_TWEET_M) echo $1=''\'"$2"''\'  >> $config_file ;; # para las cadenas

*) echo "emmm" ;; # algo se rompio, chauuuu
esac

}


# funcion para crear la llamada a twitter
# desde curl.

get_nonce(){
	timestamp=`date +%s`
	nonce=`date +%s%T555555555 | openssl base64 | sed -e s'/[+=/]//g'`
}


# funcion para chequear cuando fue
# la ultima vez que se actualizo el cache
# y no conectarnos al pedo a la api de twitter
get_last_check(){
case $1 in
mentions)
if [ $(($LAST_CHECK_M + $check_in_seconds)) -gt $timestamp ];then
return 1
else
return 0
fi
;;
timeline)
if [ $(($LAST_CHECK_T + $check_in_seconds)) -gt $timestamp ];then
return 1
else
return 0
fi
;;
*)
echo "mmmm"
exit
esac
}



# funcion para obtener el timeline y las funciones
# 'get_tweets mentions' para las menciones
# 'get_tweets timeline' para el timeline
get_tweets(){
get_nonce


case $1 in
mentions)

signature_base_string_mentions="GET&https%3A%2F%2Fapi.twitter.com%2F1.1%2Fstatuses%2Fmentions_timeline.json&count%3D${tweet_count}%26oauth_consumer_key%3D${consumer_key}%26oauth_nonce%3D${nonce}%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D${timestamp}%26oauth_token%3D${oauth_token}%26oauth_version%3D1.0"
signature_key_mentions="${consumer_secret}&${oauth_secret}"
oauth_signature_mentions=`echo -n ${signature_base_string_mentions} | openssl dgst -sha1 -hmac ${signature_key_mentions} -binary | openssl base64 | sed -e s'/+/%2B/' -e s'/\//%2F/' -e s'/=/%3D/'`

header_mentions="Authorization: OAuth oauth_consumer_key=\"${consumer_key}\", oauth_nonce=\"${nonce}\", oauth_signature=\"${oauth_signature_mentions}\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"${timestamp}\", oauth_token=\"${oauth_token}\", oauth_version=\"1.0\""

# me fijo si es hora de conectarme a la api de twitter
if  get_last_check mentions ; then 
	result=`eval curl --silent --get 'https://api.twitter.com/1.1/statuses/mentions_timeline.json' --data \""count=${tweet_count}\"" --header \""Content-Type: application/x-www-form-urlencoded\"" --header \""${header_mentions}\""` 
	
	# devuelvo los datos obtenidos, pero en reversa...para consultarlos
	# mas facilmente....eso creo (?)
	result=`echo $result | $JQ_PATH 'reverse'`
	
	# lo guardo en el cache, para mas tarde	
	echo $result > $data_dir/mentions.cache

	# actualizo la hora del ultimo chequeo
	borrar_variable "LAST_CHECK_M"
	agregar_variable "LAST_CHECK_M" $timestamp
else
	# si no es hora de conectarse a twitter, 
	# uso el archivo que guarde antes	
	echo `cat $data_dir/mentions.cache`
	exit 
	fi
;;

timeline)

signature_base_string_timeline="GET&https%3A%2F%2Fapi.twitter.com%2F1.1%2Fstatuses%2Fhome_timeline.json&count%3D${tweet_count}%26oauth_consumer_key%3D${consumer_key}%26oauth_nonce%3D${nonce}%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D${timestamp}%26oauth_token%3D${oauth_token}%26oauth_version%3D1.0"

signature_key_timeline="${consumer_secret}&${oauth_secret}"

oauth_signature_timeline=`echo -n ${signature_base_string_timeline} | openssl dgst -sha1 -hmac ${signature_key_timeline} -binary | openssl base64 | sed -e s'/+/%2B/' -e s'/\//%2F/' -e s'/=/%3D/'`

header_timeline="Authorization: OAuth oauth_consumer_key=\"${consumer_key}\", oauth_nonce=\"${nonce}\", oauth_signature=\"${oauth_signature_timeline}\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"${timestamp}\", oauth_token=\"${oauth_token}\", oauth_version=\"1.0\""

# me fijo si es hora de conectarme a la api de twitter
if  get_last_check timeline ; then
	result=`eval curl  --silent --get 'https://api.twitter.com/1.1/statuses/home_timeline.json' --data "\"count=${tweet_count}\"" --header "\"Content-Type: application/x-www-form-urlencoded\"" --header "\"${header_timeline}\""` 
	
	# devuelvo los datos obtenidos, pero en reversa...para consultarlos
	# mas facilmente....eso creo (?)
	result=`echo $result | $JQ_PATH 'reverse'`

	# lo guardo en el cache, para mas tarde	
	echo $result > $data_dir/timeline.cache

	# actualizo la hora del ultimo chequeo
	borrar_variable "LAST_CHECK_T"
	agregar_variable "LAST_CHECK_T" $timestamp
else
	# si no es hora de conectarse a twitter, 
	# uso el archivo que guarde antes	
	echo `cat $data_dir/timeline.cache`
	exit 
	fi
;;

*)
echo "emmmm" # aca se pudre todo....y me voy al joraca
exit
esac

# si hay un error con curl, problemas de red ponele
# muestro el error y me voy.
err=$?
if [ $err -ne 0 ]; then echo "cURL error code $err"; exit 1;fi
echo $result


}



#######
# Programa (?)
########

# creo el archivo de variables si es que no existe
crear_variables_inicio

# si existe, lo cargo
source $config_file # archivo con variables.



# linea de comando
# -m Menciones
# -t Timeline
# -c cantidad de tweets (20 o 40 cada 3 minutos)

while getopts c:tm flag; do
case $flag in

	c)
        	tweet_count=$OPTARG # cantidad de tweets
		;;
	t)
		a=0 # Menciones
		;;
	m)
		a=1 # Timeline
		;;
	*)
        	echo "uso: $0  -m (mentions) -t(timeline) -c(count)"
		exit
	esac
done

# si no se seteo el valor de $a, me voy al joraca.
# pero antes muestro la ayuda
if [ -z ${a+x} ]; then echo "uso: $0  -m (mentions) -t(timeline) -c(count)";exit; fi

# si $a es igual a 1, muestro las menciones
# si es igual a 0, muestro el timeline
if [ $a -eq 1 ]; then result=`get_tweets mentions`;elif [ $a -eq 0 ]; then result=`get_tweets timeline`;else echo "uso: $0  -m (mentions) -t(timeline) -c(count)"; exit; fi

# primero me fijo si hay una cadena
# que se llame '{"errors":'
# en la salida JSON
errores=`echo $result | grep -e '{"errors":'`

# si existe, imprimo el error
# y....me voy al joraca
if [[ -n $errores ]];then 
error_message=`echo $result | $JQ_PATH  '.errors' | $JQ_PATH -r '.[].message'`
error_code=`echo $result | $JQ_PATH  '.errors' | $JQ_PATH -r '.[].code'`
echo "Twitter API error: $error_message ($error_code)"
exit
fi

# contador a cero
COUNTER=0

# mientras el contador sea menor a la cantidad de tweets
# los voy procesando en un loop
while [  $COUNTER -lt $tweet_count ]; do
	
	
	id_str=`echo $result  |   $JQ_PATH  -r '.['$COUNTER'].id_str' `
	
	# si id_str tiene 'null' como valor, me voy al joraca
	# y muestro el ultimo tweet guardado	
	if [[ $id_str == "null" ]]; then empty=1; break;exit;fi		


	# si el id_str es menor o igual al almacenado
	# tambien me voy al joraca y muestro el tweet guardado
	if [ $a -eq 0 ]; then
		if [ $id_str -le $LAST_SEEN_T ] ;then ((COUNTER+=1));empty=1;continue;fi
	fi
	if [ $a -eq 1 ]; then
		if [ $id_str -le $LAST_SEEN_M ] ;then ((COUNTER+=1));empty=1;continue;fi
	fi			
	



	# empiezo a crear la cadena a mostrar
	# [screen_name] tweet (fecha)
	screen_name=`echo $result  |  $JQ_PATH -r '.['$COUNTER'].user.screen_name'`
	text=`echo $result  |  $JQ_PATH -r '.['$COUNTER'].text'`
	date=`echo $result  |  $JQ_PATH -r '.['$COUNTER'].created_at'`
	
	# creo la fecha simple, como en la web de twitter	
	unix_date=`date --utc --date "$date" +%s`
	gmt_time=`$timezone date -d @$unix_date`
        starttime=$(date +%s)
	elapse=$(($starttime - $unix_date))




	#sumo uno al contador
	((COUNTER+=1))	
	# aca armo la fecha con el formato como en la web de twitter
	if [ $elapse -gt 2678400 ]; then
		nice_date="hace $(($elapse / 2678400)) mes."
		if [ $(($elapse / 2678400)) -gt 1 ];then nice_date="hace $(($elapse / 2678400)) meses.";fi
			elif [ $elapse -gt 86400 ];then
		nice_date="hace $(($elapse / 86400)) dia."
		if [ $(($elapse / 86400)) -gt 1 ];then nice_date="hace $(($elapse / 86400)) dias.";fi
			elif [ $elapse -gt 3600 ];then
			nice_date="hace $(($elapse / 3600)) hora."
		if [ $(($elapse / 3600)) -gt 1 ];then nice_date="hace $(($elapse / 3600)) horas.";fi	
			else
			nice_date="hace $(($elapse / 60 )) min."
		fi

	# finalmente armo la cadena a mostrar	
	cadena="[@$screen_name] $text ($nice_date)"

	# remove new line and single quotes
	# le quito la nueva linea y las comillas simples...por las dudas
	cadena=`echo $cadena |  sed -e "s/'/\\\'/g" | sed ':a;N;$!ba;s/\n/ /g'`  
	
	# muestro el tweet	
	echo $cadena
	
	# guardo el id_str y el tweet en una variable, para usar luego
	if [ $a -eq 1 ]; then
		borrar_variable "LAST_SEEN_M"	
		agregar_variable "LAST_SEEN_M" $id_str
		borrar_variable "LATEST_TWEET_M"	
		agregar_variable "LATEST_TWEET_M" "$cadena"
	else
		borrar_variable "LAST_SEEN_T"	
		agregar_variable "LAST_SEEN_T" $id_str
		borrar_variable "LATEST_TWEET_T"	
		agregar_variable "LATEST_TWEET_T" "$cadena"

	fi
	
		
	empty=0
	break


done

# si no encontro un tweet mas nuevo para mostrar
# muestro el ultimo que se vio

if [ $empty -eq 1 ] ;then

	if [ $a -eq 1 ]; then

		echo $LATEST_TWEET_M
	fi
	if [ $a -eq 0 ]; then
		echo $LATEST_TWEET_T
	fi	
fi	
