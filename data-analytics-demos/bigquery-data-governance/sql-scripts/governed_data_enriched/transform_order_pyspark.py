from pyspark.sql import SparkSession
from pyspark.sql.functions import first, col, concat, lit
from pyspark.sql.functions import to_timestamp, date_format, from_unixtime


# Create a SparkSession
spark = SparkSession.builder.appName("OrderEnricher").getOrCreate()

# Read the source table
customer_transaction_df = spark.read.format("bigquery") \
  .option("table", "${project_id}.${bigquery_governed_data_raw_dataset}.customer_transaction") \
  .load()

# Create order header table
order_header_df = customer_transaction_df.groupBy("customer_id", "order_date", "order_time") \
  .agg(first("transaction_id").alias("order_id"), first("region").alias("region"))

# Create order detail table
order_detail_df = customer_transaction_df.select(
    col("transaction_id").alias("order_id"),
    col("product"),
    col("quantity"),
    col("price")
)

# Look up product_id from product table
product_df = spark.read.format("bigquery") \
  .option("table", "${project_id}.${bigquery_governed_data_enriched_dataset}.product") \
  .load()

order_detail_enriched_df = order_detail_df.join(
    product_df, order_detail_df["product"] == product_df["product_name"], "left"
).select(
    col("order_id"),
    col("product_id"),
    col("quantity"),
    col("price")
)

# Combine order_date and order_time into a datetime column
order_header_enriched_df = order_header_df.withColumn(
    "order_datetime", to_timestamp(
        concat(
            date_format(col("order_date"), "yyyy-MM-dd"), 
            lit(" "), 
            from_unixtime(col("order_time") / (60 * 60 * 24), "HH:mm:ss")
        ), 
        "yyyy-MM-dd HH:mm:ss"
    )
).drop("order_date", "order_time")

# Write to BigQuery
order_header_enriched_df.write.format("bigquery") \
  .option("temporaryGcsBucket","${governed_data_code_bucket}") \
  .option("table", "${project_id}.${bigquery_governed_data_enriched_dataset}.order_header") \
  .mode("overwrite").save()

order_detail_enriched_df.write.format("bigquery") \
  .option("temporaryGcsBucket","${governed_data_code_bucket}") \
  .option("table", "${project_id}.${bigquery_governed_data_enriched_dataset}.order_detail") \
  .mode("overwrite").save()

spark.stop()