from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when
from pyspark.sql.types import StructType, StringType
import sys
import datetime
import logging
import boto3

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Spark session
spark = SparkSession.builder.appName("DataProcessingJob").getOrCreate()

# Initialize S3 client
s3 = boto3.client('s3')

def check_s3_path_exists(bucket, prefix):
    """Check if a given S3 path exists."""
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix, MaxKeys=1)
    return 'Contents' in response

def read_csv_robust(path):
    """Read a CSV file into a Spark DataFrame, handling multi-line fields, commas, and nested quotes."""
    try:
        # Check if the path exists
        bucket, key = path.replace("s3://", "").split("/", 1)
        if not check_s3_path_exists(bucket, key):
            logger.warning(f"Path does not exist: {path}")
            return spark.createDataFrame([], StructType([]))

        # Read the CSV file into a DataFrame with robust options
        df = spark.read \
            .option("header", "true") \
            .option("inferSchema", "true") \
            .option("multiline", "true") \
            .option("quote", '"') \
            .option("escape", '"') \
            .option("delimiter", ",") \
            .option("mode", "PERMISSIVE") \
            .option("columnNameOfCorruptRecord", "_corrupt_record") \
            .option("encoding", "UTF-8") \
            .csv(path)
        
        if df.rdd.isEmpty():
            logger.warning(f"No data read from {path}")
            return spark.createDataFrame([], StructType([]))

        # Log the schema of the read data
        logger.info(f"Schema of data read from {path}:")
        df.printSchema()
        
        # Check for corrupt records
        if "_corrupt_record" in df.columns:
            corrupt_count = df.filter(col("_corrupt_record").isNotNull()).count()
            if corrupt_count > 0:
                logger.warning(f"Found {corrupt_count} corrupt records in {path}")
            df = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
        
        # Filter out rows with null or empty 'Key' if 'Key' column exists
        if "Key" in df.columns:
            df = df.filter(col("Key").isNotNull() & (col("Key") != ""))
            logger.info(f"Successfully read data from {path}. Count after filtering: {df.count()}")
        else:
            logger.warning(f"'Key' column not found in {path}. No filtering applied.")
        
        return df
    except Exception as e:
        logger.error(f"Failed to read from {path}: {str(e)}. Returning empty DataFrame.")
        return spark.createDataFrame([], StructType([]))


def process_data(s3_bucket, new_csv_file):
    """Process unprocessed data and deduplicate against existing staged data."""
    # Construct S3 paths
    unprocessed_path = f"s3://{s3_bucket}/{new_csv_file}"
    staged_path = f"s3://{s3_bucket}/staged/"

    # Read unprocessed data
    unprocessed_df = read_csv_robust(unprocessed_path)
    
    if unprocessed_df.rdd.isEmpty():
        logger.error(f"No valid data found in unprocessed data: {unprocessed_path}")
        return
    
    # Read existing staged data if it exists
    if check_s3_path_exists(s3_bucket, "staged/"):
        staged_df = read_csv_robust(staged_path)
        if staged_df.rdd.isEmpty():
            logger.warning("No existing staged data found. Treating all unprocessed data as new.")
            new_records = unprocessed_df
        elif "Key" not in staged_df.columns:
            logger.warning("'Key' column is missing from staged data. Treating all unprocessed data as new.")
            new_records = unprocessed_df
        else:
            # Deduplicate unprocessed data against existing staged data based on "Key"
            new_records = unprocessed_df.join(staged_df, "Key", "leftanti")
    else:
        logger.warning("Staged data path does not exist. Treating all unprocessed data as new.")
        new_records = unprocessed_df
    
    if new_records.rdd.isEmpty():
        logger.info("No new records found. Exiting without writing output.")
        return
    
    # Generate a timestamped output filename
    current_time = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"staged_{current_time}.csv"
    
    # Write to CSV in S3 directly using Spark, ensuring a single file output
    output_path = f"s3://{s3_bucket}/staged/{output_filename}"
    
    # Convert DataFrame to Pandas and write using boto3
    pandas_df = new_records.toPandas()
    csv_buffer = pandas_df.to_csv(index=False, quoting=1, quotechar='"', escapechar='"', encoding='utf-8')
        
    # WRite the files to S3
    s3_resource = boto3.resource('s3')
    s3_resource.Object(s3_bucket, f"staged/{output_filename}").put(Body=csv_buffer)
    
    logger.info(f"Wrote {new_records.count()} new records to {output_path}")

# Main execution
if __name__ == "__main__":
    args = getResolvedOptions(sys.argv, ['S3_BUCKET', 'NEW_CSV_FILE', 'JOB_NAME'])

    
    s3_bucket = args['S3_BUCKET']
    new_csv_file = args['NEW_CSV_FILE']
    
    logger.info(f"Processing file: {new_csv_file} in bucket: {s3_bucket}")
    
    process_data(s3_bucket, new_csv_file)
    
    logger.info(f"Job completed successfully")

# Stop the Spark session
spark.stop()