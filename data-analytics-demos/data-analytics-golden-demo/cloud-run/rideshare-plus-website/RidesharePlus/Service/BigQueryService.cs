namespace RidesharePlus.Models;
using Google.Cloud.BigQuery.V2;
using System.Collections.Generic;

// https://cloud.google.com/dotnet/docs/reference/Google.Cloud.BigQuery.V2/latest#querying

public class BigQueryService
{
    public void GeneratePredictions(string rideDistance, bool isRaining, bool isSnowing)
    {
        string projectId = EnvVarService.ENV_PROJECT_ID;
        string rideshareLakehouseCuratedDataset = EnvVarService.ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET;

        BigQueryClient client = BigQueryClient.Create(projectId);

        string sql = "CALL `" + projectId + "." + rideshareLakehouseCuratedDataset + ".sp_website_score_data`('" + 
                rideDistance + "', " + isRaining.ToString() + ", " + isSnowing.ToString() + ", 0, 0);";

        BigQueryResults results = client.ExecuteQuery(sql, null); 
    }
    

    public StreamingDataModel StreamingData ()
    {
        string projectId = EnvVarService.ENV_PROJECT_ID;
        string rideshareLakehouseCuratedDataset = EnvVarService.ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET;

        BigQueryClient client = BigQueryClient.Create(projectId);
        string sql = "SELECT * FROM `" + projectId + "." + rideshareLakehouseCuratedDataset + ".website_realtime_dashboard`";

    
        //BigQueryParameter[] parameters = null;
        BigQueryResults results = client.ExecuteQuery(sql, null); 

        List<StreamingDataModel> streamingDataModels = new List<StreamingDataModel>();

        foreach (BigQueryRow row in results)
        {
            StreamingDataModel streamingDataModel= new StreamingDataModel();
            streamingDataModel.RideCount = Int32.Parse(row["ride_count"].ToString());
            streamingDataModel.AverageRideDurationMinutes = float.Parse(row["average_ride_duration_minutes"].ToString());
            streamingDataModel.AverageTotalAmount = float.Parse(row["average_total_amount"].ToString());
            streamingDataModel.AverageRideDistance = float.Parse(row["average_ride_distance"].ToString());
            streamingDataModel.MaxPickupLocationZone = row["max_pickup_location_zone"].ToString();
            streamingDataModel.MaxPickupRideCount = Int32.Parse(row["max_pickup_ride_count"].ToString());
            streamingDataModel.MaxDropoffLocationZone = row["max_dropoff_location_zone"].ToString();
            streamingDataModel.MaxDropoffRideCount = Int32.Parse(row["max_dropoff_ride_count"].ToString());

            streamingDataModels.Add(streamingDataModel);
        }  

        return streamingDataModels.FirstOrDefault<StreamingDataModel>();                   

    }

}