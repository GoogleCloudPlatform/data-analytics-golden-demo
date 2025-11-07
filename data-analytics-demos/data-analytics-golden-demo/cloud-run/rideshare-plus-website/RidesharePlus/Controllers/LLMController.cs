using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using RidesharePlus.Models;

namespace RidesharePlus.Controllers;

public class LLMController : Controller
{
    private readonly ILogger<LLMController> _logger;

    public LLMController(ILogger<LLMController> logger)
    {
        _logger = logger;
    }

    public IActionResult Index()
    {       
        return View();
    }

   [Route("llm/configure")]
    public IActionResult ConfigureGet()
    {
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null)
        {
            dataStoreModel = new DataStoreModel();
        }

        LLMConfigureViewModel llmConfigureViewModel = new LLMConfigureViewModel();

        if (dataStoreModel.LookerAILLM != null)
        {
            llmConfigureViewModel.LookerEmbedUrl = dataStoreModel.LookerAILLM;
        }

        llmConfigureViewModel.ProjectId = EnvVarService.ENV_PROJECT_ID;
        llmConfigureViewModel.DatasetName = EnvVarService.ENV_RIDESHARE_LLM_CURATED_DATASET;
        llmConfigureViewModel.LookerCustomerReview = "looker_customer_review";
        llmConfigureViewModel.LookerCustomer = "looker_customer";
        llmConfigureViewModel.LookerDriver = "looker_driver";

        return View("Configure", llmConfigureViewModel);
    }

    public IActionResult ConfigureSet(Models.LLMConfigureViewModel llmConfigureViewModel)
    {
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null)
        {
            dataStoreModel = new DataStoreModel();
        }

        dataStoreModel.LookerAILLM = llmConfigureViewModel.LookerEmbedUrl;

        // https://lookerstudio.google.com/embed/reporting/47d745eb-b17a-4505-8693-07798e7e82d5/page/p_71hkwn158c
        string basePath = llmConfigureViewModel.LookerEmbedUrl.Substring(0, 
                                llmConfigureViewModel.LookerEmbedUrl.IndexOf("/page/")+ "/page/".Length);

        dataStoreModel.LookerAILLM_Page_EmployeeProfile = basePath + "zeXaD";
        dataStoreModel.LookerAILLM_Page_EmployeeReviews = basePath + "p_uelxhla98c";
        dataStoreModel.LookerAILLM_Page_CustomerProfile = basePath + "p_o8qps9u68c";
        dataStoreModel.LookerAILLM_Page_CustomerReviews = basePath + "p_i384xv988c";    

        dataStoreModel = dataStoreService.Save(dataStoreModel);

        return RedirectToAction("employee-profile", "LLM");
    }

    [Route("/llm/customer-profile")]
    public IActionResult CustomerProfile()
    {      
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerAILLM_Page_CustomerProfile == null)
        {
            return RedirectToAction("Configure", "LLM");
        }
        else
        {
            Models.LLMVisualizeViewModel llmVisualizeViewModel = new LLMVisualizeViewModel();
            llmVisualizeViewModel.LookerEmbedUrl = dataStoreModel.LookerAILLM_Page_CustomerProfile;
            return View("customer-profile", llmVisualizeViewModel);
        }                 
    }

    [Route("/llm/customer-reviews")]
    public IActionResult CustomerReviews()
    {      
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerAILLM_Page_CustomerProfile == null)
        {
            return RedirectToAction("Configure", "LLM");
        }
        else
        {
            Models.LLMVisualizeViewModel llmVisualizeViewModel = new LLMVisualizeViewModel();
            llmVisualizeViewModel.LookerEmbedUrl = dataStoreModel.LookerAILLM_Page_CustomerReviews;
            return View("customer-reviews", llmVisualizeViewModel);
        }                 
    }

    [Route("/llm/employee-profile")]
    public IActionResult EmployeeProfile()
    {       
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerAILLM_Page_EmployeeProfile == null)
        {
            return RedirectToAction("Configure", "LLM");
        }
        else
        {
            Models.LLMVisualizeViewModel llmVisualizeViewModel = new LLMVisualizeViewModel();
            llmVisualizeViewModel.LookerEmbedUrl = dataStoreModel.LookerAILLM_Page_EmployeeProfile;
            return View("employee-profile", llmVisualizeViewModel);
        }   
    }  

    [Route("/llm/employee-reviews")]
    public IActionResult EmployeeReviews()
    {       
        DataStoreService dataStoreService = new DataStoreService();
        DataStoreModel dataStoreModel = dataStoreService.GetDataStore;

        if (dataStoreModel == null || dataStoreModel.LookerAILLM_Page_EmployeeProfile == null)
        {
            return RedirectToAction("Configure", "LLM");
        }
        else
        {
            Models.LLMVisualizeViewModel llmVisualizeViewModel = new LLMVisualizeViewModel();
            llmVisualizeViewModel.LookerEmbedUrl = dataStoreModel.LookerAILLM_Page_EmployeeReviews;
            return View("employee-reviews", llmVisualizeViewModel);
        }   
    }  
    public IActionResult Architecture()
    {
        return View();
    }  

}
