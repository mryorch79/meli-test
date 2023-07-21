## Elaborado por Jorge Velandia

### Arquitectura de referencia
![Arq. referencia](./test-implemented.png "Arq referencia")

### Arquitectura implementada
![Arq. Implementada](./test-reference.png "Arq implementada")

# Nivel 1

La solucion se implemento en un libro de python usando pyspark para su analisis. Dados que el formato csv no permite obtener los datos con tipos de columna complejos, se usaron funciones de apoyo para este analisis

- Ingresar a ./nivel1
- Ejecutar ```pip install requirements -r requirements.txt(se puede ejecutar creando un virtual environment)```
- Cambiar el java_home en el libro notebook.ipynb
- Ejecutar notebook.ipynb con el mismo kernel de spark donde se encuentra instaldo pyspark


# Nivel 2

La solucion se implemento con python, usando pyspark para simular el "preprocesamiento de la carga" antes de serir peticiones, igualmente se usa redis para agregar un nivel de cache a la solucion. 

- Ingresar a ./nivel1
- Ejecutar ```docker build -t service . ``` para construir la imagen
- Ejecutar ```docker run -p 7080:7080 service``` para subir el servicio
- - Esperar que el servicio suba, iniciando, el servicio va a convertir el archivo por lo cual tomara unos segundos
- Ejecutar ```http://localhost:7080/experiment/<<:id>>/result?day=YYYY-MM-DD+HH"```
- - por ejemplo ```http://localhost:7080/experiment/mclics/show-pads-search-list/result?day=2021-08-02+06"```

# Nivel 3

Se usa terraform para desplegar en aws, para hacer las cosas sencillas solo se despliega el docker en una instancia ec2. Por temas de seguridad y costos la solucion solo se desplegara en el momento de una demo.

- Ingresar a ./nivel3
- hacer set de la variable de entorno 
- ejecutar terraform plan / apply
- probar en ```http://<<ec2-url>>/experiment/<<:id>/result/day=YYYY-MM-DD+HH```


# Consideraciones y recomendaciones

- Si la carga es poco predecible (entre 100 y 1 millon) las arquitecturas serverless pueden ayudar a reducir costos y soportar carga, mientras se tienen datos suficientes para predecirla
- Una vez se tenga determinada la carga se pueden crear clusteres estaticos con la elasticidad requerida
- Usar bases de datos de cache como Redis, puede ayudar a reducir la latencia y las peticiones contra la fuente de datos
- Dada que los datos no se encuentran en un formato optimo para una actividad transaccional, se recomienda un procesamiento previo que los aliste mediante un servicio de streaming en caso de ser online o un proceso ETL en caso que la fuente sea batch
- Se recomienda uso de API gateway para brindar una capa de administracion y seguridad adicional
- Se recomienda el uso de formato parquet en lugar de csv para mejorar rendimiento y poder procesar de mejor manera algunos datos de tipo complejo
