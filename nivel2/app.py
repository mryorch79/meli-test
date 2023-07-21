# importo dependencias
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, explode, date_format, struct, collect_list
from pyspark.sql.types import StringType, ArrayType, MapType, IntegerType, TimestampType, StructType, StructField
from flask import Flask, request, Response
import os, json, urllib, re, redis, logging


flask_host = os.environ.get("FLASK_HOST","0.0.0.0")
flask_port = os.environ.get("FLASK_PORT",7080)
redis_host = os.environ.get("REDIS_HOST","127.0.0.1")
redis_port = os.environ.get("REDIS_PORT",6379)

# iniciando conexion a Redis
logging.info("initiating redis")
r = redis.Redis(host=redis_host, port=int(redis_port), decode_responses=True)

# iniciando contexto spark
logging.info("initiating spark context")
spark = SparkSession \
    .builder \
    .appName("testing") \
    .getOrCreate()

parquet_name="data"

# funcion para ejecutar el parser del campo experiment, dado que csv solo soporta tipos nativos
def parser(value):
    json_str = value.replace(" ", "").replace("{", "{\"").replace("}", "\"}").replace("=", "\":\"").replace(",", "\",\"")
    return json.loads(json_str)

# funcion para sumar los participantes
def participants(value):
    return sum(count for variant, count in value)

# funcion para sumar los ordenar y contar los experimentos con mas participantes
def winner(value):
    return sorted([(variant,count) for variant, count in value], key=lambda x: x[1], reverse=True)[0][0]

# funcion para generar un json con el formato json de las variantes
def variants_string(value):
    return [{"id":variant, "number_of_purchases":count} for variant, count in value]

# funcion que inicializa el archivo y lo convierte en un parquet con las funciones requeridas
def init():
    logging.info("converting file")
    parser_udf = udf(parser, MapType(StringType(), StringType()))
    participants_udf = udf(participants, IntegerType())
    winner_udf = udf(winner, StringType())
    variants_string_udf = udf(variants_string, ArrayType(MapType(StringType(),StringType())))
    data_path = "../data/data.csv"
    schema = StructType([
        StructField('event_name', StringType(), True),
        StructField('item_id', IntegerType(), True), 
        StructField('timestamp', TimestampType(), True), 
        StructField('site', StringType(), True), 
        StructField('experiments', StringType(), True), 
        StructField('user_id', IntegerType(), True), 
    ])
    data = spark.read.schema(schema).option("header","true").csv(data_path)
    new_data = data.withColumn("parsed_experiments",parser_udf("experiments"))
    new_data = new_data.select(*schema.fieldNames(), explode("parsed_experiments").alias("experiment_id","version_id"))
    
    result = new_data.withColumn("day",date_format('timestamp','yyyy-MM-dd HH')).groupBy("day","event_name","experiment_id", "version_id").count()
    result = result.groupBy("day","event_name","experiment_id").agg(collect_list(struct("version_id","count")).alias("variant"))
    result = result.withColumn("number_of_participants",participants_udf("variant")).withColumn("winner",winner_udf("variant")).withColumn("variants",variants_string_udf("variant"))
    result.write.mode("overwrite").parquet(parquet_name)

# funcion para validar el pattern de la fecha yyyy-MM-dd HH
def validate_date_format(day):
    pattern = r'^\d{4}-\d{2}-\d{2} \d{2}$'
    if re.match(pattern, day):
        return True
    else:
        return False
    
# objecto con formato de respuestas
responses = {
    "ok": lambda message: Response(message, status=200, mimetype='application/json'),
    "bad_request": lambda message: Response(message, status=400, mimetype='plain/text'),
    "not_found":  lambda message: Response(message, status=404, mimetype='plain/text'),
    "unknown": lambda message: Response(message, status=500, mimetype='plain/text')
}

#app flask
app = Flask(__name__)

#funcion que expone el path experiment
@app.route('/experiment/<path:id>/result', methods=['GET'])
def get_experiment(id):
    try:
        day = urllib.parse.unquote(request.args['day'], encoding='utf-8', errors='replace')
        logging.info("id recibido:", id)
        logging.info("day recibido:", day)
        if not validate_date_format(day):
            logging.error("error en fecha")
            return responses["bad_request"]("bad date format")
        cache = r.get(id+day)
        if cache:
            logging.info("response found in cache")
            return responses["ok"](cache) 
        logging.info("response not found in cache")
        data = spark.read.parquet(parquet_name)
        result = data.where(f"experiment_id='{id}' and day='{day}'").select("number_of_participants", "winner", "variants")
        if result.count() == 0:
            return responses["not_found"]("experiment not found")
        response = json.dumps({
                "results":{
                    id:[json.loads(exp) for exp in result.toJSON().collect()]
                }
            })
        r.set(id+day, response)
        r.expire(id+day, 60)
        return responses["ok"](response)
    except Exception as e:
        logging.error(str(e))
        return responses["unknown"](str(e))


#metodo main
if __name__ == '__main__':
    init()
    app.run(host=flask_host, port=int(flask_port))