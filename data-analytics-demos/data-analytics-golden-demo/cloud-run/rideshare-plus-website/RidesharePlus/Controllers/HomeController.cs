using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using RidesharePlus.Models;

namespace RidesharePlus.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;

    public HomeController(ILogger<HomeController> logger)
    {
        _logger = logger;
    }

    public IActionResult Index()
    {
        ViewBag.Key1 = Environment.GetEnvironmentVariable("KEY1") ?? "KEY1-Null";
        return View();
    }

    public IActionResult DemoOverview()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
