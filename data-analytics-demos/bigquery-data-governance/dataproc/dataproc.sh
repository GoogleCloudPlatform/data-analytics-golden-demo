# Run the dataproc job by hand

PROJECT_ID="governed-data-mib3n1f02y"
PROJECT_EXTENSION="mib3n1f02y"

# Turn on data lineage for the cluster: --properties="dataproc:dataproc.lineage.enabled=true"
gcloud dataproc clusters create "my-cluster" \
    --project="${PROJECT_ID}" \
    --region="us-central1" \
    --num-masters=1 \
    --bucket="governed-data-code-${PROJECT_EXTENSION}" \
    --temp-bucket="governed-data-code-${PROJECT_EXTENSION}" \
    --master-machine-type="n1-standard-4" \
    --worker-machine-type="n1-standard-4" \
    --num-workers=2 \
    --image-version="2.1.75-debian11" \
    --subnet="dataproc-subnet" \
    --service-account="dataproc-service-account@${PROJECT_ID}.iam.gserviceaccount.com" \
    --properties="dataproc:dataproc.lineage.enabled=true" \
    --no-address

-- Tell the job to log lineage: --properties=spark.openlineage.namespace=${PROJECT_ID},spark.openlineage.appName=OrderEnricher
gcloud dataproc jobs submit pyspark  \
   --project="${PROJECT_ID}" \
   --cluster="my-cluster" \
   --region="us-central1" \
   --properties=spark.openlineage.namespace=${PROJECT_ID},spark.openlineage.appName=OrderEnricher \
   gs://governed-data-code-${PROJECT_EXTENSION}/dataproc/transform_order_pyspark.py    

gcloud dataproc clusters delete "my-cluster" \
   --project="${PROJECT_ID}" \
   --region="us-central1"