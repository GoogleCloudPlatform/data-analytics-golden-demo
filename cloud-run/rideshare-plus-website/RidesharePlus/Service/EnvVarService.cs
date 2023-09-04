namespace RidesharePlus.Models;

public class EnvVarService
{
    /*
    //C:\Users\Matth\OneDrive\Desktop\cloud-run-app\cloud-run-app\RidesharePlus\ \Users\Matth\OneDrive\Documents\gcp.json
    export GOOGLE_APPLICATION_CREDENTIALS=/Users/paternostro/cloud-run-app/a.json
    export ENV_PROJECT_ID="my-project"
    export ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET="rideshare-curated"
    export ENV_CODE_BUCKET="rideshare-curated"

    */
    public static string GOOGLE_APPLICATION_CREDENTIALS
    {
        get
        {
            return Environment.GetEnvironmentVariable("ENV_CODE_BUCKET") ?? "/Users/paternostro/cloud-run-app/a.json";
        }
    }

    public static string ENV_PROJECT_ID
    {
        get
        {
            return Environment.GetEnvironmentVariable("ENV_PROJECT_ID") ?? "data-analytics-demo-u0i2dr3u3j";
        }
    }

    public static string ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET
    {
        get
        {
            return Environment.GetEnvironmentVariable("ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET") ?? "rideshare_lakehouse_curated";
        }
    }

    public static string ENV_CODE_BUCKET
    {
        get
        {
            return Environment.GetEnvironmentVariable("ENV_CODE_BUCKET") ?? "code-data-analytics-demo-u0i2dr3u3j";
        }
    }

    public static string ENV_RIDESHARE_LLM_CURATED_DATASET
    {
        get
        {
            return Environment.GetEnvironmentVariable("ENV_RIDESHARE_LLM_CURATED_DATASET") ?? "rideshare_llm_curated";
        }
    }

} // class
