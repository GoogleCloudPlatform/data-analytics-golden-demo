using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using RidesharePlus.Models;

[ApiController]
public class RestApiController : ControllerBase
{

    private readonly ILogger<RestApiController> _logger;

    public RestApiController(ILogger<RestApiController> logger)
    {
        _logger = logger;

    }


    [HttpGet]
    [Route("/api/rideshare-streaming")]
    public IActionResult RideshareStraming()
    {
        /*
        GET http://0.0.0.0:8080/api/rideshare-streaming 405 (Method Not Allowed)
        */
        BigQueryService bigQueryService = new BigQueryService();
        StreamingDataModel streamingDataModel = bigQueryService.StreamingData();

        if (streamingDataModel == null)
        {
            streamingDataModel = new StreamingDataModel();
            streamingDataModel.AverageRideDistance = 0 ;
            streamingDataModel.AverageRideDurationMinutes = 0;
            streamingDataModel.AverageTotalAmount = 0;
            streamingDataModel.MaxDropoffLocationZone = "Streaming Job is Stopped";
            streamingDataModel.MaxDropoffRideCount = 0;
            streamingDataModel.MaxPickupLocationZone = "Streaming Job is Stopped";
            streamingDataModel.RideCount = 0;
        }

        return Ok(streamingDataModel);
    } //RideshareStraming

}
