using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using RidesharePlus.Models;

namespace RidesharePlus.Controllers;

public class StreamingController : Controller
{
    private readonly ILogger<HomeController> _logger;

    public StreamingController(ILogger<HomeController> logger)
    {
        _logger = logger;
    }

    public IActionResult Index()
    {
        return View();
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
