from pyspark.sql import SparkSession

if __name__ == "__main__":
    # Initialize SparkSession
    spark = SparkSession.builder \
        .appName("Sample PySpark App") \
        .getOrCreate()

    # Create a sample DataFrame
    data = [("Alice", 34), ("Bob", 23), ("Cathy", 45)]
    columns = ["Name", "Age"]
    df = spark.createDataFrame(data, columns)

    # Show the DataFrame
    df.show()

    # Perform a transformation
    df_filtered = df.filter(df.Age > 30)

    # Show the filtered DataFrame
    df_filtered.show()

    # Stop the Spark session
    spark.stop()
