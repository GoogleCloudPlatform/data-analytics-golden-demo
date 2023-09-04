namespace RidesharePlus.Models;
using Newtonsoft.Json;
using Google.Cloud.Storage.V1;

public class DataStoreService
{
    private readonly string BUCKET_NAME = EnvVarService.ENV_CODE_BUCKET;
    private readonly string JSON_FILE = "website/ailakehouse.json";

    public void Initialize(DataStoreModel model)
    {
        var client = StorageClient.Create();

        JSONService jsonService = new JSONService();
        string json = jsonService.Serialize<DataStoreModel>(model);
        var content = System.Text.Encoding.UTF8.GetBytes(json);
        
        var returnValue = client.UploadObject(BUCKET_NAME, JSON_FILE, "text/plain", new MemoryStream(content));        
    }

    public DataStoreModel GetDataStore
    {
        get
        {
            var client = StorageClient.Create();

            // Download file / data
            DataStoreModel dataStoreModel = new DataStoreModel();

            Stream stream = new MemoryStream();
            try
            {
                client.DownloadObject(BUCKET_NAME, JSON_FILE, stream);
                stream.Position = 0;

                StreamReader reader = new StreamReader(stream);
                string json = reader.ReadToEnd();

                JSONService jsonService = new JSONService();
                dataStoreModel = jsonService.Deserialize<DataStoreModel>(json);
            }
            catch
            {
                // file does not exist
                dataStoreModel.LookerAILLM = null;
                dataStoreModel.LookerHighValueRides = null;
                this.Initialize(dataStoreModel);
            }

            return dataStoreModel;
        }
    }


    public DataStoreModel Save(DataStoreModel dataStoreModel)
    {
        var client = StorageClient.Create();

        JSONService jsonService = new JSONService();
        string json = jsonService.Serialize<DataStoreModel>(dataStoreModel);
        var content = System.Text.Encoding.UTF8.GetBytes(json);        
        
        var returnValue = client.UploadObject(BUCKET_NAME, JSON_FILE, "text/plain", new MemoryStream(content));  

        return dataStoreModel;      
    }

}