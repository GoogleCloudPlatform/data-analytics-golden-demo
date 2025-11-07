using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using RidesharePlus.Models;

namespace RidesharePlus.Controllers;

public class PredictController : Controller
{
    private readonly ILogger<PredictController> _logger;

    public PredictController(ILogger<PredictController> logger)
    {
        _logger = logger;
    }

    [Route("predict/index")]
    public IActionResult PredictGet()
    {
        PredictViewModel predictViewModel = new PredictViewModel();
        return View("Index", predictViewModel);
    }

    public IActionResult PredictSet(PredictViewModel predictViewModel)
    {
        BigQueryService bigQueryService = new BigQueryService();
        bool isRaining = false;
        bool isSnowing = false;

        if (string.IsNullOrWhiteSpace(predictViewModel.RideDistance))
        {
           predictViewModel.RideDistance = "short";
        }
        if (predictViewModel.SimulateWeather == "rain")
        {
            isRaining = true;
        }
        if (predictViewModel.SimulateWeather == "snow")
        {
            isSnowing = true;
        }

        bigQueryService.GeneratePredictions(predictViewModel.RideDistance, isRaining, isSnowing);

        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerHighValueRides == null)
        {
            // need to configure looker
            return RedirectToAction("Configure", "Predict");
        }
        else
        {
            return RedirectToAction("Visualize", "Predict");
        }
    }

    [Route("predict/configure")]
    public IActionResult ConfigureGet()
    {
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null)
        {
            dataStoreModel = new DataStoreModel();
        }

        PredictConfigureViewModel predictConfigureViewModel = new PredictConfigureViewModel();

        if (dataStoreModel.LookerHighValueRides != null)
        {
            predictConfigureViewModel.LookerEmbedUrl = dataStoreModel.LookerHighValueRides;
        }

        predictConfigureViewModel.ProjectId = EnvVarService.ENV_PROJECT_ID;
        predictConfigureViewModel.DatasetName = EnvVarService.ENV_RIDESHARE_LAKEHOUSE_CURATED_DATASET;
        predictConfigureViewModel.ViewName = "looker_high_value_rides";

        return View("Configure", predictConfigureViewModel);
    }

    public IActionResult ConfigureSet(Models.PredictConfigureViewModel predictConfigureViewModel)
    {
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null)
        {
            dataStoreModel = new DataStoreModel();
        }

        dataStoreModel.LookerHighValueRides = predictConfigureViewModel.LookerEmbedUrl;
        dataStoreModel = dataStoreService.Save(dataStoreModel);

        return RedirectToAction("Visualize", "Predict");
    }

    [Route("predict/visualize")]
    public IActionResult VisualizeGet()
    {
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerHighValueRides == null)
        {
            return RedirectToAction("Configure", "Predict");
        }
        else
        {
            Models.PredictVisualizeViewModel predictVisualizeViewModel = new PredictVisualizeViewModel();
            predictVisualizeViewModel.LookerEmbedUrl = dataStoreModel.LookerHighValueRides;
            return View("Visualize", predictVisualizeViewModel);
        }
    }

    public IActionResult Architecture()
    {
        return View();
    }    


    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
