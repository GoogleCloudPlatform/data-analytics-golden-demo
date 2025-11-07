namespace RidesharePlus.Models;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

public class PredictViewModel
{

    public PredictViewModel()
    {
        this.RideDistance = "short";
        this.SimulateWeather = "current";


    }

    [DisplayName("Ride Distance")]
    public string? RideDistance { get; set; }

    [DisplayName("Simulate Weather")]
    public string? SimulateWeather { get; set; }

}
