namespace RidesharePlus.Models;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

public class PredictConfigureViewModel
{

    public PredictConfigureViewModel()
    {
        this.LookerEmbedUrl = "https://Replace-Me";
    }

    [DisplayName("Looker Embed Url")]
    public string? LookerEmbedUrl { get; set; }

    public string? ProjectId { get; set; }

    public string? DatasetName { get; set; }

    public string? ViewName { get; set; }

}
