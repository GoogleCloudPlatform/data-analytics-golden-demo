namespace RidesharePlus.Models;
using Newtonsoft.Json;


public class JSONService
{
    /// <summary>
    /// Serializes a model to JSON string
    /// </summary>
    public string Serialize<T>(T model)
    {
        return JsonConvert.SerializeObject(model);
    } // Serialize


    /// <summary>
    /// Deserilaizes a model.  Ignores missing fields
    /// </summary>
    public T Deserialize<T>(string json)
    {
        return JsonConvert.DeserializeObject<T>(json);
    } // Deserialize


} // class
